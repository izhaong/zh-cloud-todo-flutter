import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// M11-B2 清单 / 智能清单仓库。
///
/// - 写操作入 drift（UI 真相源）+ sync_queue
/// - 智能清单（`smart:` 前缀的 list）由 [SmartListFilter] 解析
class ListRepository {
  ListRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  /// 顶层非智能清单（不解析 smart 前缀），按本地 folder UUID / sortOrder 排序。
  Stream<List<TodoList>> watchAll() {
    return (_db.select(_db.todoLists)
          ..where(
            (t) => t.name.like('smart:%').not() & t.id.equals('inbox').not(),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.folderLocalId),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<List<TodoList>> getAll() {
    return (_db.select(_db.todoLists)
          ..where(
            (t) => t.name.like('smart:%').not() & t.id.equals('inbox').not(),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.folderLocalId),
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
    String? folderLocalId,
    int sortOrder = 0,
  }) async {
    return _db.transaction(() async {
      final folder = await _folderByLocalId(folderLocalId);
      final now = DateTime.now();
      final id = _uuid.v4();
      await _db
          .into(_db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: id,
              name: name,
              folderLocalId: Value(folderLocalId),
              folderId: Value(folder?.serverId),
              sortOrder: Value(sortOrder),
              updatedAt: now,
              createdAt: now,
            ),
          );
      final row = await (_db.select(
        _db.todoLists,
      )..where((t) => t.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.list,
        op: SyncOps.upsert,
        localId: id,
        payload: row.toJson(),
      );
      return row;
    });
  }

  Future<TodoList> rename(String listId, String newName) async {
    final now = DateTime.now();
    await (_db.update(_db.todoLists)..where((t) => t.id.equals(listId))).write(
      TodoListsCompanion(name: Value(newName), updatedAt: Value(now)),
    );
    final row = await (_db.select(
      _db.todoLists,
    )..where((t) => t.id.equals(listId))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.upsert,
      localId: listId,
      serverId: row.serverId,
      payload: row.toJson(),
    );
    return row;
  }

  /// 将普通清单移入本地 [folderLocalId]，或传 null 移到顶层。
  ///
  /// folder 是 REST 特例，但 list 仍是同步白名单实体：本地更新与 list/upsert
  /// outbox 必须一起写入，才能让另一个设备经正常 pull 恢复组织关系。
  Future<TodoList> moveToFolder(String listId, String? folderLocalId) async {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).getSingleOrNull();
      if (existing == null) {
        throw StateError('清单不存在');
      }
      if (existing.name.startsWith('smart:')) {
        throw StateError('智能清单不支持移动到文件夹');
      }
      final folder = await _folderByLocalId(folderLocalId);
      await (_db.update(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).write(
        TodoListsCompanion(
          folderLocalId: Value(folderLocalId),
          folderId: Value(folder?.serverId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final moved = await (_db.select(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.list,
        op: SyncOps.upsert,
        localId: listId,
        serverId: moved.serverId,
        payload: moved.toJson(),
      );
      return moved;
    });
  }

  Future<TodoFolder?> _folderByLocalId(String? folderLocalId) async {
    if (folderLocalId == null) return null;
    final folder = await (_db.select(
      _db.todoFolders,
    )..where((row) => row.id.equals(folderLocalId))).getSingleOrNull();
    if (folder == null) {
      throw StateError('文件夹不存在');
    }
    return folder;
  }

  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(
        _db.todoLists,
      )..where((t) => t.id.equals(orderedIds[i]))).write(
        TodoListsCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> delete(String listId) async {
    final row = await (_db.select(
      _db.todoLists,
    )..where((t) => t.id.equals(listId))).getSingleOrNull();
    await (_db.delete(_db.todoLists)..where((t) => t.id.equals(listId))).go();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.delete,
      localId: listId,
      serverId: row?.serverId,
      payload: {'id': listId, 'serverId': row?.serverId},
    );
  }

  Future<TodoList> saveSmart({
    required String filterName,
    required Map<String, dynamic> filter,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: id,
            name: 'smart:$filterName',
            folderLocalId: const Value(null),
            folderId: const Value(null),
            sortOrder: const Value(0),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final row = await (_db.select(
      _db.todoLists,
    )..where((t) => t.id.equals(id))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.upsert,
      localId: id,
      payload: {...row.toJson(), 'isSmart': true, 'filter': filter},
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

  final String? listId;
  final int? folderId;
  final List<String> tagIds;
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
      listId: json['listId'] as String?,
      folderId: json['folderId'] as int?,
      tagIds: (json['tagIds'] as List?)?.cast<String>() ?? const [],
      priority: json['priority'] as int?,
      dueRange: json['dueRange'] as String?,
      completed: json['completed'] as bool?,
    );
  }

  factory SmartListFilter.fromListName(String listName) {
    if (!listName.startsWith('smart:')) return SmartListFilter();
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
