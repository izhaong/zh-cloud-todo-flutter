import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import 'task_query_repository.dart';

/// 每个清单独立的任务排序偏好。
///
/// 用户库已按 tenant/user 隔离；在库内再以 `TASK_SORT + listId` 唯一，
/// 让不同清单、离线重启和跨端同步使用同一份偏好实体。
class TaskSortPreferenceRepository {
  TaskSortPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'TASK_SORT';
  static const _inboxSourceKey = 'inbox';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TaskSort> get(String? listId) async {
    final row =
        await (_db.select(_db.todoViewPreferences)..where(
              (preference) =>
                  preference.sourceType.equals(_sourceType) &
                  preference.sourceKey.equals(_sourceKey(listId)),
            ))
            .getSingleOrNull();
    return _decode(row?.valueJson);
  }

  Stream<TaskSort> watch(String? listId) {
    return (_db.select(_db.todoViewPreferences)..where(
          (preference) =>
              preference.sourceType.equals(_sourceType) &
              preference.sourceKey.equals(_sourceKey(listId)),
        ))
        .watchSingleOrNull()
        .map((row) => _decode(row?.valueJson));
  }

  Future<void> save(String? listId, TaskSort sort) async {
    final sourceKey = _sourceKey(listId);
    final now = DateTime.now();
    final valueJson = jsonEncode({'sort': sort.name});
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (preference) =>
                    preference.sourceType.equals(_sourceType) &
                    preference.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      final companion = TodoViewPreferencesCompanion(
        id: Value(id),
        serverId: existing?.serverId == null
            ? const Value.absent()
            : Value(existing!.serverId),
        sourceType: const Value(_sourceType),
        sourceKey: Value(sourceKey),
        valueJson: Value(valueJson),
        updatedAt: Value(now),
        createdAt: existing == null ? Value(now) : Value(existing.createdAt),
      );
      if (existing == null) {
        await _db.into(_db.todoViewPreferences).insert(companion);
      } else {
        await (_db.update(
          _db.todoViewPreferences,
        )..where((preference) => preference.id.equals(id))).write(companion);
      }
      await _queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: id,
        serverId: existing?.serverId,
        payload: {
          'sourceType': _sourceType,
          'sourceKey': sourceKey,
          'viewType': 'LIST',
          'valueJson': valueJson,
        },
      );
    });
  }

  String _sourceKey(String? listId) =>
      listId == null || listId.isEmpty ? _inboxSourceKey : listId;

  TaskSort _decode(String? valueJson) {
    if (valueJson == null) return TaskSort.smart;
    try {
      final raw = jsonDecode(valueJson);
      final value = raw is Map<String, dynamic> ? raw['sort'] : null;
      return TaskSort.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => TaskSort.smart,
      );
    } on FormatException {
      return TaskSort.smart;
    }
  }
}
