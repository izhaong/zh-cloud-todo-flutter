import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../sync_change_queue.dart';

/// M11-B2 任务仓库。
///
/// - 写操作入 drift（UI 真相源）+ sync_queue
/// - 子任务通过 [parentTaskId] 维护
class TaskRepository {
  TaskRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

  /// 顶层任务（无 parent）的 stream，按 listId 过滤。
  Stream<List<TodoTask>> watchTopLevelByList(int listId) {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.listId.equals(listId) & t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Stream<List<TodoTask>> watchChildrenOf(int parentTaskId) {
    return _db.watchChildrenOf(parentTaskId);
  }

  Stream<List<TodoTask>> watchAll() {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<TodoTask?> getById(int id) {
    return (_db.select(_db.todoTasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<TodoTask> create({
    required int listId,
    required String title,
    String? description,
    int priority = 0,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    int? parentTaskId,
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    final id = await _db.into(_db.todoTasks).insert(
      TodoTasksCompanion.insert(
        listId: listId,
        parentTaskId: Value(parentTaskId),
        title: title,
        description: Value(description),
        priority: Value(priority),
        isPinned: Value(isPinned),
        startAt: Value(startAt),
        endAt: Value(endAt),
        dueAt: Value(dueAt),
        updatedAt: now,
        createdAt: now,
      ),
    );
    final row = await (_db.select(_db.todoTasks)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoTask> update(
    int taskId, {
    String? title,
    String? description,
    int? priority,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    int? listId,
    bool? isPinned,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.todoTasks)..where((t) => t.id.equals(taskId)))
        .write(TodoTasksCompanion(
      title: title == null ? const Value.absent() : Value(title),
      description: description == null
          ? const Value.absent()
          : Value(description),
      priority: priority == null ? const Value.absent() : Value(priority),
      isPinned: isPinned == null ? const Value.absent() : Value(isPinned),
      startAt: startAt == null ? const Value.absent() : Value(startAt),
      endAt: endAt == null ? const Value.absent() : Value(endAt),
      dueAt: dueAt == null ? const Value.absent() : Value(dueAt),
      listId: listId == null ? const Value.absent() : Value(listId),
      updatedAt: Value(now),
    ));
    final row = await (_db.select(_db.todoTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  /// 切换置顶状态 + sync_queue。
  Future<TodoTask> togglePin(int taskId) async {
    final current = await (_db.select(_db.todoTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingle();
    final next = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );
    await (_db.update(_db.todoTasks)..where((t) => t.id.equals(taskId)))
        .write(next);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: next.serverId,
      payload: next.toJson(),
    );
    return next;
  }

  /// 切换完成状态 + sync_queue。
  Future<TodoTask> toggleComplete(int taskId) async {
    final next = await _db.toggleTaskComplete(taskId);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: next.serverId,
      payload: next.toJson(),
    );
    return next;
  }

  Future<void> delete(int taskId) async {
    final row = await (_db.select(_db.todoTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    // 递归收集所有后代任务
    final descendants = await _collectDescendants(taskId);
    // 从最深层开始删除，避免孤儿
    for (final d in descendants.reversed) {
      await (_db.delete(_db.todoTaskTags)..where((t) => t.taskId.equals(d.id)))
          .go();
      await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(d.id))).go();
      // 为有 serverId 的后代入队 sync delete
      if (d.serverId != null) {
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.delete,
          localId: d.id,
          serverId: d.serverId,
          payload: {'id': d.id, 'serverId': d.serverId},
        );
      }
    }
    await (_db.delete(_db.todoTaskTags)..where((t) => t.taskId.equals(taskId)))
        .go();
    await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(taskId))).go();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.delete,
      localId: taskId,
      serverId: row?.serverId,
      payload: {'id': taskId, 'serverId': row?.serverId},
    );
  }

  /// 递归收集 taskId 的所有后代（BFS，含孙级及更深）。
  Future<List<TodoTask>> _collectDescendants(int parentId) async {
    final result = <TodoTask>[];
    final queue = [parentId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = await _db.childrenOf(current);
      for (final c in children) {
        result.add(c);
        queue.add(c.id);
      }
    }
    return result;
  }

  Future<void> reparent(int taskId, int? newParentId) async {
    await _db.reparentTask(taskId, newParentId);
    final row = await (_db.select(_db.todoTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
  }
}