import 'package:flutter/material.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》`:53`「将日历中的任务拖入清单详情区域」。
///
/// 原句 `:55`「任务会从原所属清单迁移到当前查看的清单中，并保留其原有的时间安排。」
/// ⇒ 这个落点只做「换所属清单」：时间安排（`dueAt`/`startAt`/`endAt`/`allDay`）一个都不碰。
/// `sectionId` 要清空 —— 分组属于原清单，把它带进新清单会指到别的清单的分组上。
///
/// 只做手势容器与高亮，不改被包内容的外观。日历侧的拖出源是
/// `lib/features/task/views/calendar_view.dart` 里 `Draggable<TodoTask>` 的任务条。
class TaskListDropTarget extends StatelessWidget {
  const TaskListDropTarget({
    required this.currentListId,
    required this.onAccept,
    required this.child,
    super.key,
  });

  /// 当前查看的清单；为 null（没选中具体清单）时这个落点不存在，直接返回原内容。
  final String? currentListId;

  /// 落点被命中时的回调，参数是日历侧拖出来的任务。
  final void Function(TodoTask task) onAccept;

  final Widget child;

  /// 读屏语义挂在落点自己的节点上：测试要钉得住这个节点，而不是全树随便一个同名 `Text`。
  static const ValueKey<String> zoneKey = ValueKey<String>(
    'todo-list-drop-target',
  );

  /// 语义取 `:55` 那句的效果描述，不另造嘀嗒没有的功能名词。
  static const String zoneLabel = '移入当前清单';

  @override
  Widget build(BuildContext context) {
    final listId = currentListId;
    if (listId == null) return child;
    return Semantics(
      key: zoneKey,
      container: true,
      label: zoneLabel,
      child: DragTarget<TodoTask>(
        // 已经在当前清单里的任务不构成一次迁移：不接受，也就不画高亮。
        onWillAcceptWithDetails: (details) => details.data.listId != listId,
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidateData, rejectedData) {
          final Widget body = candidateData.isEmpty
              ? child
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: child,
                );
          return body;
        },
      ),
    );
  }
}

/// 页侧的落点处理。拆出 State 之外是为了让「写库、失败反馈、过期抑制、同任务串行」这四条可测。
class TaskListMoveController {
  TaskListMoveController({
    required this.repositoryOf,
    required this.currentListIdOf,
    required this.onFailure,
  });

  /// 取当前可用的任务仓储（离线/未就绪时可能为 null）。
  final TaskRepository? Function() repositoryOf;

  /// 取「此刻正在查看的清单」——反馈前要比对它有没有被切走。
  final String? Function() currentListIdOf;

  /// 失败反馈入口（页面上是 SnackBar）。
  final void Function(String message) onFailure;

  /// 同一个任务的多次落点按先后串行，后一次不会先于前一次写库。
  final Map<String, Future<void>> _chain = {};

  static const String failureMessage = '移入当前清单失败，请重试';

  /// 一次落点。返回是否真的发起过写库（同清单、没选中清单时不发起）。
  Future<bool> handleDrop(TodoTask task) async {
    final targetListId = currentListIdOf();
    if (targetListId == null || task.listId == targetListId) return false;
    final repository = repositoryOf();
    if (repository == null) {
      onFailure(failureMessage);
      return false;
    }

    final previous = _chain[task.id] ?? Future<void>.value();
    final operation = previous.then(
      (_) => repository.update(
        // 只改所属清单；时间安排沿用仓储里 `Value.absent()` 的不写语义。
        task.id,
        listId: targetListId,
        clearSectionId: true,
      ),
    );
    _chain[task.id] = operation;
    try {
      await operation;
    } catch (_) {
      // 失败不碰本地数据：Drift 里仍是原清单，已加载的任务继续显示。
      // 这条提示也只在用户还在看当初那个清单时才弹 —— 切走了就不拿旧清单的失败盖新界面。
      if (currentListIdOf() == targetListId) onFailure(failureMessage);
    } finally {
      if (_chain[task.id] == operation) _chain.remove(task.id);
    }
    return true;
  }
}
