import 'dart:convert';

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
    await _db.transaction(
      () => _save(
        listId: listId,
        groupDimension: groupDimension,
        columnsJson: columnsJson,
      ),
    );
  }

  /// 重新应用当前清单最近一次失败的偏好变更。
  ///
  /// 原变更保留为 `resolved`，新的 upsert 通过既有 outbox 正常重试，避免
  /// Widget 直接解析 payload 或修改同步队列。
  Future<bool> recoverLatestFailed({required String listId}) async {
    return _db.transaction(() async {
      final list = await (_db.select(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).getSingleOrNull();
      if (list == null) return false;
      final changes =
          await (_db.select(_db.todoSyncChanges)
                ..where(
                  (row) =>
                      row.entity.equals(SyncEntities.boardPreference) &
                      row.status.equals('failed'),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
              .get();
      for (final change in changes) {
        final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
        final payloadListId = payload['listId']?.toString();
        if (payloadListId != listId &&
            payloadListId != list.serverId?.toString()) {
          continue;
        }
        final groupDimension = payload['groupDimension']?.toString();
        if (groupDimension == null || groupDimension.trim().isEmpty) {
          return false;
        }
        await _save(
          listId: listId,
          groupDimension: groupDimension,
          columnsJson: payload['columnsJson']?.toString(),
        );
        await (_db.update(_db.todoSyncChanges)
              ..where((row) => row.id.equals(change.id)))
            .write(const TodoSyncChangesCompanion(status: Value('resolved')));
        return true;
      }
      return false;
    });
  }

  Future<void> _save({
    required String listId,
    required String groupDimension,
    required String? columnsJson,
  }) async {
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
  }
}
