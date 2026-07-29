import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('selecting task B replaces task A and keeps one selected row', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    await _tapTask(tester, TodoVisualFixture.pinnedTaskId);
    _expectSelectedTask(
      tester,
      taskId: TodoVisualFixture.pinnedTaskId,
      title: '确定今天最重要的三件事',
    );

    await _tapTask(tester, TodoVisualFixture.todayTaskId);

    expect(
      find.byKey(
        const Key('task-row-selected-${TodoVisualFixture.pinnedTaskId}'),
      ),
      findsNothing,
    );
    _expectSelectedTask(
      tester,
      taskId: TodoVisualFixture.todayTaskId,
      title: '完成 Todo 工作区视觉评审',
    );
  });

  testWidgets('selecting a task keeps the populated list visible immediately', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    final surface = find.byKey(
      const Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
    );
    await tester.tap(surface);
    await tester.pump();

    final content = find.byKey(const Key('todo-content'));
    expect(
      find.descendant(
        of: content,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
      reason:
          'selection must not replace an already loaded task list with a spinner',
    );
    expect(surface, findsOneWidget);
  });

  testWidgets('changing the current list clears task selection and detail', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    const selectedTitle = '确定今天最重要的三件事';

    await _tapTask(tester, TodoVisualFixture.pinnedTaskId);
    _expectSelectedTask(
      tester,
      taskId: TodoVisualFixture.pinnedTaskId,
      title: selectedTitle,
    );

    final personalList = find.byKey(
      const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
    );
    expect(personalList, findsOneWidget);
    await tester.ensureVisible(personalList);
    await tester.tap(personalList);
    await tester.pumpAndSettle();

    _expectNoTaskSelected(tester, previousTitle: selectedTitle);
    expect(
      find.text('规划周末骑行路线'),
      findsOneWidget,
      reason: 'the workspace must display the newly selected list',
    );
  });

  testWidgets('deleting the selected task invalidates selection and detail', (
    tester,
  ) async {
    final fixture = await _pumpWorkspace(tester);
    const selectedTitle = '确定今天最重要的三件事';

    await _tapTask(tester, TodoVisualFixture.pinnedTaskId);
    _expectSelectedTask(
      tester,
      taskId: TodoVisualFixture.pinnedTaskId,
      title: selectedTitle,
    );

    final repository = fixture.container.read(taskRepositoryProvider)!;
    await repository.delete(TodoVisualFixture.pinnedTaskId);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
      ),
      findsNothing,
    );
    _expectNoTaskSelected(tester, previousTitle: selectedTitle);
  });

  testWidgets(
    'filtering out the selected task invalidates selection and detail',
    (tester) async {
      await _pumpWorkspace(tester);
      const selectedTitle = '确定今天最重要的三件事';

      await _tapTask(tester, TodoVisualFixture.pinnedTaskId);
      _expectSelectedTask(
        tester,
        taskId: TodoVisualFixture.pinnedTaskId,
        title: selectedTitle,
      );

      await tester.tap(find.byKey(const Key('todo-filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '优先级'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('优先级 1').last);
      await tester.pumpAndSettle();

      // Close the filter sheet so assertions inspect the workspace route.
      await tester.tapAt(const Offset(1000, 100));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
        ),
        findsNothing,
        reason: 'the priority-3 task must be absent under priority-1 filter',
      );
      _expectNoTaskSelected(tester, previousTitle: selectedTitle);
    },
  );

  testWidgets('advanced keyword filter narrows workspace tasks locally', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    await tester.tap(find.byKey(const Key('todo-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-filter-advanced')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-filter-keyword')),
      '设计反馈',
    );
    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1000, 100));
    await tester.pumpAndSettle();

    expect(find.text('回复设计反馈并确认下一步'), findsOneWidget);
    expect(find.text('确定今天最重要的三件事'), findsNothing);
  });

  testWidgets('advanced date interval narrows workspace tasks locally', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    await tester.tap(find.byKey(const Key('todo-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-filter-advanced')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-filter-due-at-from')),
      '2026-07-12',
    );
    await tester.enterText(
      find.byKey(const Key('task-filter-due-at-to')),
      '2026-07-12',
    );
    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1000, 100));
    await tester.pumpAndSettle();

    expect(find.text('提交本月报销单'), findsOneWidget);
    expect(find.text('给家人打电话'), findsOneWidget);
    expect(find.text('确定今天最重要的三件事'), findsNothing);
  });

  testWidgets('repository update preserves selection in stable smart order', (
    tester,
  ) async {
    final fixture = await _pumpWorkspace(tester);
    const taskId = TodoVisualFixture.secondaryTodayTaskId;
    const selectedTitle = '回复设计反馈并确认下一步';

    await _tapTask(tester, taskId);
    _expectSelectedTask(tester, taskId: taskId, title: selectedTitle);

    final surface = find.byKey(const Key('task-row-surface-$taskId'));
    final beforeTop = tester.getTopLeft(surface).dy;
    final repository = fixture.container.read(taskRepositoryProvider)!;
    await repository.update(taskId, description: '同步后更新排序时间');
    await tester.pumpAndSettle();

    final afterTop = tester.getTopLeft(surface).dy;
    expect(
      afterTop,
      beforeTop,
      reason: 'smart order is pinned, manual sort order, then task ID',
    );
    _expectSelectedTask(tester, taskId: taskId, title: selectedTitle);
  });

  testWidgets('completing the selected incomplete task clears its detail', (
    tester,
  ) async {
    final fixture = await _pumpWorkspace(tester);
    const taskId = TodoVisualFixture.todayTaskId;
    const selectedTitle = '完成 Todo 工作区视觉评审';

    await _tapTask(tester, taskId);
    _expectSelectedTask(tester, taskId: taskId, title: selectedTitle);

    await fixture.container
        .read(taskRepositoryProvider)!
        .toggleComplete(taskId);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('task-row-surface-$taskId')),
      findsOneWidget,
      reason: 'the task may remain visible in the completed group',
    );
    _expectNoTaskSelected(tester, previousTitle: selectedTitle);
  });

  testWidgets(
    'moving the selected task out of the current list clears detail',
    (tester) async {
      final fixture = await _pumpWorkspace(tester);
      const taskId = TodoVisualFixture.todayTaskId;
      const selectedTitle = '完成 Todo 工作区视觉评审';

      await _tapTask(tester, taskId);
      _expectSelectedTask(tester, taskId: taskId, title: selectedTitle);

      await fixture.container
          .read(taskRepositoryProvider)!
          .update(taskId, listId: TodoVisualFixture.personalListId);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('task-row-surface-$taskId')), findsNothing);
      _expectNoTaskSelected(tester, previousTitle: selectedTitle);
    },
  );

  testWidgets('selecting an already completed task keeps its detail valid', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    const taskId = 'visual-task-completed';
    const selectedTitle = '清理收集箱中的旧任务';

    await _tapTask(tester, taskId);
    await tester.pumpAndSettle();

    _expectSelectedTask(tester, taskId: taskId, title: selectedTitle);
  });
}

