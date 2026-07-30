import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

class TaskWorkspacePreference {
  const TaskWorkspacePreference({
    this.viewType,
    this.timelineZoom = 1,
    this.collapsedTimelineGroupIds = const {},
  });

  final String? viewType;
  final double timelineZoom;
  final Set<String> collapsedTimelineGroupIds;
}

/// B4 任务视图共享写操作。
///
/// 列表、看板和时间线只能经此类（或后续同类 use-case）写入任务聚合，
/// 以便本地任务更新与 outbox mutation 使用同一个 Drift transaction。
class TaskViewActionRepository {
  TaskViewActionRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _legacyTaskWorkspaceSourceKey = 'tasks_by_list';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  /// 保存任务工作区的视图模式。
  ///
  /// 视图切换同样属于离线优先写链路：先以 source type/key 落入 Drift，
  /// 再引用同一条本地记录入队，不能由 Widget 直接拼 outbox payload。
  Future<void> saveTaskWorkspaceViewMode({
    required String sourceKey,
    required String viewType,
  }) async {
    return _saveViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
      viewType: viewType,
    );
  }

  Future<String?> getTaskWorkspaceViewMode({required String sourceKey}) async {
    final scoped = await _getTaskWorkspacePreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
    );
    if (scoped.viewType != null || sourceKey != 'list:inbox') {
      return scoped.viewType;
    }
    return (await _getTaskWorkspacePreference(
      sourceType: 'task_view',
      sourceKey: _legacyTaskWorkspaceSourceKey,
    )).viewType;
  }

  Future<TaskWorkspacePreference> getTaskWorkspacePreference({
    required String sourceKey,
  }) async {
    final scoped = await _getTaskWorkspacePreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
    );
    if (scoped.viewType != null ||
        scoped.timelineZoom != 1 ||
        scoped.collapsedTimelineGroupIds.isNotEmpty ||
        sourceKey != 'list:inbox') {
      return scoped;
    }
    return _getTaskWorkspacePreference(
      sourceType: 'task_view',
      sourceKey: _legacyTaskWorkspaceSourceKey,
    );
  }

  Future<void> saveTaskTimelinePreference({
    required String sourceKey,
    required double zoom,
    required Set<String> collapsedGroupIds,
  }) {
    if (zoom < 0.75 || zoom > 1.5) {
      throw ArgumentError.value(zoom, 'zoom', '必须介于 0.75 和 1.5');
    }
    final normalizedGroupIds =
        collapsedGroupIds
            .map((groupId) => groupId.trim())
            .where((groupId) => groupId.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _saveViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
      preferencePatch: {
        'timelineZoom': zoom,
        'collapsedTimelineGroupIds': normalizedGroupIds,
      },
    );
  }

  Future<void> saveCalendarViewMode(String viewType) async {
    return _saveViewPreference(
      sourceType: 'calendar_view',
      sourceKey: 'task_calendar',
      viewType: viewType,
    );
  }

  Future<String?> getCalendarViewMode() {
    return _getViewPreference(
      sourceType: 'calendar_view',
      sourceKey: 'task_calendar',
    );
  }

  Future<void> _saveViewPreference({
    required String sourceType,
    required String sourceKey,
    String? viewType,
    Map<String, dynamic> preferencePatch = const {},
  }) async {
    if (sourceKey.trim().isEmpty) {
      throw ArgumentError.value(sourceKey, 'sourceKey', '来源不能为空');
    }
    if (viewType != null && viewType.trim().isEmpty) {
      throw ArgumentError.value(viewType, 'viewType', '视图类型不能为空');
    }

    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (row) =>
                    row.sourceType.equals(sourceType) &
                    row.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
      final preferenceValue = _decodePreferenceValue(existing?.valueJson);
      preferenceValue.addAll(preferencePatch);
      if (viewType != null) preferenceValue['viewType'] = viewType;
      final effectiveViewType =
          preferenceValue['viewType']?.toString().trim().isNotEmpty == true
          ? preferenceValue['viewType'].toString()
          : 'list';
      final payload = <String, dynamic>{
        'sourceType': sourceType,
        'sourceKey': sourceKey,
        'viewType': effectiveViewType,
        'valueJson': jsonEncode(preferenceValue),
      };
      final now = DateTime.now();
      final companion = TodoViewPreferencesCompanion(
        id: Value(existing?.id ?? _uuid.v4()),
        serverId: Value(existing?.serverId),
        sourceType: Value(sourceType),
        sourceKey: Value(sourceKey),
        valueJson: Value(jsonEncode(payload)),
        updatedAt: Value(now),
        createdAt: Value(existing?.createdAt ?? now),
      );
      if (existing == null) {
        await _db.into(_db.todoViewPreferences).insert(companion);
      } else {
        await (_db.update(
          _db.todoViewPreferences,
        )..where((row) => row.id.equals(existing.id))).write(companion);
      }
      final saved =
          await (_db.select(_db.todoViewPreferences)..where(
                (row) =>
                    row.sourceType.equals(sourceType) &
                    row.sourceKey.equals(sourceKey),
              ))
              .getSingle();
      await _queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: saved.id,
        serverId: saved.serverId,
        payload: payload,
      );
    });
  }

  Future<TaskWorkspacePreference> _getTaskWorkspacePreference({
    required String sourceType,
    required String sourceKey,
  }) async {
    final preference =
        await (_db.select(_db.todoViewPreferences)..where(
              (row) =>
                  row.sourceType.equals(sourceType) &
                  row.sourceKey.equals(sourceKey),
            ))
            .getSingleOrNull();
    if (preference == null) return const TaskWorkspacePreference();
    final value = _decodePreferenceValue(preference.valueJson);
    final viewType = value['viewType']?.toString();
    final zoomValue = value['timelineZoom'];
    final zoom = zoomValue is num ? zoomValue.toDouble() : 1.0;
    final collapsed = (value['collapsedTimelineGroupIds'] as List? ?? const [])
        .map((groupId) => groupId.toString())
        .where((groupId) => groupId.isNotEmpty)
        .toSet();
    return TaskWorkspacePreference(
      viewType: viewType != null && viewType.trim().isNotEmpty
          ? viewType
          : null,
      timelineZoom: zoom >= 0.75 && zoom <= 1.5 ? zoom : 1,
      collapsedTimelineGroupIds: collapsed,
    );
  }

  Future<String?> _getViewPreference({
    required String sourceType,
    required String sourceKey,
  }) async {
    return (await _getTaskWorkspacePreference(
      sourceType: sourceType,
      sourceKey: sourceKey,
    )).viewType;
  }

  Map<String, dynamic> _decodePreferenceValue(String? rawValue) {
    if (rawValue == null) return {};
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) return {};
      final result = Map<String, dynamic>.from(decoded)
        ..remove('sourceType')
        ..remove('sourceKey')
        ..remove('source_type')
        ..remove('source_key');
      final nestedRaw =
          result.remove('valueJson') ?? result.remove('value_json');
      if (nestedRaw is String) {
        final nested = jsonDecode(nestedRaw);
        if (nested is Map<String, dynamic>) result.addAll(nested);
      } else if (nestedRaw is Map) {
        result.addAll(nestedRaw.cast<String, dynamic>());
      }
      return result;
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> moveTimelineTask(
    String taskId, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  }) async {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', '必须晚于开始时间');
    }

    await _db.transaction(() async {
      await _requireWritableTask(taskId);
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          startAt: Value(startAt),
          endAt: Value(endAt),
          dueAt: Value(dueAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final task = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: task.id,
        serverId: task.serverId,
        payload: task.toJson(),
      );
    });
  }

  Future<void> moveKanbanTask(
    String taskId, {
    required int priority,
    required bool completed,
  }) async {
    if (priority < 0 || priority > 3) {
      throw ArgumentError.value(priority, 'priority', '必须介于 0 和 3');
    }

    await _db.transaction(() async {
      await _requireWritableTask(taskId);
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          priority: Value(priority),
          completed: Value(completed),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final task = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: task.id,
        serverId: task.serverId,
        payload: task.toJson(),
      );
    });
  }

  Future<void> reorderListTasks(List<String> taskIds) async {
    if (taskIds.toSet().length != taskIds.length) {
      throw ArgumentError.value(taskIds, 'taskIds', '不能包含重复任务');
    }
    if (taskIds.isEmpty) return;

    await _db.transaction(() async {
      final tasks = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.isIn(taskIds))).get();
      if (tasks.length != taskIds.length) {
        throw StateError('任务不存在');
      }
      final listIds = tasks.map((task) => task.listId).toSet();
      if (listIds.length != 1) {
        throw ArgumentError.value(taskIds, 'taskIds', '必须属于同一清单');
      }
      await _requireWritableList(listIds.single);

      for (final entry in taskIds.indexed) {
        final taskId = entry.$2;
        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).write(
          TodoTasksCompanion(
            sortOrder: Value(entry.$1),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final task = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).getSingle();
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: task.id,
          serverId: task.serverId,
          payload: task.toJson(),
        );
      }
    });
  }

  Future<TodoTask> _requireWritableTask(String taskId) async {
    final task = await (_db.select(
      _db.todoTasks,
    )..where((row) => row.id.equals(taskId))).getSingleOrNull();
    if (task == null) {
      throw StateError('任务不存在');
    }
    await _requireWritableList(task.listId);
    return task;
  }

  Future<void> _requireWritableList(String listId) async {
    final list = await (_db.select(
      _db.todoLists,
    )..where((row) => row.id.equals(listId))).getSingleOrNull();
    if (list == null) {
      throw StateError('清单不存在');
    }
    if (!list.writable) {
      throw StateError('当前清单为只读，无法修改任务');
    }
  }
}
