import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/collaboration/task_assign_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 团队看板三面里 `:175`（右键任务 →「分配给」）与 `:188`/`:198`（评论、任务动态）的判定与入口测试。
///
/// 判据口径：嘀嗒《02-看板视图：分类管理任务》原文 ——
/// `:175`「在看板视图右键任务，选择「分配给」即可。」
/// `:188`「点击任务，点击弹窗里的「评论」…」
/// `:198`「点击任务，点击弹窗右下角「...」-「任务动态」。」
void main() {
  testWidgets('看板卡片右键出现「分配给」，且左键仍然是打开详情', (tester) async {
    await pumpKanbanOnInbox(tester);

    await rightClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    expect(find.text('分配给'), findsOneWidget);
    // 不能把左键吃掉：卡片左键还是进详情。
    await tester.tap(find.text('分配给'));
    await tester.pumpAndSettle();
    await leftClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    expect(find.text('检查事项'), findsWidgets);
  });

  testWidgets('任务未同步时点「分配给」：提示可见，且任务一个字节都没改', (tester) async {
    final fixture = await pumpKanbanOnInbox(tester);
    final before = await taskRow(
      fixture.database,
      TodoVisualFixture.secondaryTodayTaskId,
    );
    final queuedBefore = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();

    await rightClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    await tester.tap(find.text('分配给'));
    await tester.pumpAndSettle();

    expect(find.text('任务尚未同步，无法指派'), findsOneWidget);
    final after = await taskRow(
      fixture.database,
      TodoVisualFixture.secondaryTodayTaskId,
    );
    // 整行比对，不是挑三个字段看：任务表任何一列被动过都该红。
    expect(after.toJson(), before.toJson());
    // 发件箱行数一丁点都没涨（基线是 fixture 自己种下的，不假设它是 0）。
    final queuedAfter = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(queuedAfter.length, queuedBefore.length);
  });

  testWidgets('任务与清单都已同步时，「分配给」真的打开指派页（不是只弹个菜单）', (tester) async {
    // 用「工作」清单：它在 todoLists 里是一行真实的清单（收集箱的行由 sync 建立，见 #318 的撤证）。
    const workTaskId = 'visual-task-work-list';
    final fixture = await pumpKanbanOnInbox(
      tester,
      listId: TodoVisualFixture.workListId,
    );
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((row) => row.id.equals(workTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(4401)));
    final listRows =
        await (fixture.database.update(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .write(const TodoListsCompanion(serverId: Value(5501)));
    expect(listRows, 1, reason: '任务所属清单在库里查不到行，用例前提就不成立');
    await tester.pumpAndSettle();

    await rightClickCard(tester, workTaskId);
    await tester.tap(find.text('分配给'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskAssignPage), findsOneWidget);
    expect(find.text('任务尚未同步，无法指派'), findsNothing);
    expect(find.text('清单尚未同步，无法选择执行人'), findsNothing);
  });

  testWidgets('清单自己还没同步时不 push 指派页，而是给那一句可见提示', (tester) async {
    // 「本地建了清单、服务端还没回 serverId」是生产里真会发生的一种：
    // 用工作清单，只给任务补 serverId，清单行的 serverId 保持为空。
    const workTaskId = 'visual-task-work-list';
    final fixture = await pumpKanbanOnInbox(
      tester,
      listId: TodoVisualFixture.workListId,
    );
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((row) => row.id.equals(workTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(4401)));
    await tester.pumpAndSettle();

    await rightClickCard(tester, workTaskId);
    await tester.tap(find.text('分配给'));
    await tester.pumpAndSettle();

    expect(find.text('清单尚未同步，无法选择执行人'), findsOneWidget);
    expect(find.byType(TaskAssignPage), findsNothing);
  });

  testWidgets('判定钉住 :188 —— 从看板卡片点开的详情里有「评论」入口', (tester) async {
    await pumpKanbanOnInbox(tester);

    await leftClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);

    final collaboration = find.byTooltip('协作（指派/评论/成员）');
    expect(collaboration, findsOneWidget);
    await tester.tap(collaboration);
    await tester.pumpAndSettle();
    expect(find.text('查看/添加评论'), findsOneWidget);
    expect(find.text('指派执行人'), findsOneWidget);
  });

  testWidgets('判定钉住 :198（未同步那一支）—— 详情里有「任务动态」这一节并给可见说明', (tester) async {
    await pumpKanbanOnInbox(tester);

    await leftClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    await scrollDetailTo(tester, '任务动态');

    expect(find.text('任务动态'), findsOneWidget);
    expect(find.text('任务同步后可查看动态'), findsOneWidget);
  });

  testWidgets('判定钉住 :198（已同步那一支）—— 任务 serverId 到位才真的挂上动态区', (tester) async {
    final fixture = await pumpKanbanOnInbox(tester);
    await (fixture.database.update(fixture.database.todoTasks)..where(
          (row) => row.id.equals(TodoVisualFixture.secondaryTodayTaskId),
        ))
        .write(const TodoTasksCompanion(serverId: Value(4401)));
    await tester.pumpAndSettle();

    await leftClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    final activity = find.byKey(
      const ValueKey(
        'task-activities-${TodoVisualFixture.secondaryTodayTaskId}',
      ),
    );
    await scrollDetailTo(tester, '任务动态', target: activity);

    // 这一支不再走"同步后可查看"的说明，而是真的构建 _ActivitySection（私有类，按它自己的 key 认）。
    expect(find.text('任务同步后可查看动态'), findsNothing);
    expect(activity, findsOneWidget);
  });

  testWidgets('右键菜单在 320px + 1.3 倍字号下不溢出，且卡片自己的读屏语义还在', (tester) async {
    await pumpKanbanOnInbox(tester, narrowWithLargeText: true);
    await rightClickCard(tester, TodoVisualFixture.secondaryTodayTaskId);
    expect(tester.takeException(), isNull);
    expect(find.text('分配给'), findsOneWidget);
    // 读屏：这一项要能被单独读到，而不是只有一串视觉文字。
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.text('分配给')).label, contains('分配给'));
    handle.dispose();
  });
}

