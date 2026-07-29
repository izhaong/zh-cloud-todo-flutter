import '../../state/repositories/reminder_inbox_repository.dart';
import '../db/app_database.dart';
import 'local_notification_service.dart';

/// 将服务端提醒派发读模型转换为当前设备的即时系统通知。
///
/// 收件箱读取统一经过 [ReminderInboxRepository]；同一派发 ID 在当前 App
/// 生命周期内只展示一次，避免 30 秒轮询反复触发相同通知。跨重启定时调度不在
/// B2 范围内。
class ReminderNotificationPoller {
  ReminderNotificationPoller({
    required ReminderInboxRepository repository,
    required AppDatabase database,
    required LocalNotificationService notifications,
    DateTime Function()? now,
  }) : _repository = repository,
       _database = database,
       _notifications = notifications,
       _now = now ?? DateTime.now;

  final ReminderInboxRepository _repository;
  final AppDatabase _database;
  final LocalNotificationService _notifications;
  final DateTime Function() _now;
  final Set<int> _shownDispatchIds = {};

  Future<int> poll() async {
    final current = _now();
    final upcomingBoundary = current.add(const Duration(seconds: 30));
    var shown = 0;
    for (final item in await _repository.list()) {
      if (!item.pending ||
          item.remindAt.isAfter(upcomingBoundary) ||
          !_shownDispatchIds.add(item.id)) {
        continue;
      }
      final task = await _database.taskByServerId(item.taskId);
      final localTitle = task?.title.trim() ?? '';
      final remoteTitle = item.taskTitle.trim();
      await _notifications.show(
        id: item.id,
        title: localTitle.isNotEmpty
            ? localTitle
            : (remoteTitle.isNotEmpty ? remoteTitle : '提醒'),
        body: '到期提醒',
        payload: 'reminder:${item.id}',
      );
      shown++;
    }
    return shown;
  }
}
