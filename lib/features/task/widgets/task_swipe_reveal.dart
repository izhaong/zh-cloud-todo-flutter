import 'package:flutter/material.dart';

import '../../../core/task/task_swipe_preferences.dart';

/// 一侧的一个动作钮。颜色由调用方给（沿用倒数纪念日那一面的
/// `*Container` / `on*Container` 成对取色，那一对是主题里保证对比度的组合）。
///
/// `onTap == null` 表示"这一档此刻不可用"：钮留在原位但点不动。
/// 选"禁用"而不是"消失"是因为消失会让这一侧的露出宽度随状态变，
/// 而滑动位移是按档位数量算的 —— 两套口径迟早对不上，位移落在一个
/// 已经不存在的钮上，就是"看着能点、点下去没反应"。
class TaskSwipeActionSpec {
  const TaskSwipeActionSpec({
    required this.action,
    required this.key,
    required this.background,
    required this.foreground,
    this.onTap,
    this.label,
  });

  final TaskSwipeAction action;
  final Key key;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  /// 覆盖默认文案（已完成那一行的「完成」要说「取消完成」）。
  final String? label;
}

/// 任务行的双向滑动露出动作。
///
/// 判据源：嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》
/// - `:66`「将任务向左短滑，可以看到任务右侧出现了三个选项……「移动任务」、
///   「删除任务」、「修改日期」，根据需要点击对应的选项进行操作。」
/// - `:71`「向右滑动分别为「完成」、「置顶」。」
///
/// ⇒ 形状是**短滑露出按钮、再点按钮才执行**（原文"出现了三个选项……点击对应的
///   选项进行操作"），不是滑到尽头直接完成。所以这里不是 `Dismissible`——
///   它绑死的正是"滑动即执行"那一形状，而且一个方向只能挂一个动作。
///
/// 方向命名跟 `DismissDirection`：
/// - [startToEndActions] = 手指向右拖 = 原文「向右滑动」，钮露在行的**左**边；
/// - [endToStartActions] = 手指向左拖 = 原文「向左短滑」，钮露在行的**右**边。
/// 两侧共用一个位移，所以任一时刻只可能露出一侧（原文也是这个意思：
/// 一次滑动只出现一头的选项）。
class TaskSwipeRevealRow extends StatefulWidget {
  const TaskSwipeRevealRow({
    super.key,
    required this.startToEndActions,
    required this.endToStartActions,
    required this.child,
  });

  final List<TaskSwipeActionSpec> startToEndActions;
  final List<TaskSwipeActionSpec> endToStartActions;
  final Widget child;

  /// 单个动作钮的宽度：三个并排 216px，在 320px 窄屏上仍给行体留出身份区。
  static const double slotWidth = 72.0;

  @override
  State<TaskSwipeRevealRow> createState() => TaskSwipeRevealRowState();
}

class TaskSwipeRevealRowState extends State<TaskSwipeRevealRow>
    with SingleTickerProviderStateMixin {
  /// 位移按像素：正值 = 内容右移（露出左侧动作），负值 = 内容左移（露出右侧动作）。
  late final AnimationController _ctrl = AnimationController.unbounded(
    vsync: this,
  );

  double get _leftWidth =>
      TaskSwipeRevealRow.slotWidth * widget.startToEndActions.length;

  double get _rightWidth =>
      TaskSwipeRevealRow.slotWidth * widget.endToStartActions.length;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 换档位（设置页改完回来）时，别把上一档的露出状态留在屏幕上：
  /// 那一格可能已经不存在了，位移也对不上新的侧宽。
  @override
  void didUpdateWidget(TaskSwipeRevealRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shapeChanged =
        oldWidget.startToEndActions.length != widget.startToEndActions.length ||
        oldWidget.endToStartActions.length != widget.endToStartActions.length;
    if (shapeChanged && _ctrl.value != 0) _collapse();
  }

  void _onDragUpdate(double dx) {
    _ctrl.stop();
    _ctrl.value = (_ctrl.value + dx).clamp(-_rightWidth, _leftWidth);
  }

  void _onDragEnd(double velocity) {
    // 甩动方向决定落在哪一侧；慢慢停住时按当前位移判（与倒数纪念日那一面同一套手感）。
    final target = _targetFor(velocity);
    _ctrl.animateTo(
      target,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 150),
    );
  }

  double _targetFor(double velocity) {
    if (velocity <= -400) return -_rightWidth;
    if (velocity >= 400) return _leftWidth;
    final value = _ctrl.value;
    if (value >= 0) {
      return value >= _leftWidth * 0.4 ? _leftWidth : 0;
    }
    return -value >= _rightWidth * 0.4 ? -_rightWidth : 0;
  }

  void _collapse() {
    _ctrl.animateTo(
      0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 150),
    );
  }

  Widget _actions(List<TaskSwipeActionSpec> specs, {required bool atStart}) {
    final row = Row(
      children: [
        for (final spec in specs)
          SizedBox(
            width: TaskSwipeRevealRow.slotWidth,
            child: Semantics(
              button: true,
              label: spec.label ?? spec.action.label,
              // 里面的 Text 不再自己报一遍：读屏会把"移动任务"念两次
              // （档位名一份 + 画出来的字一份），而两份迟早会漂。
              child: ExcludeSemantics(
                child: Material(
                  color: spec.background,
                  child: InkWell(
                    key: spec.key,
                    onTap: spec.onTap == null
                        ? null
                        : () {
                            // 先收回去再执行：动作之后这一行多半要变（完成态、换清单），
                            // 留着露出状态会显示一张过期的按钮条。
                            _collapse();
                            spec.onTap!();
                          },
                    child: Center(
                      // scaleDown 而不是靠固定宽度截断：字号被系统放大时宁可缩字，
                      // 也不让四个字的文案溢出成一条错误的按钮。
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            spec.label ?? spec.action.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: spec.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Positioned(
      top: 0,
      bottom: 0,
      width: TaskSwipeRevealRow.slotWidth * specs.length.toDouble(),
      left: atStart ? 0 : null,
      right: atStart ? null : 0,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragUpdate: (details) =>
                _onDragUpdate(details.delta.dx),
            onHorizontalDragEnd: (details) =>
                _onDragEnd(details.primaryVelocity ?? 0),
            child: AnimatedBuilder(
              animation: _ctrl,
              child: widget.child,
              builder: (context, child) {
                final value = _ctrl.value;
                return Stack(
                  children: [
                    // 关闭态整条动作带**根本不建**：任务行的底色是透明的（选中/悬停色
                    // 由外层给），一直画着就会在静止时把按钮透出来 —— 黄金基线实测到的就是这个。
                    if (value > 0 && widget.startToEndActions.isNotEmpty)
                      _actions(widget.startToEndActions, atStart: true),
                    if (value < 0 && widget.endToStartActions.isNotEmpty)
                      _actions(widget.endToStartActions, atStart: false),
                    Transform.translate(
                      offset: Offset(value, 0),
                      child: SizedBox(width: width, child: child),
                    ),
                    // 露出状态下行体上的点击先收回去，不该顺手选中任务或勾掉勾选框。
                    // Barrier 只盖行体那一段，两侧的钮在它之外，照样点得动。
                    if (value.abs() > 0.5)
                      Positioned(
                        left: value,
                        width: width,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          key: const Key('todo-task-swipe-collapse-barrier'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _collapse,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// 某一行的某一档的稳定 Key（界面测试与语义树都按这一个名字找）。
Key taskSwipeActionKey(TaskSwipeAction action, String taskId) =>
    Key('todo-task-swipe-${action.wire}-$taskId');
