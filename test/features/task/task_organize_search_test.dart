import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_search_page.dart';

import '../../support/todo_visual_fixture.dart';

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
}
