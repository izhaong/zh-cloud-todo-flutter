import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';

/// 清单行内的拖放落点。嘀嗒的原文分两页，落点也按句划成互不重叠的三块：
///
/// 《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》
/// - mobile tab `:20`「通过拖动将现有的任务转化成子任务。」（FL #590）
/// - desktop tab `:60-:61`「……拖动到另一个任务**右下方**即可快速转化为子任务。」（FL #590）
/// - mobile tab `:24`「通过拖动「+」到任务下方偏右一点的位置来在这个任务下快速创建「子任务」。」（FL #591）
///
/// 《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》
/// - 「拖动排序」一节：「你还可以自已手动拖动任务的顺序，让任务排序更灵活。」
///   「按住任务，自由选择放置任务的位置。多种操作，一“指”搞定。」（FL #595）
/// - 「拖动生成子任务」一节：「滴答清单不仅支持拖动调整任务排序，你还可以用拖动来实现
///   「任务」➡️「子任务」的转换。」「长按任务，将其拖至另一个任务右下方，即可将这个任务转换成子任务。」
///
/// ⇒ 一行被划成三格，"同一个手势、由放置位置决定结果"就是这么落的：
/// **上半条＝排到该行之前**、**下半左＝排到该行之后**、**下半右＝转子任务**
/// （右下那块里还叠着「+」的建子任务落点）。三块互不重叠 ⇒ 一次拖只有一块在指针下，
/// 所以"同一次拖、不同落点 ⇒ 不同结果"能被一条用例量出来（三块对照就是它）。
///
/// 为什么用几何而不是手算坐标带：SDK 交给落点的 `DragTargetDetails.offset` 是
/// `globalPosition - dragStartPoint`（源未设 `dragAnchorStrategy` 时那个起点不是全局指针位置），
/// 拿它当全局坐标算区域必错（FL #590 第一版就这么错过，那批用例读数 `+3 -7`）。
/// 每块都是 `Positioned.fill` + `FractionallySizedBox`：`Stack` 给非 positioned 孩子 loose 约束，
/// 不 fill 就按内容收缩成 0×0 —— 既画不出高亮也进不了命中路径（FL #591 实测踩过）。
///
/// 这一层不抢点击：`DragTarget.hitTestBehavior` 缺省 `translucent`，它挂进命中路径但不吞命中，
/// 行体的"点开这一行"与行首排序手柄照旧（各有用例钉着）。
///
/// 两种拖出物按**泛型**分流：`DragTarget<TodoTask>`（转子任务/放置排序）与
/// `DragTarget<QuickAddSubtaskIntent>`（建子任务）；SDK 找落点时先按类型过滤，互不截走。
///
/// 任务侧的拖出源沿用清单行已有的 `LongPressDraggable<TodoTask>`（并列日历那一面用的就是它，
/// 嘀嗒原文写的也是「长按任务」）：这里只加落点，不再造第二个拖出源。
class TaskSubtaskDropTarget extends StatefulWidget {
  const TaskSubtaskDropTarget({
    required this.task,
    required this.enabled,
    required this.onDrop,
    required this.child,
    this.onCreateParent,
    this.onPlace,
    super.key,
  });

  /// 这一行对应的任务 = 潜在的**父任务**，也是放置排序时参照的那一行。
  final TodoTask task;

  /// 页身份闸门：嘀嗒 `:28`「这一功能在「今天」、「最近七天」等智能清单中不可用，
  /// 只可以在「收集箱」以及自己创建的普通清单中可用」。false 时这一行根本不是落点。
  final bool enabled;
  final Future<void> Function(TodoTask dragged) onDrop;
  final Widget child;

  /// 拖「+」落到这一行 ⇒ 在这一行下建子任务（嘀嗒 `:24`）。
  /// null（比如没有清单行身份的页面）时这一块落点不建 ——
  /// 「+」拖上去什么也不发生，而不是落进一块"看着能落、落下去没反应"的区域。
  final Future<void> Function(TodoTask parent)? onCreateParent;

  /// 拖任务落到这一行的上半/左下 ⇒ 把 dragged 放到这一行**之前/之后**（《01-列表视图.md》拖动排序）。
  /// null（智能清单、有分组、只读清单这些"手动排序本来就不可用"的场合）时这两块落点不建。
  final Future<void> Function(TodoTask dragged, bool after)? onPlace;

  /// 读屏语义挂在带 key 的节点自己身上：测试读 `getSemantics(byKey).label`，
  /// 不用全树 `bySemanticsLabel`（那会被旁侧 `Text` 满足而恒真）。
  static Key zoneKey(String taskId) =>
      ValueKey<String>('todo-task-subtask-drop-$taskId');

  static Key createZoneKey(String taskId) =>
      ValueKey<String>('todo-task-subtask-create-$taskId');

