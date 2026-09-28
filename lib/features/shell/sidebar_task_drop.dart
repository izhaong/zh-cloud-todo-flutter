import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》:57「拖动到清单或标签上」
/// `:59`「任务会被移动到目标清单，或自动打上相应标签。」
///
/// 落点是侧栏的清单行与标签行；拖出源沿用既有的 `Draggable<TodoTask>`
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
  SidebarTaskDropController({required this.moveTask, required this.attachTag});

  /// 换清单；实现侧负责清掉属于原清单的 `sectionId`。
  final Future<void> Function(String taskId, String listId) moveTask;

  /// 「自动打上相应标签」= 追加；实现侧负责去重（已有就不写）。
  final Future<void> Function(String taskId, String tagId) attachTag;

  final Map<String, Future<void>> _chain = <String, Future<void>>{};

  /// 清单行只在「真的换清单」时才是有效落点：落回原清单不该发写请求。
  bool acceptsList(TodoTask task, String listId) => task.listId != listId;

  Future<SidebarDropOutcome> moveToList(TodoTask task, String listId) {
    if (!acceptsList(task, listId))
      return Future.value(SidebarDropOutcome.skipped);
    // :59「移动到目标清单」只提清单，没提时间 ⇒ 时间安排一毫秒都不动。
    return _serialize(task.id, () => moveTask(task.id, listId));
  }

  Future<SidebarDropOutcome> addTagToTask(TodoTask task, String tagId) {
    return _serialize(task.id, () => attachTag(task.id, tagId));
  }

  Future<SidebarDropOutcome> _serialize(
    String taskId,
    Future<void> Function() operation,
  ) async {
    var outcome = SidebarDropOutcome.applied;
    final previous = _chain[taskId] ?? Future<void>.value();
    // 失败也要把链条续上（onError 只记结果不重抛），否则下一刀会挂在旧错误上被静默跳过。
    final current = previous
        .then((_) => operation())
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            outcome = SidebarDropOutcome.failed;
          },
        );
    _chain[taskId] = current;
    await current;
    if (_chain[taskId] == current) _chain.remove(taskId);
    return outcome;
  }
}

/// 控制器挂在 provider 上而不是每次 build 新建：串行链要活得过重绘，
/// 否则侧栏刷一次就把「同一任务串行」这件事抹平了。
final sidebarTaskDropControllerProvider = Provider<SidebarTaskDropController>((
  ref,
) {
  return SidebarTaskDropController(
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
  );
});
