import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// M11-B2 标签仓库（含 task_tag 关联）。
class TagRepository {
  TagRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

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
    return (_db.select(_db.todoTags)..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
        .watch();
  }

  Future<List<TodoTag>> getAll() {
    return (_db.select(_db.todoTags)..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
        .get();
  }

  Future<TodoTag> create({
    required String name,
    String? color,
    String? parentId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: id,
            parentId: Value(parentId),
            name: name,
            color: Value(color),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final row = await (_db.select(
      _db.todoTags,
    )..where((t) => t.id.equals(id))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.upsert,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoTag> update(
    String tagId, {
    String? name,
    String? color,
    required String? parentId,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.todoTags)..where((t) => t.id.equals(tagId))).write(
      TodoTagsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        color: color == null ? const Value.absent() : Value(color),
        parentId: Value(parentId),
        updatedAt: Value(now),
      ),
    );
    final row = await (_db.select(
      _db.todoTags,
    )..where((t) => t.id.equals(tagId))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.upsert,
      localId: tagId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  /// 置顶或取消置顶标签（嘀嗒《04-用标签管理任务》:79 侧边栏左滑出现「置顶」、
  /// :94 右键同样出现「置顶」）。
  ///
  /// 与 [update] 同一条口径：本地写入与 tag/upsert outbox 必须一起落，
  /// payload 走 `toJson()`，服务端 `todo_tag.is_pinned` 收同一字段名。
  /// 允许多个标签同时置顶 —— 标签这页原文没有「只支持置顶一个」那种话。
  Future<TodoTag> setPinned(String tagId, bool pinned) async {
    final now = DateTime.now();
    await (_db.update(_db.todoTags)..where((t) => t.id.equals(tagId))).write(
      TodoTagsCompanion(isPinned: Value(pinned), updatedAt: Value(now)),
    );
    final row = await (_db.select(
      _db.todoTags,
    )..where((t) => t.id.equals(tagId))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.tag,
      op: SyncOps.upsert,
      localId: tagId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  Future<void> delete(String tagId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.todoTags,
      )..where((t) => t.id.equals(tagId))).getSingleOrNull();
      final children = await (_db.select(
        _db.todoTags,
      )..where((tag) => tag.parentId.equals(tagId))).get();
      final now = DateTime.now();
      for (final child in children) {
        await (_db.update(
          _db.todoTags,
        )..where((tag) => tag.id.equals(child.id))).write(
          TodoTagsCompanion(parentId: const Value(null), updatedAt: Value(now)),
        );
        final reparented = await (_db.select(
          _db.todoTags,
        )..where((tag) => tag.id.equals(child.id))).getSingle();
        await _queue.enqueue(
          entity: SyncEntities.tag,
          op: SyncOps.upsert,
          localId: child.id,
          serverId: child.serverId,
          payload: reparented.toJson(),
        );
      }
      await (_db.delete(
        _db.todoTaskTags,
      )..where((t) => t.tagId.equals(tagId))).go();
      await (_db.delete(_db.todoTags)..where((t) => t.id.equals(tagId))).go();
      await _queue.enqueue(
        entity: SyncEntities.tag,
        op: SyncOps.delete,
        localId: tagId,
        serverId: row?.serverId,
        payload: {'id': tagId, 'serverId': row?.serverId},
      );
    });
  }

  // --- 任务-标签关联 --------------------------------------------------

  Stream<List<TodoTag>> watchTagsOfTask(String taskId) {
    final q = _db.select(_db.todoTaskTags).join([
      innerJoin(
        _db.todoTags,
        _db.todoTags.id.equalsExp(_db.todoTaskTags.tagId),
      ),
    ])..where(_db.todoTaskTags.taskId.equals(taskId));
    return q.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.todoTags)).toList(),
    );
  }

  /// 整表「任务 id → 标签 id 集合」索引。筛选要对整页任务求值，逐条 `tagIdsOf`
  /// 会打成 N 次查询；列表渲染与高级筛选预览都同源用这一份。
  Stream<Map<String, Set<String>>> watchTagIndex() {
    return _db.select(_db.todoTaskTags).watch().map((rows) {
      final out = <String, Set<String>>{};
      for (final row in rows) {
        out.putIfAbsent(row.taskId, () => <String>{}).add(row.tagId);
      }
      return out;
    });
  }

  Future<List<String>> tagIdsOf(String taskId) async {
    final rows = await (_db.select(
      _db.todoTaskTags,
    )..where((t) => t.taskId.equals(taskId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    final normalizedTagIds = tagIds.toSet().toList();
    await _db.transaction(() async {
      await (_db.delete(
        _db.todoTaskTags,
      )..where((t) => t.taskId.equals(taskId))).go();
      for (final tagId in normalizedTagIds) {
        await _db
            .into(_db.todoTaskTags)
            .insert(
              TodoTaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await _queue.enqueue(
        entity: SyncEntities.taskTag,
        op: SyncOps.upsert,
        localId: taskId,
        payload: {'taskId': taskId, 'tagIds': normalizedTagIds},
      );
    });
  }
}
