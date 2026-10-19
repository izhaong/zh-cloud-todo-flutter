import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';
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
        home: Scaffold(
          body: QuickAddBar(onSubmit: (request) => submitted = request.input),
        ),
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

  // ── FL #344 面④：输入框样式三档（`:54`「切换输入框样式」）──

  testWidgets('collapsed：工具行收起、单行输入仍在且回车仍能建任务', (tester) async {
    SharedPreferences.setMockInitialValues({
      'todo_quick_add_input_style_v1': 'collapsed',
    });
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: QuickAddBar(onSubmit: (request) => submitted = request.input),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 工具行收起（单行的意义）：三个快捷工具一个都不剩
    expect(find.byTooltip('日期'), findsNothing, reason: 'collapsed ⇒ 工具行不显示');
    expect(find.byTooltip('优先级'), findsNothing);
    expect(find.byTooltip('标签'), findsNothing);
    // 输入框仍在
    expect(find.byType(TextField), findsOneWidget);

    // 回车仍能建任务（收起的是工具，不是能力）
    await tester.enterText(find.byType(TextField), '收起样式下建任务');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(submitted, '收起样式下建任务');
  });

  testWidgets('inline（默认）：工具行照常显示 —— 切样式不改既有体验', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(body: QuickAddBar(onSubmit: (_) {})),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byTooltip('日期'), findsOneWidget, reason: 'inline = 现状');
    expect(find.byTooltip('优先级'), findsOneWidget);
    expect(find.byTooltip('标签'), findsOneWidget);
  });

  testWidgets('mobile QuickAdd exposes fixed-device semantic identifiers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MobileQuickAddButton(onSubmit: (_) {})),
      ),
    );

    expect(find.bySemanticsIdentifier('todo_mobile_quick_add'), findsOneWidget);
    await tester.tap(find.bySemanticsIdentifier('todo_mobile_quick_add'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('todo_mobile_quick_add_title'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
      findsOneWidget,
    );

    semantics.dispose();
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

  testWidgets(
    'desktop QuickAdd exposes a stable input anchor for GUI journeys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: Scaffold(body: QuickAddBar(onSubmit: (_) {})),
        ),
      );

      expect(find.byKey(const Key('todo-quick-add-input')), findsOneWidget);
    },
  );

  testWidgets('QuickAddBar sends explicit priority and tag overrides', (
    tester,
  ) async {
    QuickAddRequest? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: QuickAddBar(
            tagOptions: const [QuickAddTagOption(id: 'focus', name: '专注')],
            onSubmit: (request) => submitted = request,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('优先级'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高优先级'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('专注'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '覆盖默认值');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted?.input, '覆盖默认值');
    expect(submitted?.priorityOverride, 3);
    expect(submitted?.tagIds, ['focus']);
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
      await tester.scrollUntilVisible(
        personalListRow,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('todo-sidebar')),
              matching: find.byType(Scrollable),
            )
            .first,
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

  testWidgets('HomeShell QuickAdd applies locally persisted capture defaults', (
    tester,
  ) async {
    const title = '继承默认优先级的任务';
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );
    await TaskCaptureDefaultsRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).save(const TaskCaptureDefaults(defaultPriority: 2));

    final quickAdd = find.descendant(
      of: find.byType(QuickAddBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(quickAdd, title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final created =
        (await fixture.database.select(fixture.database.todoTasks).get())
            .singleWhere((task) => task.title == title);
    expect(created.priority, 2);
  });

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
