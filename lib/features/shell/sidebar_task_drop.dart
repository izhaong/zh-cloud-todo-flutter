import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/time/task_time_formatter.dart';
import '../../core/time/task_time_mode.dart';
import '../../state/providers.dart';
import 'smart_list_time_condition.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》:57「拖动到清单或标签上」
/// `:59`「任务会被移动到目标清单，或自动打上相应标签。」
/// 与 `:61`「拖动到智能清单上」`:63`「会为任务自动添加该智能清单关联的时间条件，
/// 例如“今天”、“本周”等。」
///
/// 落点是侧栏的清单行、标签行与「带时间条件」的智能清单行；拖出源沿用既有的
/// `Draggable<TodoTask>`
/// （看板、时间线、并列视图的清单行），所以这一面在双栏并列时才看得见，
/// 但落点本身不挑视图 —— 嘀嗒那句原文也没有把落点限定在并列视图内。
class SidebarDropZone extends StatefulWidget {
  const SidebarDropZone({
    required this.hoverLabel,
    required this.accept,
    required this.onDrop,
    required this.child,
    super.key,
  });

  /// 候选态（指针停在落点上）才给读屏文案：静止的侧栏不该被几百行噪声占满。
  final String hoverLabel;
  final bool Function(TodoTask task) accept;
  final Future<void> Function(TodoTask task) onDrop;
  final Widget child;

  @override
  State<SidebarDropZone> createState() => _SidebarDropZoneState();
}

