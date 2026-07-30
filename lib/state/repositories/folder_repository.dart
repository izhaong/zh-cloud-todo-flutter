import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// M11-B2 文件夹仓库。
///
/// 文件夹不在后端 `/sync` 白名单，走普通 REST（`/app-api/todo/folder`）；
/// 本地缓存展示 + 复用 outbox 做离线重试。
class FolderRepository {
  FolderRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Stream<List<TodoFolder>> watchAll() {
    return (_db.select(_db.todoFolders)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
        .watch();
  }

  Future<TodoFolder> create(String name, {String? parentId}) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _validateParent(folderId: id, parentId: parentId);
    await _db
        .into(_db.todoFolders)
        .insert(
          TodoFoldersCompanion.insert(
            id: id,
            parentId: Value(parentId),
            name: name,
            updatedAt: now,
            createdAt: now,
          ),
        );
    final row = await (_db.select(
      _db.todoFolders,
    )..where((t) => t.id.equals(id))).getSingle();
    await _enqueueUpsert(row);
    return row;
  }

  Future<TodoFolder> rename(String folderId, String newName) async {
    final now = DateTime.now();
    await (_db.update(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).write(
      TodoFoldersCompanion(name: Value(newName), updatedAt: Value(now)),
    );
    final row = await (_db.select(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).getSingle();
    await _enqueueUpsert(row);
    return row;
  }

  Future<TodoFolder> moveToParent(String folderId, String? parentId) async {
    await _validateParent(folderId: folderId, parentId: parentId);
    final now = DateTime.now();
    await (_db.update(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).write(
      TodoFoldersCompanion(parentId: Value(parentId), updatedAt: Value(now)),
    );
    final row = await (_db.select(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).getSingle();
    await _enqueueUpsert(row);
    return row;
  }

  Future<void> delete(String folderId) async {
    // folder 走 REST：本地主键为 String id；todo_lists.folderId 引用的是文件夹
    // 的服务端整数 id (serverId)。删除时按 serverId 找到指向该 folder 的清单，
    // 将其 folderId 置 null（未同步的 folder 尚未有 serverId，无需处理）。
    final row = await (_db.select(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).getSingleOrNull();
    final serverId = row?.serverId;
    if (serverId != null) {
      await (_db.update(_db.todoLists)
            ..where((t) => t.folderId.equals(serverId)))
          .write(const TodoListsCompanion(folderId: Value(null)));
    }
    final children = await (_db.select(
      _db.todoFolders,
    )..where((folder) => folder.parentId.equals(folderId))).get();
    final now = DateTime.now();
    for (final child in children) {
      await (_db.update(
        _db.todoFolders,
      )..where((folder) => folder.id.equals(child.id))).write(
        TodoFoldersCompanion(
          parentId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      final promoted = await (_db.select(
        _db.todoFolders,
      )..where((folder) => folder.id.equals(child.id))).getSingle();
      await _enqueueUpsert(promoted);
    }
    await (_db.delete(
      _db.todoFolders,
    )..where((t) => t.id.equals(folderId))).go();
    await _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.delete,
      localId: folderId,
      serverId: row?.serverId,
      payload: {'id': folderId, 'serverId': row?.serverId},
    );
  }

  Future<void> _validateParent({
    required String folderId,
    required String? parentId,
  }) async {
    if (parentId == null) return;
    if (parentId == folderId) {
      throw StateError('文件夹不能以自身为父级');
    }
    final visited = <String>{};
    var currentId = parentId;
    while (true) {
      if (currentId == folderId || !visited.add(currentId)) {
        throw StateError('文件夹父子关系存在循环');
      }
      final current = await (_db.select(
        _db.todoFolders,
      )..where((folder) => folder.id.equals(currentId))).getSingleOrNull();
      if (current == null) {
        throw StateError('父文件夹不存在');
      }
      final nextId = current.parentId;
      if (nextId == null) return;
      currentId = nextId;
    }
  }

  Future<void> _enqueueUpsert(TodoFolder row) async {
    if (row.serverId == null) {
      final pending =
          await (_db.select(_db.todoSyncChanges)
                ..where(
                  (change) =>
                      change.entity.equals(SyncEntities.folder) &
                      change.op.equals(SyncOps.upsert) &
                      change.entityLocalId.equals(row.id) &
                      change.entityServerId.isNull() &
                      (change.status.equals('queued') |
                          change.status.equals('retryable')),
                )
                ..orderBy([(change) => OrderingTerm.asc(change.id)])
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) {
        await (_db.update(
          _db.todoSyncChanges,
        )..where((change) => change.id.equals(pending.id))).write(
          TodoSyncChangesCompanion(
            payloadJson: Value(jsonEncode(row.toJson())),
            status: const Value('queued'),
            attemptCount: const Value(0),
            nextAttemptAt: const Value(null),
            failureReason: const Value(null),
          ),
        );
        return;
      }
    }
    return _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.upsert,
      localId: row.id,
      serverId: row.serverId,
      payload: row.toJson(),
    );
  }
}
