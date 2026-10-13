import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/task/task_swipe_preferences.dart';
import '../../core/theme/brand_colors.dart';
import '../../state/providers.dart';

/// 配置页上的"一侧"。命名跟着**手指方向**，不跟着按钮位置 ——
/// 行右侧的钮其实是向左滑露出来的，两处各用各的口径正是这一面最容易写歪的地方。
enum TaskSwipeSide {
  swipeLeft('swipeLeft', '向左滑（按钮露在行的右边）', '默认：移动任务、删除任务、修改日期'),
  swipeRight('swipeRight', '向右滑（按钮露在行的左边）', '默认：完成、置顶');

  const TaskSwipeSide(this.wire, this.heading, this.hint);

  final String wire;
  final String heading;
  final String hint;

  List<TaskSwipeAction> actionsOf(TaskSwipePreferences preferences) =>
      switch (this) {
        TaskSwipeSide.swipeLeft => preferences.swipeLeft,
        TaskSwipeSide.swipeRight => preferences.swipeRight,
      };

  TaskSwipePreferences replacing(
    TaskSwipePreferences preferences,
    List<TaskSwipeAction> actions,
  ) => switch (this) {
    TaskSwipeSide.swipeLeft => preferences.withSwipeLeft(actions),
    TaskSwipeSide.swipeRight => preferences.withSwipeRight(actions),
  };
}

/// 「设置 → 任务 → 滑动操作」：自定义任务行左右滑动各露出哪些动作。
///
/// 判据源：嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》`:75`
/// 「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置」。
/// 路径差一处并已记进台账：本应用的设置页没有「更多设置」那一层，
/// 这一项直接落在「任务」分组里 —— 名字与"可以进行自定义配置"照原文。
///
/// 勾选即保存（与「时区」「星期开始于」同一形状）：值直接读仓储流的现值、
/// 不做乐观更新，写失败时勾选框因此自动留在切换前。
class TaskSwipeSettingsPage extends ConsumerWidget {
  const TaskSwipeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final preferences = resolveTaskSwipePreferences(
      ref.watch(taskSwipePreferencesProvider),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('滑动操作')),
      body: ListView(
        // 底部留出确认条的高度：「恢复默认」是这一页最下面那颗，
        // 不留的话每次勾选弹出的确认条会正好盖住它（本轮实测挂在这里）。
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          Text(
            '一侧最多 ${TaskSwipePreferences.maxActionsPerSide} 个动作；'
            '勾选的先后就是按钮从行内侧往外的排列顺序。',
            style: TextStyle(color: colors.mutedForeground),
          ),
          for (final side in TaskSwipeSide.values) ...[
            _SideHeading(side: side),
            for (final action in TaskSwipeAction.values)
              CheckboxListTile(
                key: Key('todo-settings-swipe-${side.wire}-${action.wire}'),
                value: side.actionsOf(preferences).contains(action),
                // 已满一侧只放行"取消勾选"：与其让人勾了被弹回去，
                // 不如当场就按不动。
                onChanged: _canToggle(side, preferences, action)
                    ? (checked) => _toggle(
                        context,
                        ref,
                        side,
                        preferences,
                        action,
                        checked ?? false,
                      )
                    : null,
                title: Text(action.label),
                // 序号是"顺序"这件事唯一的可见证据，否则勾选的先后没有任何地方能核对。
                secondary: side.actionsOf(preferences).contains(action)
                    ? CircleAvatar(
                        radius: 12,
                        child: Text(
                          '${side.actionsOf(preferences).indexOf(action) + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )
                    : null,
              ),
          ],
          const SizedBox(height: 16),
          TextButton(
            key: const Key('todo-settings-swipe-reset'),
            onPressed: () =>
                _save(context, ref, TaskSwipePreferences.defaults, '已恢复默认滑动操作'),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  bool _canToggle(
    TaskSwipeSide side,
    TaskSwipePreferences preferences,
    TaskSwipeAction action,
  ) {
    final actions = side.actionsOf(preferences);
    if (actions.contains(action)) return true;
    return actions.length < TaskSwipePreferences.maxActionsPerSide;
  }

  void _toggle(
    BuildContext context,
    WidgetRef ref,
    TaskSwipeSide side,
    TaskSwipePreferences preferences,
    TaskSwipeAction action,
    bool checked,
  ) {
    final current = side.actionsOf(preferences);
    final next = checked
        ? [...current, action]
        : [
            for (final item in current)
              if (item != action) item,
          ];
    _save(context, ref, side.replacing(preferences, next), '滑动操作已保存，等待同步');
  }

  void _save(
    BuildContext context,
    WidgetRef ref,
    TaskSwipePreferences preferences,
    String successLabel,
  ) {
    final repository = ref.read(taskSwipePreferenceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (repository == null) {
      messenger.showSnackBar(const SnackBar(content: Text('滑动操作暂不可保存，请稍后重试')));
      return;
    }
    repository
        .save(preferences)
        .then((_) {
          // 每次勾选都提示一句，连着改就会排成一串过期确认；这一页的反馈
          // 只该有最新那条（清单页批量操作也是同一处理）。
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(content: Text(successLabel)));
        })
        .catchError((Object _) {
          // 仓储会拒重复与超上限的配置；界面已经先把这两条挡住了，走到这里
          // 说明还有别的原因。只说"保存失败"，不把异常对象塞进文案。
          messenger.showSnackBar(const SnackBar(content: Text('滑动操作保存失败，请重试')));
        });
  }
}

class _SideHeading extends StatelessWidget {
  const _SideHeading({required this.side});

  final TaskSwipeSide side;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            side.heading,
            style: TextStyle(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Text(
            side.hint,
            style: TextStyle(color: colors.mutedForeground, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
