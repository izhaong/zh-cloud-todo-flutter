import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/command_palette.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_search_page.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

Future<void> enterBatchEdit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-sort-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('todo-batch-edit')));
  await tester.pumpAndSettle();
}

Future<void> modifiedTaskTap(
  WidgetTester tester, {
  required String taskId,
  required LogicalKeyboardKey modifier,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.tap(find.byKey(Key('task-row-surface-$taskId')));
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

/// 任务范围组合筛选所需的本地清单、标签与任务。
Future<void> seedTaskSearchFilterData(TodoVisualFixture fixture) async {
  final now = fixture.fixedNow;
  await fixture.database.batch((batch) {
    batch.insert(
      fixture.database.todoLists,
      TodoListsCompanion.insert(
        id: 'search-filter-list',
        name: '筛选搜索清单',
        updatedAt: now,
        createdAt: now,
      ),
    );
    batch.insert(
      fixture.database.todoTags,
      TodoTagsCompanion.insert(
        id: 'search-filter-tag',
        name: '筛选搜索标签',
        updatedAt: now,
        createdAt: now,
      ),
    );
    batch.insertAll(fixture.database.todoTasks, [
      TodoTasksCompanion.insert(
        id: 'search-filter-match',
        listId: 'search-filter-list',
        title: '筛选搜索目标',
        priority: const Value(3),
        dueAt: Value(DateTime(2026, 7, 11, 10)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTasksCompanion.insert(
        id: 'search-filter-other',
        listId: 'search-filter-list',
        title: '筛选搜索其他任务',
        priority: const Value(1),
        updatedAt: now,
        createdAt: now,
      ),
    ]);
    batch.insertAll(fixture.database.todoTaskTags, [
      TodoTaskTagsCompanion.insert(
        taskId: 'search-filter-match',
        tagId: 'search-filter-tag',
      ),
      TodoTaskTagsCompanion.insert(
        taskId: 'search-filter-match',
        tagId: TodoVisualFixture.focusTagId,
      ),
      TodoTaskTagsCompanion.insert(
        taskId: 'search-filter-other',
        tagId: 'search-filter-tag',
      ),
    ]);
  });
}

Future<void> applyTaskSearchFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('task-search-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('task-search-filter-list')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('筛选搜索清单').last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('task-search-filter-tag-search-filter-tag')),
  );
  await tester.tap(
    find.byKey(
      const Key('task-search-filter-tag-${TodoVisualFixture.focusTagId}'),
    ),
  );
  await tester.tap(find.byKey(const Key('task-search-filter-priority-3')));
  await tester.tap(find.byKey(const Key('task-search-filter-apply')));
  await tester.pumpAndSettle();
}

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

  testWidgets('search scopes task results and applies local combined filters', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await seedTaskSearchFilterData(fixture);

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
    await tester.enterText(find.byKey(const Key('global-task-search')), '筛选搜索');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-search-scope-all')), findsOneWidget);
    expect(find.byKey(const Key('task-search-scope-task')), findsOneWidget);
    expect(find.byKey(const Key('task-search-scope-list')), findsOneWidget);
    expect(find.byKey(const Key('task-search-scope-tag')), findsOneWidget);
    expect(find.text('任务 · 筛选搜索目标'), findsOneWidget);
    expect(find.text('清单 · 筛选搜索清单'), findsOneWidget);
    expect(find.text('标签 · 筛选搜索标签'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-scope-task')));
    await tester.pumpAndSettle();
    expect(find.text('任务 · 筛选搜索目标'), findsOneWidget);
    expect(find.text('清单 · 筛选搜索清单'), findsNothing);
    expect(find.text('标签 · 筛选搜索标签'), findsNothing);

    await applyTaskSearchFilter(tester);
    await tester.pumpAndSettle();

    expect(find.text('任务 · 筛选搜索目标'), findsOneWidget);
    expect(find.text('任务 · 筛选搜索其他任务'), findsNothing);
    expect(find.byKey(const Key('task-search-filter-clear')), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-scope-all')));
    await tester.pumpAndSettle();
    expect(find.text('清单 · 筛选搜索清单'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-search-scope-task')));
    await tester.pumpAndSettle();
    expect(find.text('任务 · 筛选搜索目标'), findsOneWidget);
    expect(find.text('任务 · 筛选搜索其他任务'), findsNothing);

    await tester.tap(find.byKey(const Key('task-search-filter-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-search-scope-task')), findsOneWidget);
    expect(find.text('任务 · 筛选搜索目标'), findsOneWidget);
    expect(find.text('任务 · 筛选搜索其他任务'), findsOneWidget);
  });

  testWidgets('查询链路出现重复行时分页游标不回收', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    final requests = <TaskSearchPageRequest>[];
    const rows = [
      TaskSearchResult(
        type: TaskSearchResultType.task,
        id: 'dup-0',
        title: '重复行任务甲',
      ),
      TaskSearchResult(
        type: TaskSearchResultType.task,
        id: 'dup-0',
        title: '重复行任务甲',
      ),
      TaskSearchResult(
        type: TaskSearchResultType.task,
        id: 'tail-row',
        title: '重复行任务乙',
      ),
    ];

    Future<TaskSearchPageResult> search(TaskSearchPageRequest request) async {
      requests.add(request);
      final start = request.offset.clamp(0, rows.length);
      final end = (start + 1).clamp(start, rows.length);
      return TaskSearchPageResult(
        total: rows.length,
        results: rows.sublist(start, end),
      );
    }

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: TaskSearchPage(searchPage: search),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('global-task-search')),
      '重复行关键词',
    );
    await tester.pumpAndSettle();

    expect(find.text('任务 · 重复行任务甲'), findsOneWidget);
    expect(find.text('任务 · 重复行任务乙'), findsNothing);
    expect(find.bySemanticsLabel('加载更多 2 条搜索结果'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-load-more')));
    await tester.pumpAndSettle();
    // 第二页整页都是重复行：展示条数没变，但游标必须已经消费掉这一页，
    // 否则「加载更多」会停在同一个 offset 上永远点不出新结果。
    expect(requests.map((request) => request.offset), [0, 1]);
    expect(find.bySemanticsLabel('加载更多 1 条搜索结果'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '加载更多 1 条'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('任务 · 重复行任务乙'), findsOneWidget);
    expect(find.byKey(const Key('task-search-load-more')), findsNothing);
    expect(requests.map((request) => request.offset), [0, 1, 2]);
    semantics.dispose();
  });

  testWidgets('加载更多失败时保留已加载结果并可重试同一页', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    final requests = <TaskSearchPageRequest>[];
    const rows = [
      TaskSearchResult(
        type: TaskSearchResultType.task,
        id: 'keep-1',
        title: '失败重试任务甲',
      ),
      TaskSearchResult(
        type: TaskSearchResultType.task,
        id: 'keep-2',
        title: '失败重试任务乙',
      ),
    ];
    var failNext = false;

    Future<TaskSearchPageResult> search(TaskSearchPageRequest request) async {
      requests.add(request);
      final start = request.offset.clamp(0, rows.length);
      if (start > 0 && failNext) {
        failNext = false;
        throw StateError('本地查询失败');
      }
      final end = (start + 1).clamp(start, rows.length);
      return TaskSearchPageResult(
        total: rows.length,
        results: rows.sublist(start, end),
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: TaskSearchPage(searchPage: search),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('global-task-search')),
      '失败重试关键词',
    );
    await tester.pumpAndSettle();
    expect(find.text('任务 · 失败重试任务甲'), findsOneWidget);
    expect(find.text('任务 · 失败重试任务乙'), findsNothing);

    failNext = true;
    await tester.tap(find.byKey(const Key('task-search-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('加载更多失败，点击重试'), findsOneWidget);
    expect(find.text('任务 · 失败重试任务甲'), findsOneWidget);

    await tester.tap(find.text('加载更多失败，点击重试'));
    await tester.pumpAndSettle();
    expect(find.text('任务 · 失败重试任务乙'), findsOneWidget);
    expect(find.byKey(const Key('task-search-load-more')), findsNothing);
    expect(requests.map((request) => request.offset), [0, 1, 1]);
  });

  testWidgets('320px 下范围切换、筛选与清除保持可读语义且无溢出', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await seedTaskSearchFilterData(fixture);
    final originalSize = tester.view.physicalSize;
    final originalDpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
    });

    final semantics = tester.ensureSemantics();
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
    await tester.enterText(find.byKey(const Key('global-task-search')), '筛选搜索');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('搜索范围'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-scope-task')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('筛选任务'), findsOneWidget);

    await applyTaskSearchFilter(tester);
    expect(find.bySemanticsLabel('筛选任务，已选 4 项'), findsOneWidget);
    expect(find.byKey(const Key('task-search-filter-clear')), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-search-filter-clear')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('筛选任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('search appends stable pages and isolates stale requests', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    final originalSize = tester.view.physicalSize;
    final originalDpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
    });
    final oldRequest = Completer<TaskSearchPageResult>();
    final requests = <TaskSearchPageRequest>[];
    Future<TaskSearchPageResult> search(TaskSearchPageRequest request) {
      requests.add(request);
      if (request.keyword == '旧关键词') return oldRequest.future;
      if (request.keyword == '新关键词') {
        return Future.value(
          const TaskSearchPageResult(
            total: 1,
            results: [
              TaskSearchResult(
                type: TaskSearchResultType.task,
                id: 'new-result',
                title: '新查询结果',
              ),
            ],
          ),
        );
      }
      final start = request.offset;
      final end = start + 50 > 51 ? 51 : start + 50;
      return Future.value(
        TaskSearchPageResult(
          total: 51,
          results: [
            for (var index = start; index < end; index++)
              TaskSearchResult(
                type: TaskSearchResultType.task,
                id: 'page-$index',
                title: '分页任务 ${index.toString().padLeft(2, '0')}',
              ),
          ],
        ),
      );
    }

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: TaskSearchPage(searchPage: search),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('global-task-search')),
      '分页关键词',
    );
    await tester.pumpAndSettle();

    expect(find.text('任务 · 分页任务 00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-search-load-more')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.bySemanticsLabel('加载更多 1 条搜索结果'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-search-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('任务 · 分页任务 50'), findsOneWidget);
    expect(requests.map((request) => request.offset), [0, 50]);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('global-task-search')), '旧关键词');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('global-task-search')), '新关键词');
    await tester.pumpAndSettle();
    expect(find.text('任务 · 新查询结果'), findsOneWidget);

    oldRequest.complete(
      const TaskSearchPageResult(
        total: 1,
        results: [
          TaskSearchResult(
            type: TaskSearchResultType.task,
            id: 'old-result',
            title: '旧查询结果',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('任务 · 新查询结果'), findsOneWidget);
    expect(find.text('任务 · 旧查询结果'), findsNothing);
    semantics.dispose();
  });

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

  testWidgets(
    'wide workspace reaches local search through the command palette',
    (tester) async {
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

      // 嘀嗒《08-桌面快捷键.md》:9 把 ⌘K 定给指令菜单 ⇒ 搜索不再是键位的直接落点，
      // 而是面板里的一条命令。这里量的是"换语义没把搜索弄丢"。
      expect(find.byType(CommandPalette), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('todo-command-palette-field')),
        '全局搜索',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('todo-command-palette-item-全局搜索')));
      await tester.pumpAndSettle();

      expect(find.byType(TaskSearchPage), findsOneWidget);
    },
  );

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
          // fixture 的任务都在收集箱，且断言要的正是收集箱那把键
          // （`'inbox'` 是真实清单 id，生产里由 `home_shell._effectiveListId`
          // 对 `SmartList.inbox` 显式给出）。不传 `initialListId` 就成了
          // 「无清单上下文」，那条路上正确的键是 `'no-list'`（FL #619 后半）。
          home: const Scaffold(
            body: TasksByListPage(hideAppBar: true, initialListId: 'inbox'),
          ),
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
    'advanced filter selects a cached assignee and narrows the workspace',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((row) => row.id.equals(TodoVisualFixture.pinnedTaskId))).write(
        const TodoTasksCompanion(
          assigneeUserId: Value(101),
          assigneeUserName: Value('小周'),
        ),
      );
      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((row) => row.id.equals(TodoVisualFixture.todayTaskId))).write(
        const TodoTasksCompanion(
          assigneeUserId: Value(102),
          assigneeUserName: Value('小李'),
        ),
      );

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

      await tester.tap(find.byKey(const Key('todo-filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-filter-advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-filter-assignee')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('小周').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('应用高级筛选'));
      await tester.tap(find.text('应用高级筛选'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('确定今天最重要的三件事'), findsOneWidget);
      expect(find.text('完成 Todo 工作区视觉评审'), findsNothing);
    },
  );

  testWidgets('command and control clicks toggle non-adjacent visible tasks', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
    );

    await modifiedTaskTap(
      tester,
      taskId: TodoVisualFixture.pinnedTaskId,
      modifier: LogicalKeyboardKey.metaLeft,
    );
    await modifiedTaskTap(
      tester,
      taskId: TodoVisualFixture.secondaryTodayTaskId,
      modifier: LogicalKeyboardKey.controlLeft,
    );

    expect(find.byKey(const Key('todo-batch-actionbar')), findsOneWidget);
    expect(find.text('2 已选'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(
              Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}'),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(
              Key(
                'task-batch-select-${TodoVisualFixture.secondaryTodayTaskId}',
              ),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(
              Key('task-batch-select-${TodoVisualFixture.todayTaskId}'),
            ),
          )
          .value,
      isFalse,
    );
  });

  testWidgets(
    'shift click selects an inclusive range from the latest selection anchor',
    (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      );

      await modifiedTaskTap(
        tester,
        taskId: TodoVisualFixture.pinnedTaskId,
        modifier: LogicalKeyboardKey.controlLeft,
      );
      await modifiedTaskTap(
        tester,
        taskId: TodoVisualFixture.secondaryTodayTaskId,
        modifier: LogicalKeyboardKey.shiftLeft,
      );

      expect(find.text('3 已选'), findsOneWidget);
      for (final taskId in [
        TodoVisualFixture.pinnedTaskId,
        TodoVisualFixture.todayTaskId,
        TodoVisualFixture.secondaryTodayTaskId,
      ]) {
        expect(
          tester
              .widget<Checkbox>(find.byKey(Key('task-batch-select-$taskId')))
              .value,
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'compact selection dock exposes primary actions without overflow',
    (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.mobileMin,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      );

      await enterBatchEdit(tester);
      await tester.tap(
        find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('todo-batch-actionbar')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-due')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-priority')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-move')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-delete')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320dp selection dock keeps primary actions reachable without overflow',
    (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: const Size(320, 700),
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      );

      await enterBatchEdit(tester);
      await tester.tap(
        find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('todo-batch-due')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-priority')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-move')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-delete')), findsOneWidget);
      expect(find.byKey(const Key('todo-batch-complete')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('todo-batch-action-complete')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('todo-batch-action-linkToParent')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('todo-batch-action-share')), findsOneWidget);
    },
  );

  testWidgets(
    'batch edit links selected tasks to a chosen parent with feedback',
    (tester) async {
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      );

      await enterBatchEdit(tester);
      await tester.tap(
        find.byKey(
          Key('task-batch-select-${TodoVisualFixture.secondaryTodayTaskId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-action-linkToParent')));
      await tester.pumpAndSettle();

      expect(find.text('关联主任务'), findsOneWidget);
      expect(
        find.byKey(Key('todo-batch-parent-${TodoVisualFixture.pinnedTaskId}')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key('todo-batch-parent-${TodoVisualFixture.secondaryTodayTaskId}'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(Key('todo-batch-parent-${TodoVisualFixture.pinnedTaskId}')),
      );
      await tester.pumpAndSettle();

      final linked =
          await (fixture.database.select(fixture.database.todoTasks)..where(
                (row) => row.id.equals(TodoVisualFixture.secondaryTodayTaskId),
              ))
              .getSingle();
      expect(linked.parentTaskId, TodoVisualFixture.pinnedTaskId);
      final queued = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        queued.where(
          (change) =>
              change.entity == 'task' &&
              change.entityLocalId == TodoVisualFixture.secondaryTodayTaskId &&
              change.op == 'upsert',
        ),
        hasLength(1),
      );
      expect(find.text('已关联 1 项；失败 0 项'), findsOneWidget);
    },
  );

  testWidgets(
    'batch delete requires confirmation and reuses cascade delete outbox',
    (tester) async {
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      );

      await enterBatchEdit(tester);
      await tester.tap(
        find.byKey(
          Key('task-batch-select-${TodoVisualFixture.metadataTaskId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-delete')));
      await tester.pumpAndSettle();

      expect(find.text('删除所选任务？'), findsOneWidget);
      expect(find.textContaining('子任务也会被一并删除'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        await (fixture.database.select(fixture.database.todoTasks)..where(
              (task) => task.id.equals(TodoVisualFixture.metadataTaskId),
            ))
            .getSingleOrNull(),
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('todo-batch-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      final remaining = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      expect(
        remaining.map((task) => task.id),
        isNot(
          containsAll([
            TodoVisualFixture.metadataTaskId,
            'visual-task-metadata-child-1',
            'visual-task-metadata-child-2',
          ]),
        ),
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        changes.where(
          (change) =>
              change.entity == 'task' &&
              change.entityLocalId == TodoVisualFixture.metadataTaskId &&
              change.op == 'delete',
        ),
        hasLength(1),
      );
      expect(find.text('已删除 1 项；失败 0 项'), findsOneWidget);
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

      await enterBatchEdit(tester);
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

      await enterBatchEdit(tester);
      for (final taskId in [
        TodoVisualFixture.pinnedTaskId,
        TodoVisualFixture.todayTaskId,
      ]) {
        await tester.tap(find.byKey(Key('task-batch-select-$taskId')));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-priority')));
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

  testWidgets('batch feedback includes each failed task reason', (
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
    await enterBatchEdit(tester);
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
    );
    await (fixture.database.delete(
      fixture.database.todoTasks,
    )..where((task) => task.id.equals(TodoVisualFixture.todayTaskId))).go();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-priority')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为高优先级'));
    await tester.pumpAndSettle();

    expect(find.text('已更新 0 项；失败 1 项：任务不存在'), findsOneWidget);
  });

  testWidgets('batch feedback retries only failed tasks after data recovers', (
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
    await enterBatchEdit(tester);
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
    );
    final deletedTask =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
            .getSingle();
    await (fixture.database.delete(
      fixture.database.todoTasks,
    )..where((task) => task.id.equals(TodoVisualFixture.todayTaskId))).go();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-priority')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为高优先级'));
    await tester.pumpAndSettle();

    expect(find.text('已更新 0 项；失败 1 项：任务不存在'), findsOneWidget);
    expect(find.text('重试失败项'), findsOneWidget);

    await fixture.database
        .into(fixture.database.todoTasks)
        .insertOnConflictUpdate(deletedTask.toCompanion(true));
    await tester.tap(find.text('重试失败项'));
    await tester.pumpAndSettle();

    expect(find.text('已重试 1 项；失败 0 项'), findsOneWidget);
    final retried =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
            .getSingle();
    expect(retried.priority, 3);
  });

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

      await enterBatchEdit(tester);
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

      await enterBatchEdit(tester);
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

      await enterBatchEdit(tester);
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

    await enterBatchEdit(tester);
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.metadataTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-move')));
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

    await enterBatchEdit(tester);
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

    await enterBatchEdit(tester);
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

    await enterBatchEdit(tester);
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.todayTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-due')));
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

  testWidgets(
    'batch share preserves visible order and never writes tasks or outbox',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      MethodCall? received;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        received = call;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final tasksBefore = await fixture.database
          .select(fixture.database.todoTasks)
          .get();
      final outboxBefore = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();

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
      await enterBatchEdit(tester);
      await tester.tap(
        find.byKey(
          Key('task-batch-select-${TodoVisualFixture.secondaryTodayTaskId}'),
        ),
      );
      await tester.tap(
        find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-batch-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-batch-action-share')));
      await tester.pumpAndSettle();

      expect(received?.method, 'share');
      expect(received?.arguments, {
        'text':
            '已选择 2 项 Todo 任务\n\n'
            '1. 确定今天最重要的三件事\n'
            '先完成视觉母版，再处理交互细节。\n'
            '截止：2026-07-11 09:30 (本地时区)\n\n'
            '2. 回复设计反馈并确认下一步\n'
            '截止：2026-07-11 14:30 (本地时区)',
        'subject': '2 项 Todo 任务',
      });
      expect(find.text('已打开系统分享'), findsOneWidget);
      expect(
        await fixture.database.select(fixture.database.todoTasks).get(),
        tasksBefore,
      );
      expect(
        await fixture.database.select(fixture.database.todoSyncChanges).get(),
        outboxBefore,
      );
    },
  );

  testWidgets('batch share reports unsupported platform and keeps selection', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
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
    await enterBatchEdit(tester);
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-share')));
    await tester.pumpAndSettle();

    expect(find.text('当前设备不支持系统分享'), findsOneWidget);
    expect(find.text('1 已选'), findsOneWidget);
  });
}