Future<TodoVisualFixture> pumpKanbanOnInbox(
  WidgetTester tester, {
  bool narrowWithLargeText = false,
  String listId = TodoVisualFixture.inboxListId,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
  );
  addTearDown(fixture.dispose);
  tester.view.physicalSize = narrowWithLargeText
      ? const Size(320, 720)
      : TodoVisualViewports.wide;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        // 挂在 MaterialApp.builder 上而不是 home 上：右键菜单是 root Navigator
        // 的 Overlay 路由，只有这层能同时覆盖工作区与弹层。
        builder: narrowWithLargeText
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child ?? const SizedBox.shrink(),
              )
            : null,
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: TasksByListPage(
            initialListId: listId,
            lockedListId: true,
            hideAppBar: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(find.byKey(const Key('todo-view-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(TaskViewMode.kanban.label).last);
  await tester.pumpAndSettle();
  return fixture;
}

Future<TodoTask> taskRow(AppDatabase db, String id) =>
    (db.select(db.todoTasks)..where((row) => row.id.equals(id))).getSingle();

Future<void> revealCard(WidgetTester tester, String taskId) async {
  final columnScrollable = find
      .descendant(
        of: find.byKey(const ValueKey('col-todo')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(Key('kanban-task-$taskId')),
    100,
    scrollable: columnScrollable,
  );
  await tester.pumpAndSettle();
}

Future<void> rightClickCard(WidgetTester tester, String taskId) async {
  // 先滚到卡片再断言存在：窄屏 + 大字号下列表是懒建的，没进视口的条目根本没 build。
  await revealCard(tester, taskId);
  final card = find.byKey(Key('kanban-task-$taskId'));
  expect(card, findsOneWidget);
  await tester.tap(
    card,
    buttons: kSecondaryButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

Future<void> leftClickCard(WidgetTester tester, String taskId) async {
  final card = find.byKey(Key('kanban-task-$taskId'));
  await revealCard(tester, taskId);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> scrollDetailTo(
  WidgetTester tester,
  String text, {
  Finder? target,
}) async {
  final finder = target ?? find.text(text);
  if (tester.any(finder)) return;
  final detail = find.byType(TaskDetailPage);
  expect(detail, findsOneWidget, reason: '详情没开，滚它没有意义');
  final scrollable = find
      .descendant(of: detail, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
}
