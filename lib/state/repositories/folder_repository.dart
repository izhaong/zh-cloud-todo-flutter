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
    return (_db.select(_db.todoFolders)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<TodoFolder> create(String name) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.into(_db.todoFolders).insert(
      TodoFoldersCompanion.insert(
        id: id,
        name: name,
        updatedAt: now,
        createdAt: now,
      ),
    );
    final row = await (_db.select(_db.todoFolders)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.upsert,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoFolder> rename(String folderId, String newName) async {
    final now = DateTime.now();
    await (_db.update(_db.todoFolders)..where((t) => t.id.equals(folderId)))
        .write(TodoFoldersCompanion(
      name: Value(newName),
      updatedAt: Value(now),
    ));
    final row = await (_db.select(_db.todoFolders)
          ..where((t) => t.id.equals(folderId)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.upsert,
      localId: folderId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  Future<void> delete(String folderId) async {
    // folder 走 REST：本地主键为 String id；todo_lists.folderId 引用的是文件夹
    // 的服务端整数 id (serverId)。删除时按 serverId 找到指向该 folder 的清单，
    // 将其 folderId 置 null（未同步的 folder 尚未有 serverId，无需处理）。
    final row = await (_db.select(_db.todoFolders)
          ..where((t) => t.id.equals(folderId)))
        .getSingleOrNull();
    final serverId = row?.serverId;
    if (serverId != null) {
      await (_db.update(_db.todoLists)
            ..where((t) => t.folderId.equals(serverId)))
          .write(const TodoListsCompanion(folderId: Value(null)));
    }
    await (_db.delete(_db.todoFolders)..where((t) => t.id.equals(folderId))).go();
    await _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.delete,
      localId: folderId,
      serverId: row?.serverId,
      payload: {'id': folderId, 'serverId': row?.serverId},
    );
  }
}
