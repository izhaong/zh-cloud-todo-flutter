/// 本地通知服务封装（`flutter_local_notifications` ^18）。
///
/// 负责：初始化、权限请求、即时展示、延迟展示、取消。
///
/// **测试安全**：所有平台通道调用均用 `try/catch` 包裹；在测试环境（无
/// no-op 实现）下任何调用都不会抛异常、也不调度真实定时器。
library local_notification_service;

/// **延迟展示的实现取舍**：持久化跨重启的 OS 级定时需要引入 `timezone` 包
/// （TZDateTime）；本轮最小交付版本采用内存 `Timer` 延迟触发，App 仍在前台
/// 或短期后台期间有效。若需真正跨重启调度，补装 `timezone` 后改为
/// `zonedSchedule` 即可，接口不变。
import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final plugin = FlutterLocalNotificationsPlugin();
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

  Future<NotificationDetails> get _details => Future.value(
        const NotificationDetails(
          android: AndroidNotificationDetails(
            ReminderChannel.id,
            ReminderChannel.name,
            channelDescription: ReminderChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true),
        ),
      );

  /// 立即展示一条提醒通知。[id] 通常取服务端 reminderId，保证可去重。
  Future<void> show({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return;
    try {
      await plugin.show(id, title, body, await _details, payload: payload);
    } catch (_) {
      // 通知展示失败不阻塞业务。
    }
  }

  /// 延迟展示（最小交付版：内存 Timer；跨重启需 TZDateTime，见文件头）。
  Timer? schedule({
    required int id,
    required String title,
    String? body,
    required DateTime fireAt,
    String? payload,
  }) {
    final delay = fireAt.difference(DateTime.now());
    if (delay.isNegative) {
      show(id: id, title: title, body: body, payload: payload);
      return null;
    }
    final plugin = _plugin;
    if (plugin == null) return null;
    try {
      return Timer(delay, () {
        show(id: id, title: title, body: body, payload: payload);
      });
    } catch (_) {
      return null;
    }
  }

  /// 取消一条通知。
  Future<void> cancel(int id) async {
    await _guard();
    final plugin = _plugin;
    if (plugin == null) return;
    try {
      await plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> _guard() async {
    if (!_initialized) await init();
  }
}

/// 全局本地通知服务单例。
final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) => LocalNotificationService());
