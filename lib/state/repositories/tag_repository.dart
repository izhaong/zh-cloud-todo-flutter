import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../sync_change_queue.dart';

/// M11-B2 标签仓库（含 task_tag 关联）。
class TagRepository {
  TagRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

  /// 固定 8 色供选择（写入时存为 hex 字符串）。
  static const palette = <String>[
    '#E53935',
    '#FB8C00',
    '#FDD835',
    '#43A047',
    '#1E88E5',
    '#5E35B1',
    '#D81B60',
    '#6D4C41',
  ];

  Stream<List<TodoTag>> watchAll() {
    return (_db.select(_db.todoTags)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<List<TodoTag>> getAll() {
    return (_db.select(_db.todoTags)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<TodoTag> create({required String name, String? color}) async {
    final now = DateTime.now();
    final id = await _db.into(_db.todoTags).insert(
      TodoTagsCompanion.insert(
        name: name,
        color: Value(color),
        updatedAt: now,
        createdAt: now,
      ),
    );
    final row = await (_db.select(_db.todoTags)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.upsert,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoTag> update(int tagId, {String? name, String? color}) async {
    final now = DateTime.now();
    await (_db.update(_db.todoTags)..where((t) => t.id.equals(tagId)))
        .write(TodoTagsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      color: color == null ? const Value.absent() : Value(color),
      updatedAt: Value(now),
    ));
    final row = await (_db.select(_db.todoTags)
          ..where((t) => t.id.equals(tagId)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.upsert,
      localId: tagId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  Future<void> delete(int tagId) async {
    final row = await (_db.select(_db.todoTags)
          ..where((t) => t.id.equals(tagId)))
        .getSingleOrNull();
    await (_db.delete(_db.todoTaskTags)..where((t) => t.tagId.equals(tagId)))
        .go();
    await (_db.delete(_db.todoTags)..where((t) => t.id.equals(tagId)))
        .go();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.delete,
      localId: tagId,
      serverId: row?.serverId,
      payload: {'id': tagId, 'serverId': row?.serverId},
    );
  }

  // --- 任务-标签关联 --------------------------------------------------

  Stream<List<TodoTag>> watchTagsOfTask(int taskId) {
    final q = _db.select(_db.todoTaskTags).join([
      innerJoin(
        _db.todoTags,
        _db.todoTags.id.equalsExp(_db.todoTaskTags.tagId),
      ),
    ])
      ..where(_db.todoTaskTags.taskId.equals(taskId));
    return q.watch().map((rows) => rows.map((r) => r.readTable(_db.todoTags)).toList());
  }

  Future<List<int>> tagIdsOf(int taskId) async {
    final rows = await (_db.select(_db.todoTaskTags)
          ..where((t) => t.taskId.equals(taskId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }

  /// 替换某个任务的标签集合。
  Future<void> setTaskTags(int taskId, List<int> tagIds) async {
    await (_db.delete(_db.todoTaskTags)..where((t) => t.taskId.equals(taskId)))
        .go();
    for (final tagId in tagIds.toSet()) {
      await _db.into(_db.todoTaskTags).insert(
        TodoTaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }
    await _queue.enqueue(
      entity: SyncEntities.taskTag,
      op: SyncOps.upsert,
      localId: taskId,
      payload: {'taskId': taskId, 'tagIds': tagIds},
    );
  }
}