  static Key beforeZoneKey(String taskId) =>
      ValueKey<String>('todo-task-place-before-$taskId');

  static Key afterZoneKey(String taskId) =>
      ValueKey<String>('todo-task-place-after-$taskId');

  /// 落点**本身**的 key（恒挂在 `DragTarget` 上，不随候选态开关）：
  /// 上面那几个 `*ZoneKey` 是悬停时才建的高亮节点，静止态永远找不到 ——
  /// 拿它们判"这一行是不是落点"就是恒过的假判据。闸门类断言（智能清单/有分组不该有落点）
  /// 要量这一对。
  static Key beforeDropKey(String taskId) =>
      ValueKey<String>('todo-task-place-before-drop-$taskId');

  static Key afterDropKey(String taskId) =>
      ValueKey<String>('todo-task-place-after-drop-$taskId');

  static String hoverLabel(String parentTitle) => '成为「$parentTitle」的子任务';

  static String createHoverLabel(String parentTitle) => '在「$parentTitle」下新建子任务';

  static String beforeHoverLabel(String rowTitle) => '排到「$rowTitle」之前';

  static String afterHoverLabel(String rowTitle) => '排到「$rowTitle」之后';

  @override
  State<TaskSubtaskDropTarget> createState() => _TaskSubtaskDropTargetState();
}

class _TaskSubtaskDropTargetState extends State<TaskSubtaskDropTarget> {
  void _accept(TodoTask dragged) => unawaited(_drop(dragged));

  void _acceptCreate() => unawaited(_dropCreate());

  void _acceptPlace(TodoTask dragged, bool after) =>
      unawaited(_dropPlace(dragged, after));

  /// 失败必须看得见：仓储抛的 `StateError`（成环、五层上限、只读清单、排序保存失败）
  /// 都经 `describeError` 这条本仓统一通道上屏 —— 直接把异常对象插进文案会被
  /// `test/tooling/raw_error_text_gate_test.dart` 判失项（FL #590 第一版就是这么写的）。
  Future<void> _drop(TodoTask dragged) async {
    try {
      await widget.onDrop(dragged);
    } catch (error) {
      _showFailure('变成「${widget.task.title}」的子任务失败', error);
    }
  }

  Future<void> _dropCreate() async {
    try {
      await widget.onCreateParent?.call(widget.task);
    } catch (error) {
      _showFailure('在「${widget.task.title}」下新建子任务失败', error);
    }
  }

  Future<void> _dropPlace(TodoTask dragged, bool after) async {
    try {
      await widget.onPlace?.call(dragged, after);
    } catch (error) {
      final where = after ? '之后' : '之前';
      _showFailure('排到「${widget.task.title}」$where失败', error);
    }
  }

