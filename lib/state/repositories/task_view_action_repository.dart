import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import '../../core/time/task_time_formatter.dart';
import '../../core/time/task_time_mode.dart';

class TaskWorkspacePreference {
  const TaskWorkspacePreference({
    this.viewType,
    this.timelineZoom = 1,
    this.timelineScale = 'week',
    this.collapsedTimelineGroupIds = const {},
    this.showCompletedTasks,
  });

  final String? viewType;
  final double timelineZoom;
  final String timelineScale;
  final Set<String> collapsedTimelineGroupIds;
  final bool? showCompletedTasks;
}

/// B4 任务视图共享写操作。
///
/// 列表、看板和时间线只能经此类（或后续同类 use-case）写入任务聚合，
/// 以便本地任务更新与 outbox mutation 使用同一个 Drift transaction。
class TaskViewActionRepository {
  TaskViewActionRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _legacyTaskWorkspaceSourceKey = 'tasks_by_list';
  static const _syntheticInboxListId = 'inbox';

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
        scoped.timelineScale != 'week' ||
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
    String scale = 'week',
    required Set<String> collapsedGroupIds,
  }) {
    if (zoom < 0.75 || zoom > 1.5) {
      throw ArgumentError.value(zoom, 'zoom', '必须介于 0.75 和 1.5');
    }
    if (!const {'day', 'week', 'month'}.contains(scale)) {
      throw ArgumentError.value(scale, 'scale', '必须为 day、week 或 month');
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
        'timelineScale': scale,
        'collapsedTimelineGroupIds': normalizedGroupIds,
      },
    );
  }

  /// 日历显示设置（视图模式 + 是否显示已完成）整组读取。
  Future<TaskWorkspacePreference> getCalendarDisplay() {
    return _getTaskWorkspacePreference(
      sourceType: 'calendar_view',
      sourceKey: 'task_calendar',
    );
  }

  /// 模式与开关必须一起写：`_saveViewPreference` 在 `viewType` 缺失时会把
  /// `viewType` 兜底成 `list`，只写开关会静默把用户的视图模式改掉。
  Future<void> saveCalendarDisplay({
    required String viewMode,
    required bool showCompletedTasks,
  }) {
    return _saveViewPreference(
      sourceType: 'calendar_view',
      sourceKey: 'task_calendar',
      viewType: viewMode,
      preferencePatch: {'showCompletedTasks': showCompletedTasks},
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
    final scaleValue = value['timelineScale']?.toString();
    final scale = const {'day', 'week', 'month'}.contains(scaleValue)
        ? scaleValue!
        : 'week';
    final collapsed = (value['collapsedTimelineGroupIds'] as List? ?? const [])
        .map((groupId) => groupId.toString())
        .where((groupId) => groupId.isNotEmpty)
        .toSet();
    return TaskWorkspacePreference(
      viewType: viewType != null && viewType.trim().isNotEmpty
          ? viewType
          : null,
      timelineZoom: zoom >= 0.75 && zoom <= 1.5 ? zoom : 1,
      timelineScale: scale,
      collapsedTimelineGroupIds: collapsed,
      showCompletedTasks: value['showCompletedTasks'] is bool
          ? value['showCompletedTasks'] as bool
          : null,
    );
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

  Future<void> scheduleTimelineTask(
    String taskId, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
    required bool allDay,
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
          allDay: Value(allDay),
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

  Future<void> moveCalendarTask(
    String taskId, {
    required DateTime dueAt,
  }) async {
    await _db.transaction(() async {
      await _requireWritableTask(taskId);
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
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

  /// 将推荐任务安排到客户端本地“今天”。
  ///
  /// 已有截止时间保留其展示墙钟时刻；无日期任务使用纯日期全天语义。
  /// 已经属于今天时不重复写入，也不产生第二条 outbox mutation。
  Future<void> addToToday(String taskId, {DateTime? today}) async {
    final target = today ?? DateTime.now();
    final targetDay = DateTime(target.year, target.month, target.day);
    await _db.transaction(() async {
      final task = await _requireWritableTask(taskId);
      final currentDisplay = task.dueAt == null
          ? null
          : taskWallClockDateTime(
              task.dueAt!,
              allDay: task.allDay,
              mode: TaskTimeMode.fromWire(task.timeMode),
              timeZone: task.timeZone,
            );
      if (currentDisplay != null &&
          currentDisplay.year == targetDay.year &&
          currentDisplay.month == targetDay.month &&
          currentDisplay.day == targetDay.day) {
        return;
      }
      final dueAt = task.dueAt == null
          ? targetDay
          : task.allDay
          ? targetDay
          : taskDateTimeForDisplayDay(
              task.dueAt!,
              targetDay,
              mode: TaskTimeMode.fromWire(task.timeMode),
              timeZone: task.timeZone,
            );
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(dueAt),
          allDay: Value(task.dueAt == null ? true : task.allDay),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final updated = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: updated.id,
        serverId: updated.serverId,
        payload: updated.toJson(),
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

  /// 四象限拖动换象限的回写（嘀嗒《02-如何编辑四象限规则》:25/:44）。
  ///
  /// `dueAt == null` 表示「这一档不改时间」——组合1 只回写优先级，
  /// 不是把截止时间清空，所以不能用 `Value(null)` 走同一条路。
  Future<void> moveQuadrantTask(
    String taskId, {
    required int priority,
    DateTime? dueAt,
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
          dueAt: dueAt == null ? const Value.absent() : Value(dueAt),
          allDay: dueAt == null ? const Value.absent() : const Value(false),
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
    if (list == null && listId == _syntheticInboxListId) return;
    if (list == null) {
      throw StateError('清单不存在');
    }
    if (!list.writable) {
      throw StateError('当前清单为只读，无法修改任务');
    }
  }
}
