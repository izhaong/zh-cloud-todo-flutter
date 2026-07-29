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
    _validatePersistentInterval(persistent, intervalMinutes);
    final now = DateTime.now();
    final id = _uuid.v4();
    final mutationId = _uuid.v4();
    late TodoReminder row;
    await _db.transaction(() async {
      final task = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw StateError('提醒所属任务不存在：$taskId');
      }
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

  Future<TodoReminder> update({
    required String id,
    required DateTime fireAt,
    required String anchorType,
    int? offsetMinutes,
    required bool persistent,
    int? intervalMinutes,
    String? timeZone,
    required bool fixedTimezone,
  }) async {
    _validatePersistentInterval(persistent, intervalMinutes);
    final existing = await (_db.select(
      _db.todoReminders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('提醒规则不存在：$id');
    }

    final now = DateTime.now();
    final mutationId = _uuid.v4();
    late TodoReminder row;
    await _db.transaction(() async {
      await (_db.update(
        _db.todoReminders,
      )..where((t) => t.id.equals(id))).write(
        TodoRemindersCompanion(
          remindAt: Value(fireAt),
          anchorType: Value(anchorType),
          offsetMinutes: Value(offsetMinutes),
          persistent: Value(persistent),
          intervalMinutes: Value(intervalMinutes),
          timeZone: Value(timeZone),
          fixedTimezone: Value(fixedTimezone),
          clientMutationId: Value(mutationId),
          updatedAt: Value(now),
        ),
      );
      row = await (_db.select(
        _db.todoReminders,
      )..where((t) => t.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.reminder,
        op: SyncOps.upsert,
        localId: row.id,
        serverId: row.serverId,
        clientMutationId: mutationId,
        payload: _payload(row),
      );
    });
    return row;
  }

  Future<void> remove(String id) async {
    final row = await (_db.select(
      _db.todoReminders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('提醒规则不存在：$id');
    }

    await _db.transaction(() async {
      await (_db.delete(_db.todoReminders)..where((t) => t.id.equals(id))).go();
      await _queue.enqueue(
        entity: SyncEntities.reminder,
        op: SyncOps.delete,
        localId: row.id,
        serverId: row.serverId,
        payload: {'id': row.id, 'serverId': row.serverId},
      );
    });
  }

  Future<TodoReminder> enablePersistentByServerId({
    required int reminderServerId,
    required int intervalMinutes,
  }) async {
    final row = await (_db.select(
      _db.todoReminders,
    )..where((t) => t.serverId.equals(reminderServerId))).getSingleOrNull();
    if (row == null) {
      throw StateError('本地提醒规则不存在：$reminderServerId');
    }
    return update(
      id: row.id,
      fireAt: row.remindAt,
      anchorType: row.anchorType,
      offsetMinutes: row.offsetMinutes,
      persistent: true,
      intervalMinutes: intervalMinutes,
      timeZone: row.timeZone,
      fixedTimezone: row.fixedTimezone,
    );
  }

  void _validatePersistentInterval(bool persistent, int? intervalMinutes) {
    if (!persistent) return;
    if (intervalMinutes != null && intervalMinutes > 0) return;
    throw ArgumentError.value(
      intervalMinutes,
      'intervalMinutes',
      '持续提醒间隔必须为正分钟数',
    );
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
