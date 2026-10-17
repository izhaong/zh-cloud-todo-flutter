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
    this.showHeatmap,
    this.timelineColorBy,
    this.calendarColorBy,
    this.quadrantTaskSort = const {},
    this.quadrantOrder = const ['q1', 'q2', 'q3', 'q4'],
  });

  final String? viewType;
  final double timelineZoom;
  final String timelineScale;
  final Set<String> collapsedTimelineGroupIds;
  final bool? showCompletedTasks;

  /// 年视图热力图（嘀嗒《03-年视图》:76「默认情况下，热力图为关闭状态」）。
  /// `null` 表示这条偏好从没写过，读取侧按「关闭」处理。
  final bool? showHeatmap;

  /// 时间线任务条着色轴（嘀嗒《03-时间线视图》:95「在『显示设置』中根据
  /// 清单、标签以及优先级的颜色显示」；specs/121，矩阵 #16 面 ⑦）。
  /// `priority` | `list` | `tag`；null 读侧按「按优先级」处理（现状锁）。
  final String? timelineColorBy;

  /// 日历任务块着色轴（嘀嗒《08-常见问题》:58；specs/124，矩阵 #31）。
  /// 同 timelineColorBy 的三档；null 读侧按「按优先级」处理。
  final String? calendarColorBy;

  /// 四象限每象限的任务排序档（嘀嗒《02-如何编辑四象限规则.md》:135-:136
  /// 「如何调整四象限的任务顺序？…『排序』，可选择排序方式」；specs/127，
  /// 矩阵 #36 面 ⑪）。key 是象限名（q1..q4），value 是 `TaskSort.name`；
  /// 缺档读侧保持分桶输入顺序（现状锁）。
  final Map<String, String> quadrantTaskSort;

  /// 四象限的显示顺序（嘀嗒同页 :64-:75「如何调整四象限顺序」；specs/128，
  /// 矩阵 #36 面 ⑦）。q1..q4 的一个排列，缺省就是 Q1/Q2/Q3/Q4（现状锁）；
  /// 非法排列（缺元素/重复）读侧回退默认。
  final List<String> quadrantOrder;
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

  /// 四象限单象限的排序档（specs/127，矩阵 #36 面 ⑪）：patch 合并语义
  /// 保留其它象限已存的档；档名不在 `TaskSort` 白名单的写入被拒。
  Future<void> saveQuadrantTaskSort({
    required String sourceKey,
    required String quadrant,
    required String sort,
    required Map<String, String> current,
  }) {
    if (!const {
      'smart',
      'priorityDesc',
      'dueDate',
      'title',
      'createdAt',
      'updatedAt',
      'tag',
    }.contains(sort)) {
      throw ArgumentError.value(sort, 'sort', '未知排序档');
    }
    if (!const {'q1', 'q2', 'q3', 'q4'}.contains(quadrant)) {
      throw ArgumentError.value(quadrant, 'quadrant', '象限名必须是 q1..q4');
    }
    return _saveViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
      preferencePatch: {
        'quadrantTaskSort': {...current, quadrant: sort},
      },
    );
  }

  /// 四象限显示顺序（specs/128，矩阵 #36 面 ⑦）：patch 整键覆盖；
  /// 非法排列（非 q1..q4 的四元排列）在写入前就被拒。
  Future<void> saveQuadrantOrder({
    required String sourceKey,
    required List<String> order,
  }) {
    final normalized = order.toList();
    const valid = {'q1', 'q2', 'q3', 'q4'};
    if (normalized.length != 4 ||
        normalized.toSet().length != 4 ||
        normalized.any((q) => !valid.contains(q))) {
      throw ArgumentError.value(order, 'order', '必须是 q1..q4 的一个排列');
    }
    return _saveViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
      preferencePatch: {'quadrantOrder': normalized},
    );
  }

  /// 时间线「显示设置」只写着色轴：patch 合并语义保留 zoom/scale/折叠组
  /// （specs/121）。轴只认三档，别处传错就退回优先级，不抛错。
  Future<void> saveTimelineColorBy({
    required String sourceKey,
    required String colorBy,
  }) {
    final normalized = const {'priority', 'list', 'tag'}.contains(colorBy)
        ? colorBy
        : 'priority';
    return _saveViewPreference(
      sourceType: 'task_view',
      sourceKey: sourceKey,
      preferencePatch: {'timelineColorBy': normalized},
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
    required bool showHeatmap,
    String colorBy = 'priority',
  }) {
    return _saveViewPreference(
      sourceType: 'calendar_view',
      sourceKey: 'task_calendar',
      viewType: viewMode,
      preferencePatch: {
        'showCompletedTasks': showCompletedTasks,
        'showHeatmap': showHeatmap,
        // 嘀嗒《08-常见问题》:58「颜色-显示方式：按清单、优先级或标签显示」
        // （specs/124）；非法档归一化成 priority。
        'calendarColorBy': const {'priority', 'list', 'tag'}.contains(colorBy)
            ? colorBy
            : 'priority',
      },
    );
  }

  /// 四象限的完成态显隐读取（嘀嗒《02-功能指南/03-四象限/02-如何编辑四象限规则.md》
  /// `:132`「在四象限页面，点击右上角「...」- 隐藏已完成。」）。
  ///
  /// 没有这条偏好行时 `showCompletedTasks` 是 null ⇒ 由视图按"隐藏"处理，与嘀嗒默认一致。
  Future<TaskWorkspacePreference> getQuadrantDisplay() {
    return _getTaskWorkspacePreference(
      sourceType: 'quadrant_view',
      sourceKey: 'task_quadrant',
    );
  }

  /// 四象限这一面只有开关、没有并行的视图模式，所以不交 `viewType`
  /// （`calendar_view` 那侧必须同行交，是因为它有个模式要一起落）。
  Future<void> saveQuadrantDisplay({required bool showCompletedTasks}) {
    return _saveViewPreference(
      sourceType: 'quadrant_view',
      sourceKey: 'task_quadrant',
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
      showHeatmap: value['showHeatmap'] is bool
          ? value['showHeatmap'] as bool
          : null,
      timelineColorBy: value['timelineColorBy'] is String
          ? value['timelineColorBy'] as String
          : null,
      calendarColorBy: value['calendarColorBy'] is String
          ? value['calendarColorBy'] as String
          : null,
      quadrantTaskSort: value['quadrantTaskSort'] is Map
          ? (value['quadrantTaskSort'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : const {},
      quadrantOrder: value['quadrantOrder'] is List
          ? (value['quadrantOrder'] as List)
                .map((v) => v.toString())
                .where(const {'q1', 'q2', 'q3', 'q4'}.contains)
                .toList()
          : const ['q1', 'q2', 'q3', 'q4'],
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
      // FL #584：与 `scheduleTaskToDay` 同一口径 —— 时段跟着这一天一起挪。
      final task0 = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      final toDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
      final rangeDisplay = task0.startAt == null
          ? null
          : taskWallClockDateTime(
              task0.startAt!,
              allDay: task0.allDay,
              mode: TaskTimeMode.fromWire(task0.timeMode),
              timeZone: task0.timeZone,
            );
      final shifted = rangeDisplay == null
          ? null
          : _shiftedRange(task0, rangeDisplay, toDay);
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(dueAt),
          startAt: shifted == null
              ? const Value.absent()
              : Value(shifted.startAt),
          endAt: shifted == null ? const Value.absent() : Value(shifted.endAt),
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

  /// 将推荐任务安排到客户端本地“今天”（推荐任务的「+」按钮）。
  Future<void> addToToday(String taskId, {DateTime? today}) {
    return scheduleTaskToDay(taskId, targetDay: today ?? DateTime.now());
  }

  /// 把任务的截止日挪到 [targetDay]（时刻/全天语义都不变）。
  ///
  /// 已有截止时间保留其展示墙钟时刻；无日期任务使用纯日期全天语义。
  /// 已经属于那一天时不重复写入，也不产生第二条 outbox mutation。
  ///
  /// 「今天」与侧栏智能清单落点（嘀嗒《…07-任务与日历同时显示.md》`:63`「为任务自动添加
  /// 该智能清单关联的时间条件」）走的是同一条写入路径，所以这里只认一个目标日，
  /// 「哪一天」由调用方（`SmartListTimeCondition`）决定。

  /// 把 [fromDay] → [toDay] 的**整天差**，按墙钟加到 [value] 上。
  ///
  /// 用"年月日重新构造"而不是 `add(Duration(days: n))`：跨夏令时那天
  /// `Duration` 会把钟点挪掉一小时，而用户要的是**同一个钟点、换一天**（FL #584）。
  DateTime _shiftWallClockByDays(DateTime value, int days) {
    // ⚠️ 必须保住**这个 DateTime 自己的 UTC 属性**：库里 `startAt/endAt` 存的是 UTC，
    // 用 `DateTime(...)` 重建会把它变成**本地**的同一钟点 ⇒ 瞬间被平移一个时区偏移。
    // （第一版就是这么写的，判据当场抓到：时段落在 2027-02-28 而截止日在 2026-10-20。）
    final shifted = DateTime.utc(
      value.year,
      value.month,
      value.day + days,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return value.isUtc
        ? shifted
        : DateTime(
            value.year,
            value.month,
            value.day + days,
            value.hour,
            value.minute,
            value.second,
            value.millisecond,
            value.microsecond,
          );
  }

  /// 两个展示日之间差几天（按**日历日**算，不用时刻相减）。
  int _calendarDayDelta(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// 「挪到某一天」时，**有时段的任务要把起止一起挪过去**（FL #584）。
  ///
  /// 只挪 `dueAt` 会让两处各说各话：按 `dueAt` 过滤的清单（今天/明天/最近七天）
  /// 说它在今天，按 `startAt` 分桶的时间线/日历把它画在**原日**。
  ///
  /// 半天平移（用截至日展示墙钟的日历日差）：**时段长度与钟点都不变**。
  /// 任务没有时段（`startAt == null`）时返回 `null` —— 那种任务本来就只有一个日子。
  ({DateTime startAt, DateTime endAt})? _shiftedRange(
    TodoTask task,
    DateTime rangeDisplayDay,
    DateTime toDisplayDay,
  ) {
    final startAt = task.startAt;
    final endAt = task.endAt;
    if (startAt == null || endAt == null) return null;
    // 参照物是**时段自己的展示日**，不是截止日：
    // 「时段与截止日本来就不在同一天」的记录（测试种子里就有）用截止日的差值会把它挪到第三个日子上去。
    // 这条判据第一版就是这么写的，判据当场抓到（时段落到 2027-02-28，而截止日在 2026-10-20）。
    final delta = _calendarDayDelta(rangeDisplayDay, toDisplayDay);
    if (delta == 0) return null;
    return (
      startAt: _shiftWallClockByDays(startAt, delta),
      endAt: _shiftWallClockByDays(endAt, delta),
    );
  }

  Future<void> scheduleTaskToDay(
    String taskId, {
    required DateTime targetDay,
  }) async {
    final day = DateTime(targetDay.year, targetDay.month, targetDay.day);
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
          currentDisplay.year == day.year &&
          currentDisplay.month == day.month &&
          currentDisplay.day == day.day) {
        return;
      }
      final dueAt = task.dueAt == null
          ? day
          : task.allDay
          ? day
          : taskDateTimeForDisplayDay(
              task.dueAt!,
              day,
              mode: TaskTimeMode.fromWire(task.timeMode),
              timeZone: task.timeZone,
            );
      // FL #584：有时段的任务，起止**一起挪到同一天**（否则清单与日历各说各话）。
      final rangeDisplay = task.startAt == null
          ? null
          : taskWallClockDateTime(
              task.startAt!,
              allDay: task.allDay,
              mode: TaskTimeMode.fromWire(task.timeMode),
              timeZone: task.timeZone,
            );
      final shifted = rangeDisplay == null
          ? null
          : _shiftedRange(task, rangeDisplay, day);
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(dueAt),
          allDay: Value(task.dueAt == null ? true : task.allDay),
          startAt: shifted == null
              ? const Value.absent()
              : Value(shifted.startAt),
          endAt: shifted == null ? const Value.absent() : Value(shifted.endAt),
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

  /// 看板跨列写入「清单分组」：只改 `sectionId`，不动 priority / completed。
  /// 嘀嗒看板的列是清单内的分组（《02-看板视图：分类管理任务.md》`:99`-`:101`
  /// 「- 按主题：英语、政治、专业课…」），与 [moveKanbanTask] 的 priority 列是两种分组方式。
  Future<void> moveKanbanTaskToSection(
    String taskId, {
    required String? sectionId,
  }) async {
    await _db.transaction(() async {
      await _requireWritableTask(taskId);
      if (sectionId != null) {
        final task = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).getSingle();
        final section = await (_db.select(
          _db.todoTaskSections,
        )..where((row) => row.id.equals(sectionId))).getSingleOrNull();
        if (section == null || section.listId != task.listId) {
          throw ArgumentError.value(sectionId, 'sectionId', '分组必须属于任务所在清单');
        }
      }
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          sectionId: Value(sectionId),
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
