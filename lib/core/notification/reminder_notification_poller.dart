import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../state/repositories/reminder_inbox_repository.dart';
import '../db/app_database.dart';
import 'local_notification_service.dart';

abstract interface class ReminderNotificationStateStore {
  Future<Map<int, DateTime>> read();

  Future<bool> write(Map<int, DateTime> value);
}

class SharedPreferencesReminderNotificationStateStore
    implements ReminderNotificationStateStore {
  SharedPreferencesReminderNotificationStateStore({required String namespace})
    : _key = 'todo_reminder_dispatch_state_v1_$namespace';

  final String _key;

  @override
  Future<Map<int, DateTime>> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (int.tryParse(entry.key) case final id?)
            if (entry.value case final int timestamp)
              id: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> write(Map<int, DateTime> value) async {
    try {
      final encoded = jsonEncode({
        for (final entry in value.entries)
          entry.key.toString(): entry.value.millisecondsSinceEpoch,
      });
      return (await SharedPreferences.getInstance()).setString(_key, encoded);
    } catch (_) {
      // 状态持久化失败时不阻塞收件箱轮询。
      return false;
    }
  }
}

/// 将服务端提醒派发读模型转换为当前设备的系统通知调度。
///
/// 收件箱读取统一经过 [ReminderInboxRepository]；未来提醒交给操作系统持久
/// 调度，已到期提醒即时展示。派发被撤销或状态变化时同步取消本机调度。
class ReminderNotificationPoller {
  ReminderNotificationPoller({
    required ReminderInboxRepository repository,
    required AppDatabase database,
    required LocalNotificationService notifications,
    required ReminderNotificationStateStore stateStore,
    required String notificationScope,
    DateTime Function()? now,
  }) : _repository = repository,
       _database = database,
       _notifications = notifications,
       _stateStore = stateStore,
       _notificationScope = notificationScope,
       _now = now ?? DateTime.now;

  final ReminderInboxRepository _repository;
  final AppDatabase _database;
  final LocalNotificationService _notifications;
  final ReminderNotificationStateStore _stateStore;
  final String _notificationScope;
  final DateTime Function() _now;
  Map<int, DateTime>? _dispatchState;
  Future<int>? _pollInFlight;
  bool _stateDirty = false;

  Future<int> poll() {
    final active = _pollInFlight;
    if (active != null) return active;
    late final Future<int> run;
    run = _pollOnce().whenComplete(() {
      if (identical(_pollInFlight, run)) _pollInFlight = null;
    });
    _pollInFlight = run;
    return run;
  }

  Future<int> _pollOnce() async {
    final current = _now();
    final upcomingBoundary = current.add(const Duration(seconds: 30));
    final dispatchState = _dispatchState ??= await _stateStore.read();
    final systemSchedules = await _notifications.pendingReminderSchedules(
      _notificationScope,
    );
    final activeIds = await _notifications.activeReminderIds(
      _notificationScope,
    );
    final items = await _repository.list();
    final pendingIds = items
        .where((item) => item.pending)
        .map((item) => item.id)
        .toSet();
    final cancelledIds = {
      ...dispatchState.keys,
      ...systemSchedules.keys,
      ...activeIds,
    }.where((id) => !pendingIds.contains(id)).toList(growable: false);
    var stateChanged = _stateDirty;
    final notificationTag = LocalNotificationService.reminderTag(
      _notificationScope,
    );
    for (final id in cancelledIds) {
      if (await _notifications.cancel(id, tag: notificationTag)) {
        stateChanged = dispatchState.remove(id) != null || stateChanged;
      }
    }

    var shown = 0;
    for (final item in items) {
      if (!item.pending) {
        continue;
      }
      final isFuture = item.remindAt.isAfter(upcomingBoundary);
      final alreadyHandled =
          dispatchState[item.id] == item.remindAt ||
          systemSchedules[item.id] == item.remindAt ||
          (!isFuture && activeIds.contains(item.id));
      if (alreadyHandled) {
        if (dispatchState[item.id] != item.remindAt) {
          dispatchState[item.id] = item.remindAt;
          stateChanged = true;
        }
        continue;
      }
      final task = await _database.taskByServerId(item.taskId);
      final localTitle = task?.title.trim() ?? '';
      final remoteTitle = item.taskTitle.trim();
      final title = localTitle.isNotEmpty
          ? localTitle
          : (remoteTitle.isNotEmpty ? remoteTitle : '提醒');
      final payload =
          'reminder:${item.id}:$_notificationScope:'
          '${item.remindAt.millisecondsSinceEpoch}:${item.taskId}';
      final delivered = isFuture
          ? await _notifications.schedule(
              id: item.id,
              title: title,
              body: '到期提醒',
              fireAt: item.remindAt,
              payload: payload,
              tag: notificationTag,
            )
          : await _notifications.show(
              id: item.id,
              title: title,
              body: '到期提醒',
              payload: payload,
              tag: notificationTag,
            );
      if (!delivered) continue;
      if (!isFuture) shown++;
      dispatchState[item.id] = item.remindAt;
      stateChanged = true;
    }
    if (stateChanged) {
      _stateDirty = !await _stateStore.write(dispatchState);
    }
    return shown;
  }
}
