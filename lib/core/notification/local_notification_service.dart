/// 本地通知服务封装（`flutter_local_notifications` ^18）。
///
/// 负责：初始化、权限请求、即时展示、系统级定时展示、取消。
///
/// **测试安全**：所有平台通道调用均用 `try/catch` 包裹；在测试环境（无
/// no-op 实现）下任何调用都不会抛异常。
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// 提醒频道。
class ReminderChannel {
  ReminderChannel._();
  static const String id = 'todo_reminders';
  static const String name = '提醒';
  static const String description = '到期提醒通知';
}

/// 本地通知服务单例持有者（通过 [localNotificationServiceProvider] 对外暴露）。
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin;

  /// null 表示不支持 / 未初始化；后续所有操作对此短路返回。
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;
  static bool _timeZonesInitialized = false;

  static const _settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
    macOS: DarwinInitializationSettings(),
  );

  /// 初始化本地通知（幂等）。
  Future<void> init() async {
    if (_initialized) return;
    if (!_timeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    final plugin = _plugin ?? FlutterLocalNotificationsPlugin();
    try {
      await plugin.initialize(_settings);
      // Android 13+ 通知权限由 requestPermissions 单独申请。
      _plugin = plugin;
    } catch (_) {
      // 测试 / 不支持平台：保持 _plugin = nullptr，后续调用全部短路。
      _plugin = null;
    }
    _initialized = true;
  }

  /// 申请通知权限（iOS/macOS 弹窗；Android 13+）；返回是否已授权。
  Future<bool> requestPermissions() async {
    try {
      final plugin = _plugin;
      if (plugin == null) return false;
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      final macOS = plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS != null) {
        final ok = await macOS.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return ok ?? true;
      }
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final ok = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return ok ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<NotificationDetails> _details({String? tag}) => Future.value(
    NotificationDetails(
      android: AndroidNotificationDetails(
        ReminderChannel.id,
        ReminderChannel.name,
        channelDescription: ReminderChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        tag: tag,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    ),
  );

  /// 立即展示一条提醒通知。[id] 通常取服务端 reminderId，保证可去重。
  Future<bool> show({
    required int id,
    required String title,
    String? body,
    String? payload,
    String? tag,
  }) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return false;
    try {
      await plugin.show(
        id,
        title,
        body,
        await _details(tag: tag),
        payload: payload,
      );
      return true;
    } catch (_) {
      // 通知展示失败不阻塞业务。
      return false;
    }
  }

  /// 由操作系统持久调度提醒；同一 [id] 再次调度会覆盖旧时间。
  Future<bool> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime fireAt,
    String? payload,
    String? tag,
  }) async {
    await _guard();
    if (!fireAt.isAfter(DateTime.now())) {
      return show(id: id, title: title, body: body, payload: payload, tag: tag);
    }
    final plugin = _plugin;
    if (plugin == null) return false;
    try {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        timezone.TZDateTime.from(fireAt.toUtc(), timezone.UTC),
        await _details(tag: tag),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (_) {
      // 系统调度失败不阻塞业务。
      return false;
    }
  }

  /// 取消一条通知。
  Future<bool> cancel(int id, {String? tag}) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return false;
    try {
      await plugin.cancel(id, tag: tag);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 返回指定用户范围内尚未触发的提醒及其调度时间。
  Future<Map<int, DateTime>> pendingReminderSchedules(String scope) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return {};
    try {
      return {
        for (final request in await plugin.pendingNotificationRequests())
          if (_parseReminderPayload(request.payload, scope) case (
            id: final id,
            fireAt: final fireAt,
          ))
            id: fireAt,
      };
    } catch (_) {
      return {};
    }
  }

  /// 返回指定用户范围内当前仍展示的提醒 ID。
  Future<Set<int>> activeReminderIds(String scope) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return {};
    final tag = reminderTag(scope);
    try {
      return {
        for (final notification in await plugin.getActiveNotifications())
          if (notification.id case final id?)
            if (notification.tag == tag ||
                _parseReminderPayload(notification.payload, scope) != null)
              id,
      };
    } catch (_) {
      return {};
    }
  }

  static String reminderTag(String scope) => 'todo_reminder_$scope';

  static ({int id, DateTime fireAt})? _parseReminderPayload(
    String? payload,
    String scope,
  ) {
    final parts = payload?.split(':');
    if (parts == null ||
        parts.length != 4 ||
        parts[0] != 'reminder' ||
        parts[2] != scope) {
      return null;
    }
    final id = int.tryParse(parts[1]);
    final timestamp = int.tryParse(parts[3]);
    if (id == null || timestamp == null) return null;
    return (
      id: id,
      fireAt: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    );
  }

  Future<void> _guard() async {
    if (!_initialized) await init();
  }
}

/// 全局本地通知服务单例。
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(),
);