  void _showFailure(String prefix, Object error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('$prefix：${describeError(error)}')),
    );
  }

  /// 候选态（指针停在这一格）才画高亮与读屏文案；静止什么都不加。
  Widget _hover({
    required String label,
    required Key key,
    _Highlight highlight = _Highlight.quad,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    final line = BorderSide(color: color, width: 3);
    return DecoratedBox(
      decoration: switch (highlight) {
        // 转子任务那块：整圈描边 + 底色，形状是"这一格被吃掉"。
        _Highlight.quad => BoxDecoration(
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color),
        ),
        // 放置那两块：只在**将要插入的那条边**画一条线（行顶＝排到之前、行底＝排到之后）。
        // 交叉验证提的就是这点 —— 三格同色同形时"在排序"和"在建父子"只有读屏能分，
        // 而最容易误触的恰是共边的左下／右下两格。
        _Highlight.insertTop => BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border(top: line),
        ),
        _Highlight.insertBottom => BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border(bottom: line),
        ),
      },
      child: Semantics(key: key, label: label, child: const SizedBox.shrink()),
    );
  }

  /// 三块吃任务的落点共用同一套接受条件：
  /// ① 只接**同一张清单**里的任务 —— 清单页列表体外层还套着 `TaskListDropTarget`
  ///    （嘀嗒《07-任务与日历同时显示.md》「将日历中的任务拖入清单详情区域」＝移入当前清单），
  ///    它吃的也是 `TodoTask`；内层来者不拒会把异清单任务截走（FL #590 先跑出红才补的这条）。
  /// ② 自己不是自己的目标：既不给自己当父任务，也不"排到自己前面/后面"。
  bool _acceptsTask(TodoTask dragged) =>
      dragged.listId == widget.task.listId && dragged.id != widget.task.id;

  /// 放置排序那两块还要多一道：**只接同一父级下的兄弟**。
  /// 清单页把子任务铺成行之后（`tasks_by_list_page.dart` 的 `_subtreeOf`），
  /// 渲染顺序是"父在前、其子紧跟"，跨父的插入位在那棵树里没有对应的位置 ——
  /// 收下这一刀只会写出一个"归堆后被弹回原处"的顺序，就是"看着能落、落下去没反应"。
  /// 换父本来也不是放置该管的事：《06-多级任务.md》:20/:49 给的是右下那块转子任务。
  bool _acceptsPlacement(TodoTask dragged) =>
      _acceptsTask(dragged) && dragged.parentTaskId == widget.task.parentTaskId;

  /// 一块任务落点：区域由分数与对齐决定（三块互不重叠即可），`nested` 是给「+」留的叠层。
  Widget _taskZone({
    required double widthFactor,
    required double heightFactor,
    required Alignment alignment,
    required String label,
    required Key hoverKey,
    Key? dropKey,
    bool placementZone = false,
    _Highlight highlight = _Highlight.quad,
    required void Function(TodoTask dragged) onAccept,
    Widget? nested,
  }) {
    return Positioned.fill(
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        alignment: alignment,
        child: DragTarget<TodoTask>(
          key: dropKey,
          onWillAcceptWithDetails: (details) => placementZone
              ? _acceptsPlacement(details.data)
              : _acceptsTask(details.data),
          onAcceptWithDetails: (details) => onAccept(details.data),
          builder: (context, candidates, _) => Stack(
            children: [
              // 高亮与叠层都要 Positioned.fill（见文件头那条 0×0 的教训）；
              // 「+」那一层还要无条件挂着，不能"这一帧没候选就不建"。
              if (candidates.isNotEmpty)
                Positioned.fill(
                  child: _hover(
                    label: label,
                    key: hoverKey,
                    highlight: highlight,
                  ),
                ),
              if (nested != null) Positioned.fill(child: nested),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 闸门关掉时这一行连落点都不是：不建 DragTarget，也就不会在智能清单里
    // 抢下同一坐标的拖拽（外层 `TaskListDropTarget` 那一类落点照旧生效）。
    if (!widget.enabled) return widget.child;
    final title = widget.task.title;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.onPlace != null)
          _taskZone(
            widthFactor: 1,
            heightFactor: 0.5,
            alignment: Alignment.topCenter,
            label: TaskSubtaskDropTarget.beforeHoverLabel(title),
            hoverKey: TaskSubtaskDropTarget.beforeZoneKey(widget.task.id),
            dropKey: TaskSubtaskDropTarget.beforeDropKey(widget.task.id),
            placementZone: true,
            highlight: _Highlight.insertTop,
            onAccept: (dragged) => _acceptPlace(dragged, false),
          ),
        if (widget.onPlace != null)
          _taskZone(
            widthFactor: 0.5,
            heightFactor: 0.5,
            alignment: Alignment.bottomLeft,
            label: TaskSubtaskDropTarget.afterHoverLabel(title),
            hoverKey: TaskSubtaskDropTarget.afterZoneKey(widget.task.id),
            dropKey: TaskSubtaskDropTarget.afterDropKey(widget.task.id),
            placementZone: true,
            highlight: _Highlight.insertBottom,
            onAccept: (dragged) => _acceptPlace(dragged, true),
          ),
        // 下半右块：转子任务（FL #590），里面叠着「+」的建子任务落点（FL #591）。
        _taskZone(
          widthFactor: 0.5,
          heightFactor: 0.5,
          alignment: Alignment.bottomRight,
          label: TaskSubtaskDropTarget.hoverLabel(title),
          hoverKey: TaskSubtaskDropTarget.zoneKey(widget.task.id),
          onAccept: _accept,
          nested: widget.onCreateParent == null
              ? null
              : DragTarget<QuickAddSubtaskIntent>(
                  // 闸门已在外层 `enabled` 上判过页身份与可写；这里没有"哪个任务"要挑，
                  // 落点要的就是"在这一行下建"，所以不再自设第二条过滤。
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (_) => _acceptCreate(),
                  builder: (context, createCandidates, _) =>
                      createCandidates.isEmpty
                      ? const SizedBox.shrink()
                      : _hover(
                          label: TaskSubtaskDropTarget.createHoverLabel(title),
                          key: TaskSubtaskDropTarget.createZoneKey(
                            widget.task.id,
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

/// 候选态怎么画：转子任务那块是整圈描边，放置那两块只在插入边画一条线。
enum _Highlight { quad, insertTop, insertBottom }

/// 「+」被拖起来的载荷：它不代表某个已存在的任务，只代表"要在这个任务下建一个子任务"。
/// 用独立类型而不是 `TodoTask`，是为了让 SDK 的类型过滤把两种拖分开（见本文件头）。
class QuickAddSubtaskIntent {
  const QuickAddSubtaskIntent();
}
