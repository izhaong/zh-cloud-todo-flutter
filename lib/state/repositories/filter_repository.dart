import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 服务端 `todo_filter.conditions` 的形状见
/// `TodoFilterConditionsDO`：listIds / tagIds / dateRange / priorities / statuses / keyword。
class TodoFilterConditions {
  const TodoFilterConditions({
    this.listIds = const [],
    this.tagIds = const [],
    this.priorities = const [],
    this.statuses = const [],
    this.keyword,
    this.dateRange,
  });

  final List<String> listIds;
  final List<String> tagIds;
  final List<int> priorities;
  final List<String> statuses;
  final String? keyword;
  final TodoFilterDateRange? dateRange;

  Map<String, dynamic> toJson() => {
    if (listIds.isNotEmpty) 'listIds': listIds,
    if (tagIds.isNotEmpty) 'tagIds': tagIds,
    if (priorities.isNotEmpty) 'priorities': priorities,
    if (statuses.isNotEmpty) 'statuses': statuses,
    if (keyword?.trim().isNotEmpty == true) 'keyword': keyword!.trim(),
    if (dateRange != null) 'dateRange': dateRange!.toJson(),
  };

  /// 容忍服务端下发的多余键与单值/多值差异；无法表示的键留到 `unsupportedKeys`。
  static ({TodoFilterConditions conditions, Set<String> unsupportedKeys})
  fromJson(Map<String, dynamic> json) {
    final unsupported = <String>{};
    final known = {
      'listIds',
      'tagIds',
      'priorities',
      'statuses',
      'keyword',
      'dateRange',
    };
    unsupported.addAll(json.keys.where((key) => !known.contains(key)));
    final rawRange = json['dateRange'];
    return (
      conditions: TodoFilterConditions(
        listIds: _strings(json['listIds']),
        tagIds: _strings(json['tagIds']),
        priorities: _ints(json['priorities']),
        statuses: _strings(json['statuses']),
        keyword: json['keyword']?.toString(),
        dateRange: rawRange is Map
            ? TodoFilterDateRange(
                preset: rawRange['preset']?.toString(),
                from: DateTime.tryParse(rawRange['from']?.toString() ?? ''),
                to: DateTime.tryParse(rawRange['to']?.toString() ?? ''),
              )
            : null,
      ),
      unsupportedKeys: unsupported,
    );
  }

  static List<String> _strings(Object? raw) => raw is List
      ? raw.map((item) => '$item').toList(growable: false)
      : const [];

  static List<int> _ints(Object? raw) => raw is List
      ? raw
            .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
            .whereType<int>()
            .toList(growable: false)
      : const [];
}

/// 到期日范围：`preset` 与 `from`/`to` 可并存（与服务端 DateRange 字段一致）。
class TodoFilterDateRange {
  const TodoFilterDateRange({this.preset, this.from, this.to});

  final String? preset;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => preset == null && from == null && to == null;

  Map<String, dynamic> toJson() => {
    if (preset != null) 'preset': preset,
    if (from != null) 'from': from!.toIso8601String(),
    if (to != null) 'to': to!.toIso8601String(),
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

  Stream<List<TodoFilter>> watchAll() {
    return (_db.select(_db.todoFilters)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
        .watch();
  }

  Future<void> remove(String id) async {
    final row = await (_db.select(
      _db.todoFilters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.todoFilters)..where((t) => t.id.equals(id))).go();
      await _queue.enqueue(
        entity: SyncEntities.filter,
        op: SyncOps.delete,
        localId: id,
        serverId: row.serverId,
        payload: {'id': id, 'serverId': row.serverId},
      );
    });
  }
}
