import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// M11-B2 任务仓库。
///
/// - 写操作入 drift（UI 真相源）+ sync_queue
/// - 子任务通过 [parentTaskId] 维护
/// - ID：本地 UUID（真相源），写入即生成；serverId 由 sync 层回写。
class TaskRepository {
  TaskRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  /// 顶层任务（无 parent）的 stream，按 listId 过滤。[listId] 本地 UUID。
  Stream<List<TodoTask>> watchTopLevelByList(String listId) {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.listId.equals(listId) & t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Stream<List<TodoTask>> watchChildrenOf(String parentTaskId) {
    return _db.watchChildrenOf(parentTaskId);
  }

  Stream<List<TodoTask>> watchAll() {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<TodoTask?> getById(String id) {
    return (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<TodoTask?> watchById(String id) {
    return (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<TodoTask> create({
    required String listId,
    required String title,
    String? description,
    int priority = 0,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    String? parentTaskId,
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: id,
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
    final row = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(id))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoTask> update(
    String taskId, {
    String? title,
    String? description,
    int? priority,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    String? listId,
    bool? isPinned,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.todoTasks)..where((t) => t.id.equals(taskId))).write(
      TodoTasksCompanion(
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
      ),
    );
    final row = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
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
  Future<TodoTask> togglePin(String taskId) async {
    final current = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    final next = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );
    await (_db.update(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).write(next);
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
  Future<TodoTask> toggleComplete(String taskId) async {
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

  Future<void> delete(String taskId) async {
    final row = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    final descendants = await _collectDescendants(taskId);
    for (final d in descendants.reversed) {
      await (_db.delete(
        _db.todoTaskTags,
      )..where((t) => t.taskId.equals(d.id))).go();
      await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(d.id))).go();
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
    await (_db.delete(
      _db.todoTaskTags,
    )..where((t) => t.taskId.equals(taskId))).go();
    await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(taskId))).go();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.delete,
      localId: taskId,
      serverId: row?.serverId,
      payload: {'id': taskId, 'serverId': row?.serverId},
    );
  }

  /// 计算任务在父子链中的深度（自身为 0，即顶层任务 = 0）。
  ///
  /// 用于 §2.2 子任务深度 ≤5 的抽屉：在 [parentTaskId] 下新增子任务前校验
  /// `depthOf(parentTaskId) < 5`，避免超过服务端嵌套上限。
  Future<int> depthOf(String taskId) async {
    var depth = 0;
    var current = taskId;
    while (true) {
      final row = await (_db.select(
        _db.todoTasks,
      )..where((t) => t.id.equals(current))).getSingleOrNull();
      final parent = row?.parentTaskId;
      if (parent == null) return depth;
      depth += 1;
      current = parent;
    }
  }

  Future<List<TodoTask>> _collectDescendants(String parentId) async {
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

  Future<void> reparent(String taskId, String? newParentId) async {
    if (taskId == newParentId) {
      throw ArgumentError.value(newParentId, 'newParentId', '任务不能引用自身');
    }
    final task = await (_db.select(
      _db.todoTasks,
    )..where((row) => row.id.equals(taskId))).getSingleOrNull();
    if (task == null) {
      throw StateError('任务不存在');
    }
    await _assertParentChainDoesNotContain(taskId, newParentId);
    await _db.reparentTask(taskId, newParentId);
    final row = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
  }

  Future<void> _assertParentChainDoesNotContain(
    String taskId,
    String? newParentId,
  ) async {
    var currentId = newParentId;
    final visited = <String>{};
    var parentChainLength = 0;
    while (currentId != null) {
      final parentId = currentId;
      if (parentId == taskId || !visited.add(parentId)) {
        throw StateError('任务父子关系形成循环');
      }
      if (parentChainLength >= 5) {
        throw StateError('任务层级不能超过五级');
      }
      final current = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(parentId))).getSingleOrNull();
      if (current == null) {
        throw StateError('父任务不存在');
      }
      currentId = current.parentTaskId;
      parentChainLength += 1;
    }
  }
}
