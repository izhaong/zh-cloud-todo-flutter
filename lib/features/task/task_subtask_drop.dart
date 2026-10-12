import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》的"拖动成子任务"：
/// - mobile tab `:20`「通过拖动将现有的任务转化成子任务。」
/// - desktop tab `:60-:61`「通过拖动将现有的任务转化成子任务。
///   将光标覆盖在一个任务上，按住任务前的图标拖动到另一个任务**右下方**即可快速转化为子任务。」
///
/// 「右下方」用**几何**实现：这一行的右下象限单独是一个 `DragTarget`，其余区域不是。
/// 命中判定因此是框架自己的命中测试，不是这里手算的坐标带 —— 手写坐标带在这个 SDK 上做不了：
/// `DragTargetDetails.offset` 量的是 `_lastOffset = globalPosition - dragStartPoint`
/// （`drag_target.dart:893`，源未设 `dragAnchorStrategy` 时 `dragStartPoint` 是
/// `centerDragAnchorStrategy` 的返回值，不是全局指针位置），拿它当全局坐标算象限必然算错。
/// 落点区域只占右下象限（`FractionallySizedBox` 0.5×0.5 + `Alignment.bottomRight`），
/// 所以"同一次拖、不同落点 ⇒ 不同结果"是行本身的几何给的，左上落点那条用例咬得住它。
///
/// 这一层不抢点击：`DragTarget.hitTestBehavior` 缺省 `translucent`（`drag_target.dart:640`），
/// 它把自己挂进命中路径但不吞命中，行体的"点开这一行"与行首排序手柄照旧。
///
/// 拖出源沿用清单行已有的 `LongPressDraggable<TodoTask>`（并列日历那一面 `:49` 用的就是它）：
/// 原文给的是**一个**手势、由落点位置决定结果，所以这里只加落点，不再造第二个拖出源。
class TaskSubtaskDropTarget extends StatefulWidget {
  const TaskSubtaskDropTarget({
    required this.task,
    required this.enabled,
    required this.onDrop,
    required this.child,
    super.key,
  });

  /// 这一行对应的任务 = 潜在的**父任务**。
  final TodoTask task;

  /// 页身份闸门：嘀嗒 `:28`「这一功能在「今天」、「最近七天」等智能清单中不可用，
  /// 只可以在「收集箱」以及自己创建的普通清单中可用」。false 时这一行根本不是落点。
  final bool enabled;
  final Future<void> Function(TodoTask dragged) onDrop;
  final Widget child;

  /// 读屏语义挂在带 key 的节点自己身上：测试读 `getSemantics(byKey).label`，
  /// 不用全树 `bySemanticsLabel`（那会被旁侧 `Text` 满足而恒真）。
  static Key zoneKey(String taskId) =>
      ValueKey<String>('todo-task-subtask-drop-$taskId');

  static String hoverLabel(String parentTitle) => '成为「$parentTitle」的子任务';

  @override
  State<TaskSubtaskDropTarget> createState() => _TaskSubtaskDropTargetState();
}

class _TaskSubtaskDropTargetState extends State<TaskSubtaskDropTarget> {
  void _accept(TodoTask dragged) => unawaited(_drop(dragged));

  /// 失败必须看得见：成环与五层上限都在仓储里抛 `StateError`，
  /// 提示走 `describeError` 这条本仓统一通道 —— 直接把异常对象插进文案会被
  /// `test/tooling/raw_error_text_gate_test.dart` 判红（本面第一版就是这么写的）。
  Future<void> _drop(TodoTask dragged) async {
    try {
      await widget.onDrop(dragged);
    } catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final parent = widget.task.title;
      messenger.showSnackBar(
        SnackBar(content: Text('变成「$parent」的子任务失败：${describeError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 闸门关掉时这一行连落点都不是：不建 DragTarget，也就不会在智能清单里
    // 抢下同一坐标的拖拽（外层 `TaskListDropTarget` 那一类落点照旧生效）。
    if (!widget.enabled) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.5,
            alignment: Alignment.bottomRight,
            child: DragTarget<TodoTask>(
              // 只接**同一张清单**里的任务：清单页的整块列表体外层还套着
              // `TaskListDropTarget`（嘀嗒《07-任务与日历同时显示.md》:55「将日历中的任务拖入清单详情区域」
              // ＝移入当前清单），它吃的也是 `TodoTask`。内层来者不拒就会把异清单任务截走，
              // 那一面当场失效（这条是先跑出红、再补的条件：
              // test/features/task/task_subtask_drag_test.dart 的「异清单任务落到右下带」）。
              // 自己不能当自己的父任务；成环与 5 层上限由仓储那条通道兜住（失败给可见提示）。
              onWillAcceptWithDetails: (details) =>
                  details.data.listId == widget.task.listId &&
                  details.data.id != widget.task.id,
              onAcceptWithDetails: (details) => _accept(details.data),
              builder: (context, candidates, _) {
                if (candidates.isEmpty) return const SizedBox.shrink();
                final color = Theme.of(context).colorScheme.primary;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    border: Border.all(color: color),
                  ),
                  child: Semantics(
                    key: TaskSubtaskDropTarget.zoneKey(widget.task.id),
                    label: TaskSubtaskDropTarget.hoverLabel(widget.task.title),
                    child: const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
