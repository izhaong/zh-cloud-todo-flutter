/// 本地通知服务封装（`flutter_local_notifications` ^18）。
///
/// 负责：初始化、权限请求、即时展示、系统级定时展示、取消。
///
/// **测试安全**：所有平台通道调用均用 `try/catch` 包裹；在测试环境（无
/// no-op 实现）下任何调用都不会抛异常。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// 用户点击提醒通知后，交给应用导航层消费的最小非敏感上下文。
@immutable
class ReminderNotificationSelection {
  const ReminderNotificationSelection({
    required this.dispatchId,
    required this.scope,
    this.taskServerId,
  });

  final int dispatchId;
  final String scope;
  final int? taskServerId;

  static ReminderNotificationSelection? parse(String? payload) {
    final parts = payload?.split(':');
    if (parts == null ||
        (parts.length != 4 && parts.length != 5) ||
        parts[0] != 'reminder') {
      return null;
    }
    final dispatchId = int.tryParse(parts[1]);
    final timestamp = int.tryParse(parts[3]);
    final taskServerId = parts.length == 5 ? int.tryParse(parts[4]) : null;
    if (dispatchId == null ||
        parts[2].isEmpty ||
        timestamp == null ||
        (parts.length == 5 && taskServerId == null)) {
      return null;
    }
    return ReminderNotificationSelection(
      dispatchId: dispatchId,
      scope: parts[2],
      taskServerId: taskServerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderNotificationSelection &&
          dispatchId == other.dispatchId &&
          scope == other.scope &&
          taskServerId == other.taskServerId;

  @override
  int get hashCode => Object.hash(dispatchId, scope, taskServerId);
}

/// 本地通知服务单例持有者（通过 [localNotificationServiceProvider] 对外暴露）。
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin;

  /// null 表示不支持 / 未初始化；后续所有操作对此短路返回。
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;
  static bool _timeZonesInitialized = false;
  final _reminderSelections =
      StreamController<ReminderNotificationSelection>.broadcast(sync: true);
  ReminderNotificationSelection? _pendingReminderSelection;
  String? _lastDispatchedReminderPayload;

  Stream<ReminderNotificationSelection> get reminderSelections =>
      _reminderSelections.stream;

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
      await plugin.initialize(
        _settings,
        onDidReceiveNotificationResponse: _dispatchNotificationResponse,
      );
      // Android 13+ 通知权限由 requestPermissions 单独申请。
      _plugin = plugin;
      try {
        final launchDetails = await plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp ?? false) {
          final response = launchDetails?.notificationResponse;
          if (response != null) _dispatchNotificationResponse(response);
        }
      } catch (_) {
        // 启动来源读取失败不影响后续通知展示和点击回调。
      }
    } catch (_) {
      // 测试 / 不支持平台：保持 _plugin = nullptr，后续调用全部短路。
      _plugin = null;
    }
    _initialized = true;
  }

  void _dispatchNotificationResponse(NotificationResponse response) {
    final selection = ReminderNotificationSelection.parse(response.payload);
    if (selection == null) return;
    if (response.payload == _lastDispatchedReminderPayload) return;
    _lastDispatchedReminderPayload = response.payload;
    if (_reminderSelections.hasListener) {
      _reminderSelections.add(selection);
    } else {
      // UI 尚未就绪时只保留用户最后一次点击，避免启动后连续打开多个页面。
      _pendingReminderSelection = selection;
    }
  }

  @visibleForTesting
  void dispatchNotificationResponseForTesting(NotificationResponse response) {
    _dispatchNotificationResponse(response);
  }

  /// 取出通知冷启动或 UI 尚未订阅时暂存的最后一次点击。
  ReminderNotificationSelection? takePendingReminderSelection() {
    final selection = _pendingReminderSelection;
    _pendingReminderSelection = null;
    return selection;
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
        (parts.length != 4 && parts.length != 5) ||
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

  void dispose() {
    unawaited(_reminderSelections.close());
  }
}

/// 全局本地通知服务单例。
final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = LocalNotificationService();
  ref.onDispose(service.dispose);
  return service;
});
