import 'package:flutter/material.dart';

import 'task_detail_pane.dart';

/// 任务详情兼容页面。
///
/// 历史调用方继续使用 [TaskDetailPage]；真实详情状态、表单和操作全部由
/// [TaskDetailPane] 提供，避免页面、抽屉与固定右栏维护多份实现。
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId, this.asSheet = false});

  final String taskId;
  final bool asSheet;

  @override
  Widget build(BuildContext context) {
    return TaskDetailPane(taskId: taskId, embedded: asSheet);
  }
}

/// 弹出任务详情 Sheet（#31）。
///
/// - **宽屏（≥600dp）**：右侧抽屉，宽度 420dp，从右向左滑出
/// - **窄屏（<600dp）**：底部 Sheet，高度约 90%，向上滑出
Future<void> showTaskDetailSheet(
  BuildContext context,
  String taskId, {
  bool useRootNavigator = true,
}) async {
  final isWide = MediaQuery.sizeOf(context).width >= 600;

  if (isWide) {
    await showDialog<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: Colors.black54,
      builder: (ctx) => _RightSideSheet(
        width: 420,
        child: TaskDetailPage(taskId: taskId, asSheet: true),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: TaskDetailPage(taskId: taskId, asSheet: true),
    ),
  );
}

class _RightSideSheet extends StatelessWidget {
  const _RightSideSheet({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}
