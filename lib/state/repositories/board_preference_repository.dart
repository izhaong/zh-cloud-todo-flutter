import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// B4 看板偏好本地优先写链路。
class BoardPreferenceRepository {
  BoardPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<void> save({
    required String listId,
    required String groupDimension,
    String? columnsJson,
  }) async {
    if (groupDimension.trim().isEmpty) {
      throw ArgumentError.value(groupDimension, 'groupDimension', '分组维度不能为空');
    }
    await _db.transaction(() async {
      final list = await (_db.select(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).getSingleOrNull();
      if (list == null) throw StateError('清单不存在');
      final existing = await (_db.select(
        _db.todoBoardPreferences,
      )..where((row) => row.listId.equals(listId))).getSingleOrNull();
      final now = DateTime.now();
      final companion = TodoBoardPreferencesCompanion(
        id: Value(existing?.id ?? _uuid.v4()),
        serverId: Value(existing?.serverId),
        listId: Value(listId),
        groupDimension: Value(groupDimension),
        columnsJson: Value(columnsJson),
        updatedAt: Value(now),
        createdAt: Value(existing?.createdAt ?? now),
      );
      if (existing == null) {
        await _db.into(_db.todoBoardPreferences).insert(companion);
      } else {
        await (_db.update(
          _db.todoBoardPreferences,
        )..where((row) => row.id.equals(existing.id))).write(companion);
      }
      final saved = await (_db.select(
        _db.todoBoardPreferences,
      )..where((row) => row.listId.equals(listId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.boardPreference,
        op: SyncOps.upsert,
        localId: saved.id,
        serverId: saved.serverId,
        payload: {
          'listId': list.serverId ?? listId,
          'groupDimension': saved.groupDimension,
          'columnsJson': saved.columnsJson,
        },
      );
    });
  }
}
