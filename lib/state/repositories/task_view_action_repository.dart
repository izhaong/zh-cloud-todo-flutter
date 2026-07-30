import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

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
    final scoped = await _getViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
    );
    if (scoped != null || sourceKey != 'list:inbox') return scoped;
    return _getViewPreference(
      sourceType: 'task_view',
      sourceKey: _legacyTaskWorkspaceSourceKey,
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
    required String viewType,
  }) async {
    if (sourceKey.trim().isEmpty) {
      throw ArgumentError.value(sourceKey, 'sourceKey', '来源不能为空');
    }
    if (viewType.trim().isEmpty) {
      throw ArgumentError.value(viewType, 'viewType', '视图类型不能为空');
    }
    final payload = <String, dynamic>{
      'sourceType': sourceType,
      'sourceKey': sourceKey,
      'viewType': viewType,
    };

    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (row) =>
                    row.sourceType.equals(sourceType) &
                    row.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
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

  Future<String?> _getViewPreference({
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
    if (preference == null) return null;
    try {
      final value = jsonDecode(preference.valueJson);
      if (value is! Map<String, dynamic>) return null;
      final viewType = value['viewType'];
      return viewType is String && viewType.trim().isNotEmpty ? viewType : null;
    } on FormatException {
      return null;
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

    await _db.transaction(() async {
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
}