Future<TodoVisualFixture> _pumpWorkspace(WidgetTester tester) {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const HomeShell(),
  );
}

Future<void> _tapTask(WidgetTester tester, String taskId) async {
  final surface = find.byKey(Key('task-row-surface-$taskId'));
  expect(surface, findsOneWidget);
  await tester.ensureVisible(surface);
  await tester.tap(surface);
  await tester.pumpAndSettle();
}

void _expectSelectedTask(
  WidgetTester tester, {
  required String taskId,
  required String title,
}) {
  expect(find.byKey(Key('task-row-selected-$taskId')), findsOneWidget);
  expect(
    _selectedTaskRows(),
    findsOneWidget,
    reason: 'a workspace may expose at most one selected task row',
  );

  final detail = find.byKey(const Key('todo-detail'));
  expect(detail, findsOneWidget);
  expect(
    find.descendant(of: detail, matching: find.text(title)),
    findsOneWidget,
    reason: 'the fixed detail region must render the selected real task',
  );
}

void _expectNoTaskSelected(
  WidgetTester tester, {
  required String previousTitle,
}) {
  expect(_selectedTaskRows(), findsNothing);
  final detail = find.byKey(const Key('todo-detail'));
  expect(detail, findsOneWidget);
  expect(
    find.descendant(of: detail, matching: find.text(previousTitle)),
    findsNothing,
    reason: 'the detail region must not retain an invalid selection',
  );
}

Finder _selectedTaskRows() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('task-row-selected-');
  });
}
