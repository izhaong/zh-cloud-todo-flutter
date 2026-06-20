import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../sync_change_queue.dart';

/// M11-B2 文件夹仓库。
class FolderRepository {
  FolderRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

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
    final id = await _db.into(_db.todoFolders).insert(
      TodoFoldersCompanion.insert(
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
      op: SyncOps.create,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoFolder> rename(int folderId, String newName) async {
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
      op: SyncOps.update,
      localId: folderId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  /// 删除文件夹：下挂清单会被置 folderId=null（保留 list）。
  Future<void> delete(int folderId) async {
    final row = await (_db.select(_db.todoFolders)
          ..where((t) => t.id.equals(folderId)))
        .getSingleOrNull();
    await (_db.update(_db.todoLists)
          ..where((t) => t.folderId.equals(folderId)))
        .write(const TodoListsCompanion(folderId: Value(null)));
    await (_db.delete(_db.todoFolders)..where((t) => t.id.equals(folderId)))
        .go();
    await _queue.enqueue(
      entity: SyncEntities.folder,
      op: SyncOps.delete,
      localId: folderId,
      serverId: row?.serverId,
      payload: {'id': folderId, 'serverId': row?.serverId},
    );
  }
}