class _SidebarDropZoneState extends State<SidebarDropZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TodoTask>(
      onWillAcceptWithDetails: (details) {
        final accepted = widget.accept(details.data);
        if (accepted != _hovered) setState(() => _hovered = accepted);
        return accepted;
      },
      onLeave: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      onAcceptWithDetails: (details) {
        unawaited(widget.onDrop(details.data));
      },
      builder: (context, candidates, rejected) {
        if (candidates.isEmpty) return widget.child;
        return Semantics(
          label: widget.hoverLabel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(6),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// 落点结果：只有 [SidebarDropOutcome.failed] 需要告诉用户，
/// 另两支是「本来就不该动」，弹提示反而是打扰。
enum SidebarDropOutcome { applied, skipped, failed }

/// 侧栏落点的写库编排。同一任务的两次落点串行：后一刀必须等前一刀落完，
/// 否则「先移到 A、再移到 B」会被 Drift 的并发顺序反过来。
///
/// 仓储通过函数接缝注入（不是 `TaskRepository` 本身）：这样「不发写请求」「串行」
/// 「失败后链条不断」三件事能在不伪造整个仓储的前提下被测到。
class SidebarTaskDropController {
  SidebarTaskDropController({
    required this.loadTask,
    required this.moveTask,
    required this.attachTag,
    required this.scheduleToDay,
  });

  /// 按 id 重读**库里的当前行**（FL #585）。返回 null = 这一行已经没了
  /// （被删 / 被 pull 掉了）⇒ 调用方退回拖出快照，让下游仓储去决定怎么写。
  ///
  /// 为什么必须重读：落点判断原来吃的是 `Draggable<TodoTask>` 的 data，
  /// 也就是**拖出那一刻**的快照；而拖出到落下之间可能有一次 pull 覆盖本地行。
  /// 快照与库分叉时，落点按旧数据判「已满足」而 skip —— 那一次拖动被**静默吞掉**：
  /// 没有写入、没有提示、任务还在原地（复现见 specs/149）。
  final Future<TodoTask?> Function(String taskId) loadTask;

  /// 换清单；实现侧负责清掉属于原清单的 `sectionId`。
  final Future<void> Function(String taskId, String listId) moveTask;

  /// 「自动打上相应标签」= 追加；实现侧负责去重（已有就不写）。
  final Future<void> Function(String taskId, String tagId) attachTag;

  /// 智能清单落点：把截止日挪到该清单时间条件窗口的首日。
  final Future<void> Function(String taskId, DateTime targetDay) scheduleToDay;

  final Map<String, Future<void>> _chain = <String, Future<void>>{};

  /// 清单行只在「真的换清单」时才是有效落点：落回原清单不该发写请求。
  bool acceptsList(TodoTask task, String listId) => task.listId != listId;

  /// 智能清单行同理：任务的截止日已经落在这一档的窗口里 ⇒ 条件已满足，不是落点
  /// （与 [acceptsList]、`scheduleTaskToDay` 的「已是那天就不写」同一口径）。
  bool acceptsSmartList(TodoTask task, SmartListTimeCondition condition) =>
      !condition.satisfiedBy(_dueWallClockOf(task));

  Future<SidebarDropOutcome> moveToList(TodoTask task, String listId) {
    return _serialize(task.id, () async {
      // 判据在**落下时**按库里当前行算，不按拖出快照（FL #585）。
      if (!acceptsList(await _currentRow(task), listId)) {
        return SidebarDropOutcome.skipped;
      }
      // :59「移动到目标清单」只提清单，没提时间 ⇒ 时间安排一毫秒都不动。
      await moveTask(task.id, listId);
      return SidebarDropOutcome.applied;
    });
  }

  /// 嘀嗒 `:61`「拖动到智能清单上」`:63`「会为任务自动添加该智能清单关联的时间条件」。
  ///
  /// 只挪截止日那一格：时刻（有则保留）、清单归属、分组、标签都不动 ——
  /// 原文这一句说的是「添加时间条件」，没说换清单。
  Future<SidebarDropOutcome> applySmartListTimeCondition(
    TodoTask task,
    SmartListTimeCondition condition,
  ) {
    return _serialize(task.id, () async {
      // 同上：与清单行一起改才对称（两处原来是同一形状的两份）。
      if (!acceptsSmartList(await _currentRow(task), condition)) {
        return SidebarDropOutcome.skipped;
      }
      await scheduleToDay(task.id, condition.targetDay);
      return SidebarDropOutcome.applied;
    });
  }

  Future<SidebarDropOutcome> addTagToTask(TodoTask task, String tagId) {
    // 这一处**本来就没有** #585 那个问题：`attachTag` 现读 `tagIdsOf` 再决定加不加，
    // 判据落在库里而不是快照上。三个落点、同一口径，这里保持不动只跟签名。
    return _serialize(task.id, () async {
      await attachTag(task.id, tagId);
      return SidebarDropOutcome.applied;
    });
  }

  Future<SidebarDropOutcome> _serialize(
    String taskId,
    Future<SidebarDropOutcome> Function() operation,
  ) async {
    var outcome = SidebarDropOutcome.applied;
    final previous = _chain[taskId] ?? Future<void>.value();
    // 失败也要把链条续上（onError 只记结果不重抛），否则下一刀会挂在旧错误上被静默跳过。
    final current = previous
        .then((_) => operation())
        .then<void>(
          (result) {
            outcome = result;
          },
          onError: (Object error, StackTrace stackTrace) {
            outcome = SidebarDropOutcome.failed;
          },
        );
    _chain[taskId] = current;
    await current;
    if (_chain[taskId] == current) _chain.remove(taskId);
    return outcome;
  }

  /// 判据用的当前行：读得到就用库里的，读不到（行已删）退回拖出快照。
  Future<TodoTask> _currentRow(TodoTask snapshot) async =>
      await loadTask(snapshot.id) ?? snapshot;

  /// 与 `_dateConditionMatches`（任务页的过滤谓词）同一套展示墙钟换算，
  /// 否则「落点判据」与「这一档清单到底显示哪些任务」会各说各话。
  DateTime? _dueWallClockOf(TodoTask task) {
    final due = task.dueAt;
    if (due == null) return null;
    return taskWallClockDateTime(
      due,
      allDay: task.allDay,
      mode: TaskTimeMode.fromWire(task.timeMode),
      timeZone: task.timeZone,
    );
  }
}

/// 控制器挂在 provider 上而不是每次 build 新建：串行链要活得过重绘，
/// 否则侧栏刷一次就把「同一任务串行」这件事抹平了。
final sidebarTaskDropControllerProvider = Provider<SidebarTaskDropController>((
  ref,
) {
  return SidebarTaskDropController(
    loadTask: (taskId) async {
      final repository = ref.read(taskRepositoryProvider);
      if (repository == null) throw StateError('任务仓储未就绪');
      return repository.getById(taskId);
    },
    moveTask: (taskId, listId) async {
      final repository = ref.read(taskRepositoryProvider);
      if (repository == null) throw StateError('任务仓储未就绪');
      // sectionId 属于原清单，换清单后已无意义，必须一起清掉。
      await repository.update(taskId, listId: listId, clearSectionId: true);
    },
    attachTag: (taskId, tagId) async {
      final repository = ref.read(tagRepositoryProvider);
      if (repository == null) throw StateError('标签仓储未就绪');
      final current = await repository.tagIdsOf(taskId);
      if (current.contains(tagId)) return;
      await repository.setTaskTags(taskId, <String>[...current, tagId]);
    },
    scheduleToDay: (taskId, targetDay) async {
      final repository = ref.read(taskViewActionRepositoryProvider);
      if (repository == null) throw StateError('任务视图操作仓储未就绪');
      await repository.scheduleTaskToDay(taskId, targetDay: targetDay);
    },
  );
});
