import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../sync_change_queue.dart';

/// M11-B2 清单 / 智能清单仓库。
///
/// - 写操作入 drift（UI 真相源）
/// - 同时 [SyncChangeQueue.enqueue] 把 mutation 投到 [TodoSyncChanges]
/// - 智能清单（`smart:` 前缀的 list）由 [SmartListFilter] 解析
class ListRepository {
  ListRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

  /// 顶层非智能清单（不解析 smart 前缀），按 folderId / sortOrder 排序。
  Stream<List<TodoList>> watchAll() {
    return (_db.select(_db.todoLists)
          ..where((t) => t.name.like('smart:%').not())
          ..orderBy([
            (t) => OrderingTerm(expression: t.folderId),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<List<TodoList>> getAll() {
    return (_db.select(_db.todoLists)
          ..where((t) => t.name.like('smart:%').not())
          ..orderBy([
            (t) => OrderingTerm(expression: t.folderId),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
        .get();
  }

  Future<List<TodoList>> getSmartLists() {
    return (_db.select(_db.todoLists)
          ..where((t) => t.name.like('smart:%'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Stream<List<TodoList>> watchSmartLists() {
    return (_db.select(_db.todoLists)
          ..where((t) => t.name.like('smart:%'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<TodoList> create({
    required String name,
    int? folderId,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();
    final id = await _db.into(_db.todoLists).insert(
      TodoListsCompanion.insert(
        name: name,
        folderId: Value(folderId),
        sortOrder: Value(sortOrder),
        updatedAt: now,
        createdAt: now,
      ),
    );
    final row = await (_db.select(_db.todoLists)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.create,
      localId: id,
      payload: row.toJson(),
    );
    return row;
  }

  Future<TodoList> rename(int listId, String newName) async {
    final now = DateTime.now();
    await (_db.update(_db.todoLists)..where((t) => t.id.equals(listId)))
        .write(TodoListsCompanion(
      name: Value(newName),
      updatedAt: Value(now),
    ));
    final row = await (_db.select(_db.todoLists)
          ..where((t) => t.id.equals(listId)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.update,
      localId: listId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  Future<void> reorder(List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.todoLists)
            ..where((t) => t.id.equals(orderedIds[i])))
          .write(TodoListsCompanion(
        sortOrder: Value(i),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// 删除清单：调用方应先 [countOpenTasksByList]，如有未完成任务需拦截。
  Future<void> delete(int listId) async {
    final row = await (_db.select(_db.todoLists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    await (_db.delete(_db.todoLists)..where((t) => t.id.equals(listId)))
        .go();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.delete,
      localId: listId,
      serverId: row?.serverId,
      payload: {'id': listId, 'serverId': row?.serverId},
    );
  }

  /// 把过滤条件物化为"智能清单"：name = `smart:<filterName>`，payloadJson 写进 description。
  Future<TodoList> saveSmart({
    required String filterName,
    required Map<String, dynamic> filter,
  }) async {
    final now = DateTime.now();
    final id = await _db.into(_db.todoLists).insert(
      TodoListsCompanion.insert(
        name: 'smart:$filterName',
        folderId: const Value(null),
        sortOrder: const Value(0),
        updatedAt: now,
        createdAt: now,
      ),
    );
    final row = await (_db.select(_db.todoLists)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.create,
      localId: id,
      payload: {
        ...row.toJson(),
        'isSmart': true,
        'filter': filter,
      },
    );
    return row;
  }
}

/// 智能清单过滤器（解析保存时写入的 filter map）。
class SmartListFilter {
  SmartListFilter({
    this.listId,
    this.folderId,
    this.tagIds = const [],
    this.priority,
    this.dueRange, // 'today' | 'overdue' | 'all' | 'completed' | 'incomplete'
    this.completed,
  });

  final int? listId;
  final int? folderId;
  final List<int> tagIds;
  final int? priority;
  final String? dueRange;
  final bool? completed;

  Map<String, dynamic> toJson() => {
    'listId': listId,
    'folderId': folderId,
    'tagIds': tagIds,
    'priority': priority,
    'dueRange': dueRange,
    'completed': completed,
  };

  factory SmartListFilter.fromJson(Map<String, dynamic> json) {
    return SmartListFilter(
      listId: json['listId'] as int?,
      folderId: json['folderId'] as int?,
      tagIds: (json['tagIds'] as List?)?.cast<int>() ?? const [],
      priority: json['priority'] as int?,
      dueRange: json['dueRange'] as String?,
      completed: json['completed'] as bool?,
    );
  }

  factory SmartListFilter.fromListName(String listName) {
    // 解析 `smart:<filterName>` 中的 filterName 后回退到默认 = 全部
    if (!listName.startsWith('smart:')) {
      return SmartListFilter();
    }
    final name = listName.substring('smart:'.length);
    switch (name) {
      case 'today':
        return SmartListFilter(dueRange: 'today');
      case 'overdue':
        return SmartListFilter(dueRange: 'overdue');
      case 'completed':
        return SmartListFilter(completed: true);
      case 'all':
        return SmartListFilter();
      default:
        return SmartListFilter();
    }
  }
}