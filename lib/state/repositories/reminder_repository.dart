import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 提醒规则的本地真相源。
///
/// 每次写入都在同一 Drift transaction 内更新提醒规则和 outbox。收件箱派发
/// 动作不属于提醒规则，后续由独立的 dispatch-action repository 处理。
class ReminderRepository {
  ReminderRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TodoReminder> create({
    required String taskId,
    required DateTime fireAt,
    String anchorType = 'ABSOLUTE',
    int? offsetMinutes,
    bool persistent = false,
    int? intervalMinutes,
    String? timeZone,
    bool fixedTimezone = false,
  }) async {
    if (persistent && (intervalMinutes == null || intervalMinutes <= 0)) {
      throw ArgumentError.value(
        intervalMinutes,
        'intervalMinutes',
        '持续提醒间隔必须为正分钟数',
      );
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    final mutationId = _uuid.v4();
    late TodoReminder row;
    await _db.transaction(() async {
      await _db
          .into(_db.todoReminders)
          .insert(
            TodoRemindersCompanion.insert(
              id: id,
              taskId: taskId,
              remindAt: fireAt,
              anchorType: Value(anchorType),
              offsetMinutes: Value(offsetMinutes),
              persistent: Value(persistent),
              intervalMinutes: Value(intervalMinutes),
              timeZone: Value(timeZone),
              fixedTimezone: Value(fixedTimezone),
              clientMutationId: Value(mutationId),
              updatedAt: now,
              createdAt: now,
            ),
          );
      row = await (_db.select(
        _db.todoReminders,
      )..where((t) => t.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.reminder,
        op: SyncOps.upsert,
        localId: id,
        clientMutationId: mutationId,
        payload: _payload(row),
      );
    });
    return row;
  }

  Map<String, dynamic> _payload(TodoReminder row) => {
    'id': row.id,
    'serverId': row.serverId,
    'taskId': row.taskId,
    'anchorType': row.anchorType,
    'offsetMinutes': row.offsetMinutes,
    'fireAt': row.remindAt.toIso8601String(),
    'status': row.status,
    'firedAt': row.firedAt?.toIso8601String(),
    'persistent': row.persistent,
    'intervalMinutes': row.intervalMinutes,
    'timeZone': row.timeZone,
    'fixedTimezone': row.fixedTimezone,
  };
}
