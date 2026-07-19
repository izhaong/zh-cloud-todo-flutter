import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

class TodoFilterConditions {
  const TodoFilterConditions({
    this.listIds = const [],
    this.tagIds = const [],
    this.priorities = const [],
    this.statuses = const [],
    this.keyword,
  });

  final List<String> listIds;
  final List<String> tagIds;
  final List<int> priorities;
  final List<String> statuses;
  final String? keyword;

  Map<String, dynamic> toJson() => {
    if (listIds.isNotEmpty) 'listIds': listIds,
    if (tagIds.isNotEmpty) 'tagIds': tagIds,
    if (priorities.isNotEmpty) 'priorities': priorities,
    if (statuses.isNotEmpty) 'statuses': statuses,
    if (keyword?.trim().isNotEmpty == true) 'keyword': keyword!.trim(),
  };
}

class TodoFilterSortOrder {
  const TodoFilterSortOrder({required this.field, required this.direction});

  final String field;
  final String direction;

  Map<String, String> toJson() => {'field': field, 'direction': direction};
}

/// 已保存过滤器只经 Drift + outbox 写入；远端 apply 属于同步后的只读验收边界。
class FilterRepository {
  FilterRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TodoFilter> save({
    required String name,
    required TodoFilterConditions conditions,
    List<TodoFilterSortOrder> sortOrders = const [],
    bool isSmart = false,
    bool isPinned = false,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '过滤器名称不能为空');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    final conditionJson = jsonEncode(conditions.toJson());
    final sortOrdersJson = jsonEncode(
      sortOrders.map((item) => item.toJson()).toList(),
    );
    await _db.transaction(() async {
      await _db
          .into(_db.todoFilters)
          .insert(
            TodoFiltersCompanion.insert(
              id: id,
              name: normalizedName,
              conditionJson: conditionJson,
              sortOrdersJson: Value(sortOrdersJson),
              isSmart: Value(isSmart),
              isPinned: Value(isPinned),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await _queue.enqueue(
        entity: SyncEntities.filter,
        op: SyncOps.upsert,
        localId: id,
        payload: {
          'name': normalizedName,
          'conditionsJson': conditionJson,
          'sortOrdersJson': sortOrdersJson,
          'isSmart': isSmart,
          'isPinned': isPinned,
        },
      );
    });
    return (_db.select(
      _db.todoFilters,
    )..where((row) => row.id.equals(id))).getSingle();
  }
}
