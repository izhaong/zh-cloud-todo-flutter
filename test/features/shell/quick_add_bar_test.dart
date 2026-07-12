import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/task_view_mode_tabs.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('QuickAddBar submits text and exposes shortcut buttons', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(body: QuickAddBar(onSubmit: (text) => submitted = text)),
      ),
    );

    expect(find.byTooltip('日期'), findsOneWidget);
    expect(find.byTooltip('优先级'), findsOneWidget);
    expect(find.byTooltip('标签'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '写周报');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted, '写周报');
    expect(find.text('写周报'), findsNothing);
  });

  testWidgets('desktop QuickAdd occupies the fixed 44px workspace row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(body: QuickAddBar(onSubmit: (_) {})),
      ),
    );

    expect(tester.getSize(find.byType(QuickAddBar)).height, 44);
  });

  testWidgets('desktop workspace has one QuickAdd and no duplicate controls', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    expect(find.byType(QuickAddBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(TaskViewModeTabs), findsNothing);
  });

  testWidgets(
    'HomeShell QuickAdd keeps the selected list and desktop workspace after Enter',
    (tester) async {
      const title = '整理 T015 集成测试证据';
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      final personalListRow = find.byKey(
        const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
      );
      await tester.tap(personalListRow);
      await tester.pumpAndSettle();

      expect(find.text('规划周末骑行路线'), findsOneWidget);
      expect(find.text('完成 Todo 工作区视觉评审'), findsNothing);

      final regionFinders = <Finder>[
        find.byKey(const Key('todo-rail')),
        find.byKey(const Key('todo-sidebar')),
        find.byKey(const Key('todo-content')),
        find.byKey(const Key('todo-detail')),
      ];
      final layoutBefore = regionFinders.map(tester.getRect).toList();
      final quickAdd = find.byType(QuickAddBar);
      final input = find.descendant(
        of: quickAdd,
        matching: find.byType(TextField),
      );

      await tester.enterText(input, title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final tasks = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      final created = tasks.singleWhere((task) => task.title == title);
      expect(created.listId, TodoVisualFixture.personalListId);
      expect(tester.widget<TextField>(input).controller?.text, isEmpty);
      expect(find.text(title), findsOneWidget);
      expect(find.text('规划周末骑行路线'), findsOneWidget);
      expect(find.text('完成 Todo 工作区视觉评审'), findsNothing);
      expect(regionFinders.map(tester.getRect).toList(), layoutBefore);
      expect(find.byType(QuickAddBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(TaskViewModeTabs), findsNothing);
    },
  );

  testWidgets(
    'HomeShell QuickAdd batches nonblank lines, resolves dates, and can undo',
    (tester) async {
      const input = '明天 8点复盘 B1 证据\n\n整理验收清单';
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );
      final quickAdd = find.descendant(
        of: find.byType(QuickAddBar),
        matching: find.byType(TextField),
      );

      await tester.enterText(quickAdd, input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final created =
          (await fixture.database.select(fixture.database.todoTasks).get())
              .where(
                (task) =>
                    task.title == '明天 8点复盘 B1 证据' || task.title == '整理验收清单',
              )
              .toList();
      expect(created, hasLength(2));
      expect(
        created.singleWhere((task) => task.title == '明天 8点复盘 B1 证据').dueAt,
        isNotNull,
      );
      expect(find.text('已创建 2 项任务'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);

      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      final afterUndo =
          (await fixture.database.select(fixture.database.todoTasks).get())
              .where(
                (task) =>
                    task.title == '明天 8点复盘 B1 证据' || task.title == '整理验收清单',
              );
      expect(afterUndo, isEmpty);
    },
  );

  testWidgets(
    'today add select complete flow uses one target action per step and stays in workspace',
    (tester) async {
      const addedTitle = '今天核心流程点击预算验收';
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      await tester.tap(find.byKey(const Key('todo-sidebar-row-today')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('todo-task-workspace-header')),
          matching: find.text('今天'),
        ),
        findsOneWidget,
      );

      final quickAdd = find.descendant(
        of: find.byType(QuickAddBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(quickAdd, addedTitle);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(quickAdd).controller?.text, isEmpty);
      final tasks = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      expect(tasks.where((task) => task.title == addedTitle), hasLength(1));

      const taskId = TodoVisualFixture.pinnedTaskId;
      final taskSurface = find.byKey(const Key('task-row-surface-$taskId'));
      await tester.tap(taskSurface);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('task-row-selected-$taskId')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('todo-detail')),
          matching: find.text('确定今天最重要的三件事'),
        ),
        findsOneWidget,
      );

      final completion = find.descendant(
        of: taskSurface,
        matching: find.byType(AppCheckbox),
      );
      expect(completion.hitTestable(), findsOneWidget);
      await tester.tap(completion);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('task-row-selected-$taskId')), findsNothing);
      expect(find.byKey(const Key('todo-content')), findsOneWidget);
      expect(find.byKey(const Key('todo-detail')), findsOneWidget);
      expect(find.byType(QuickAddBar), findsOneWidget);
    },
  );
}
