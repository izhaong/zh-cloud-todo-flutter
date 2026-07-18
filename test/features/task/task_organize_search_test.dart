import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_search_page.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets(
    'global search reads task, list and tag results from local query repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const TaskSearchPage(),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('global-task-search')), '设计');
      await tester.pumpAndSettle();

      expect(find.text('任务 · 回复设计反馈并确认下一步'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('global-task-search')), '工作');
      await tester.pumpAndSettle();
      expect(find.text('清单 · 工作'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('global-task-search')), '专注');
      await tester.pumpAndSettle();
      expect(find.text('标签 · 专注'), findsOneWidget);
    },
  );

  testWidgets('searching a list opens that local list in the workspace', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('global-task-search')), '工作');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('global-search-result-list:visual-list-work')),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认下周发布窗口'), findsOneWidget);
    expect(find.text('完成 Todo 工作区视觉评审'), findsNothing);
  });

  testWidgets('searching a tag opens that local tag focused', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('global-task-search')), '专注');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('global-search-result-tag:visual-tag-focus')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tag-search-result-visual-tag-focus')),
      findsOneWidget,
    );
    expect(find.text('搜索定位的标签'), findsOneWidget);
  });

  testWidgets('searching a task opens that local task detail', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('global-task-search')), '设计反馈');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('global-search-result-task:visual-task-today-secondary'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskSearchPage), findsNothing);
    expect(find.text('回复设计反馈并确认下一步'), findsOneWidget);
  });

  testWidgets('wide workspace opens local search with control K', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    expect(find.byType(TaskSearchPage), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(TaskSearchPage), findsOneWidget);
  });

  testWidgets('workspace sort selection persists an isolated view preference', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标题'));
    await tester.pumpAndSettle();

    final preference = await fixture.database
        .select(fixture.database.todoViewPreferences)
        .getSingle();
    expect(preference.sourceType, 'TASK_SORT');
    expect(preference.sourceKey, 'inbox');
    expect(preference.valueJson, contains('title'));
    final change = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .getSingle();
    expect(change.entity, 'view_preference');
  });

  testWidgets(
    'batch completion reports per-task results from the local use-case',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-batch-edit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
      );
      await tester.tap(
        find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-complete')));
      await tester.pumpAndSettle();

      expect(find.text('已完成 2 项；失败 0 项'), findsOneWidget);
      final tasks = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      expect(
        tasks.where((task) => task.completed).map((task) => task.id),
        containsAll([
          TodoVisualFixture.pinnedTaskId,
          TodoVisualFixture.todayTaskId,
        ]),
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(changes.where((change) => change.entity == 'task'), hasLength(2));
    },
  );

  testWidgets(
    'batch priority action updates selected tasks through the local use-case',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-batch-edit')));
      await tester.pumpAndSettle();
      for (final taskId in [
        TodoVisualFixture.pinnedTaskId,
        TodoVisualFixture.todayTaskId,
      ]) {
        await tester.tap(find.byKey(Key('task-batch-select-$taskId')));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为高优先级'));
      await tester.pumpAndSettle();

      expect(find.text('已更新 2 项；失败 0 项'), findsOneWidget);
      final tasks = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      expect(
        tasks
            .where(
              (task) =>
                  task.id == TodoVisualFixture.pinnedTaskId ||
                  task.id == TodoVisualFixture.todayTaskId,
            )
            .map((task) => task.priority),
        everyElement(3),
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(changes.where((change) => change.entity == 'task'), hasLength(2));
    },
  );

  testWidgets(
    'batch pin action updates selected tasks through the local use-case',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-batch-edit')));
      await tester.pumpAndSettle();
      for (final taskId in [
        TodoVisualFixture.todayTaskId,
        TodoVisualFixture.secondaryTodayTaskId,
      ]) {
        await tester.tap(find.byKey(Key('task-batch-select-$taskId')));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('置顶所选'));
      await tester.pumpAndSettle();

      expect(find.text('已更新 2 项；失败 0 项'), findsOneWidget);
      final tasks = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      expect(
        tasks
            .where(
              (task) =>
                  task.id == TodoVisualFixture.todayTaskId ||
                  task.id == TodoVisualFixture.secondaryTodayTaskId,
            )
            .map((task) => task.isPinned),
        everyElement(isTrue),
      );
    },
  );

  testWidgets(
    'batch inbox and clear-tag actions write through the local use-case',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-batch-edit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          Key('task-batch-select-${TodoVisualFixture.metadataTaskId}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuButton>(find.byKey(const Key('todo-batch-more')))
            .enabled,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-action-moveToInbox')));
      await tester.pumpAndSettle();

      var task =
          await (fixture.database.select(fixture.database.todoTasks)..where(
                (row) => row.id.equals(TodoVisualFixture.metadataTaskId),
              ))
              .getSingle();
      expect(task.listId, TodoVisualFixture.inboxListId);

      await tester.tap(find.byKey(const Key('todo-batch-edit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          Key('task-batch-select-${TodoVisualFixture.metadataTaskId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-action-clearTags')));
      await tester.pumpAndSettle();

      final tagRows =
          await (fixture.database.select(fixture.database.todoTaskTags)..where(
                (row) => row.taskId.equals(TodoVisualFixture.metadataTaskId),
              ))
              .get();
      expect(tagRows, isEmpty);
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        changes.where((change) => change.entity == 'task_tag'),
        hasLength(1),
      );
    },
  );

  testWidgets('batch move-to-list selects a local destination list', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.metadataTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-moveToList')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('todo-batch-list-${TodoVisualFixture.workListId}')),
    );
    await tester.pumpAndSettle();

    final task =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();
    expect(task.listId, TodoVisualFixture.workListId);
  });

  testWidgets('batch clear-due action writes through the local use-case', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-clearDueAt')));
    await tester.pumpAndSettle();

    final task =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.todayTaskId)))
            .getSingle();
    expect(task.dueAt, isNull);
    final changes = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(changes.where((change) => change.entity == 'task'), hasLength(1));
  });

  testWidgets('batch set-tags selects local tags through the use-case', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.metadataTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-setTags')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('todo-batch-tag-${TodoVisualFixture.reviewTagId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-apply-tags')));
    await tester.pumpAndSettle();

    final tagRows =
        await (fixture.database.select(fixture.database.todoTaskTags)..where(
              (row) => row.taskId.equals(TodoVisualFixture.metadataTaskId),
            ))
            .get();
    expect(tagRows.map((row) => row.tagId), [TodoVisualFixture.reviewTagId]);
  });

  testWidgets('batch set-due-date selects a local calendar date', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-setDueAt')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final task =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.todayTaskId)))
            .getSingle();
    expect(task.dueAt, DateTime(2026, 7, 20));
  });
}
