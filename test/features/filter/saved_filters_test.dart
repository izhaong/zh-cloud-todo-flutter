import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filters_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

import '../../support/todo_visual_fixture.dart';

void main() {
  testWidgets('筛选面板把当前条件存成过滤器：写 todoFilters 与 outbox，不再造 smart 清单', (
    tester,
  ) async {
    final fixture = await _pump(
      tester,
      home: Scaffold(
        body: FilterBar(
          filter: const TaskFilter(
            priority: 3,
            keyword: '英语',
            dueRange: 'today',
            completed: false,
          ),
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('保存为过滤器'), findsOneWidget);
    await tester.tap(find.text('保存为过滤器'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('saved-filter-name')),
      '高优先级英语',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final rows = await fixture.database
        .select(fixture.database.todoFilters)
        .get();
    expect(rows, hasLength(1));
    final conditions =
        jsonDecode(rows.single.conditionJson) as Map<String, dynamic>;
    expect(conditions['priorities'], [3]);
    expect(conditions['keyword'], '英语');
    expect(conditions['statuses'], ['todo']);
    expect(conditions['dateRange'], {'preset': 'today'});

    expect(await _filterChanges(fixture.database), hasLength(1));
    expect((await _filterChanges(fixture.database)).single.op, 'upsert');

    // 旧口径把条件塞进 `smart:` 清单名（本地根本存不住条件），本轮必须不再走那条路。
    final allLists = await fixture.database
        .select(fixture.database.todoLists)
        .get();
    expect(
      allLists.where((row) => row.name.startsWith('smart:')),
      isEmpty,
      reason: '已保存过滤器落真表，不再借用清单名',
    );
  });

  testWidgets('本机存不住的维度会在保存对话框里明说，不静默丢弃', (tester) async {
    await _pump(
      tester,
      home: Scaffold(
        body: FilterBar(
          filter: const TaskFilter(
            folderId: 'folder-local',
            assigneeUserId: 21,
            priority: 2,
            dueRange: 'overdue',
          ),
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('保存为过滤器'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('不保存', findRichText: true),
      findsOneWidget,
      reason: '文件夹与负责人没有对应条件字段，必须告知用户而不是存成半个过滤器',
    );
    // 精确断言整句：`负责人` 三个字在筛选条本身的芯片上也有，只查子串会误判。
    expect(find.text('本过滤器不保存：文件夹、负责人、到期范围「已过期」'), findsOneWidget);
    expect(find.byKey(const Key('saved-filter-name')), findsOneWidget);
  });

  testWidgets('筛选器页列出真保存的过滤器并给出可读条件摘要，假条目不再出现', (tester) async {
    final fixture = await _pump(tester, home: const SizedBox.shrink());
    await _repo(fixture).save(
      name: '高优先级英语',
      conditions: const TodoFilterConditions(
        priorities: [3],
        keyword: '英语',
        statuses: ['todo'],
      ),
    );

    await _repump(tester, fixture, const SavedFiltersPage());

    expect(find.text('高优先级英语'), findsOneWidget);
    expect(
      find.textContaining('优先级 高'),
      findsOneWidget,
      reason: '只写名字不写条件，用户无法区分两个同名过滤器',
    );
    expect(find.textContaining('关键词「英语」'), findsOneWidget);
    expect(find.textContaining('未完成'), findsOneWidget);
    for (final fake in const ['今日任务', '已完成', '已过期']) {
      expect(find.text(fake), findsNothing, reason: '$fake 是原静态占位的假条目');
    }
  });

  testWidgets('一个过滤器都没有时给空态而不是空列表', (tester) async {
    final fixture = await _pump(tester, home: const SizedBox.shrink());

    await _repump(tester, fixture, const SavedFiltersPage());

    expect(find.text('还没有保存的过滤器'), findsOneWidget);
  });

  testWidgets('删除要二次确认：取消不删，确认后删本地行并入 outbox delete', (tester) async {
    final fixture = await _pump(tester, home: const SizedBox.shrink());
    final saved = await _repo(fixture).save(
      name: '待删除过滤器',
      conditions: const TodoFilterConditions(keyword: '删除我'),
    );

    await _repump(tester, fixture, const SavedFiltersPage());

    await tester.tap(find.byKey(ValueKey('saved-filter-delete-${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('待删除过滤器'), findsOneWidget);
    expect(await _filterChanges(fixture.database), hasLength(1));

    await tester.tap(find.byKey(ValueKey('saved-filter-delete-${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('待删除过滤器'), findsNothing);
    expect(
      await fixture.database.select(fixture.database.todoFilters).get(),
      isEmpty,
    );
    expect(
      (await _filterChanges(fixture.database)).map((row) => row.op).toList()
        ..sort(),
      ['delete', 'upsert'],
    );
  });

  testWidgets('320px + 1.3 倍字体下长名称与摘要不溢出，档位真的进到页面', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final fixture = await _pump(tester, home: const SizedBox.shrink());
    final longName = '高优先级英语与数学作业筛选器名称故意拉得很长很长';
    await _repo(fixture).save(
      name: longName,
      conditions: const TodoFilterConditions(
        priorities: [3],
        keyword: '英语',
        statuses: ['todo'],
        listIds: ['a', 'b'],
        tagIds: ['t1', 't2', 't3'],
      ),
    );

    await _repump(tester, fixture, const SavedFiltersPage());

    expect(find.text(longName), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '窄屏 + 大字体下若溢出，RenderFlex 会在这里抛出',
    );
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(SavedFiltersPage)),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '档位没真的生效时这条会红，避免大字体用例空转',
    );
  });

  testWidgets('读屏能读出过滤器名称与条件摘要（同一节点，名称在前）', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final fixture = await _pump(tester, home: const SizedBox.shrink());
      final saved = await _repo(fixture).save(
        name: '只读高优先级',
        conditions: const TodoFilterConditions(priorities: [3]),
      );
      await _repump(tester, fixture, const SavedFiltersPage());

      final label = tester
          .getSemantics(find.byKey(ValueKey('saved-filter-${saved.id}')))
          .label
          .toString();
      expect(label, startsWith('只读高优先级'));
      expect(label, contains('优先级 高'));
      // 删除动作必须自带读屏名，不能只靠垃圾桶图标。
      expect(find.bySemanticsLabel('删除过滤器'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('服务端下发但本机表示不了的条件：标不支持、且点不动', (tester) async {
    final fixture = await _pump(tester, home: const SizedBox.shrink());
    // 绕过 save()，模拟 pull 落库的行：契约里的 in_progress 在本地筛选态没有对应字段。
    await fixture.database.batch((batch) {
      batch.insert(
        fixture.database.todoFilters,
        TodoFiltersCompanion.insert(
          id: 'pulled-in-progress',
          name: '进行中的任务',
          conditionJson: '{"statuses":["in_progress"]}',
          updatedAt: DateTime(2026, 7, 11, 9),
          createdAt: DateTime(2026, 7, 11, 9),
        ),
      );
      batch.insert(
        fixture.database.todoFilters,
        TodoFiltersCompanion.insert(
          id: 'pulled-with-tag',
          name: '带标签的',
          conditionJson: '{"tagIds":["t1"]}',
          updatedAt: DateTime(2026, 7, 11, 9),
          createdAt: DateTime(2026, 7, 11, 9),
        ),
      );
    });

    await _repump(tester, fixture, const SavedFiltersPage());

    // 只有「契约里有、本地筛选态没有对应字段」的那条才算不支持。
    // `tagIds` 从 Issue #417 起真的参与求值（`applyTaskFilter` 有了标签分支），
    // 所以带标签的行必须恢复可套用 —— 这里反过来钉住它不再被标不支持。
    expect(find.textContaining('本机暂不支持套用'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('saved-filter-pulled-in-progress')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SavedFiltersPage),
      findsOneWidget,
      reason: 'in_progress 套不出一样的结果集，必须不可点',
    );
    expect(
      find.ancestor(
        of: find.text('带标签的'),
        matching: find.textContaining('本机暂不支持套用'),
      ),
      findsNothing,
      reason: '标签维度已参与求值 ⇒ 带标签的行不该再被标成不支持',
    );
  });

  testWidgets('条件流失败时给错误态而不是空白页', (tester) async {
    await _pump(
      tester,
      home: const SavedFiltersPage(),
      overridesBuilder: (_) => [
        savedFiltersStreamProvider.overrideWith(
          (ref) => Stream<List<TodoFilter>>.error(StateError('故意失败')),
        ),
      ],
    );

    expect(find.text('过滤器加载失败'), findsOneWidget);
  });

  testWidgets('只剩存不下的维度时拒存，不写库也不入 outbox', (tester) async {
    final fixture = await _pump(
      tester,
      home: Scaffold(
        body: FilterBar(
          filter: const TaskFilter(folderId: 'folder-local'),
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('保存为过滤器'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('saved-filter-name')), '只有文件夹');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('未保存'), findsOneWidget);
    expect(
      await fixture.database.select(fixture.database.todoFilters).get(),
      isEmpty,
    );
    expect(await _filterChanges(fixture.database), isEmpty);
  });

  testWidgets('点一条过滤器会忠实还原成 TaskFilter 并真的筛掉不匹配任务', (tester) async {
    final fixture = await _pump(tester, home: const SizedBox.shrink());
    await fixture.database.batch((batch) {
      batch.insert(
        fixture.database.todoLists,
        TodoListsCompanion.insert(
          id: 'saved-filter-apply-list',
          name: '套用清单',
          updatedAt: fixture.fixedNow,
          createdAt: fixture.fixedNow,
        ),
      );
      batch.insertAll(fixture.database.todoTasks, [
        TodoTasksCompanion.insert(
          id: 'saved-filter-apply-hit',
          listId: 'saved-filter-apply-list',
          title: '套用命中的任务',
          priority: const Value(3),
          updatedAt: fixture.fixedNow,
          createdAt: fixture.fixedNow,
        ),
        TodoTasksCompanion.insert(
          id: 'saved-filter-apply-miss',
          listId: 'saved-filter-apply-list',
          title: '套用不该出现的任务',
          priority: const Value(1),
          updatedAt: fixture.fixedNow,
          createdAt: fixture.fixedNow,
        ),
      ]);
    });
    final saved = await _repo(fixture).save(
      name: '只要高优先级',
      conditions: const TodoFilterConditions(priorities: [3]),
    );

    TaskFilter? applied;
    late StateSetter rebuild;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return TasksByListPage(
                initialListId: 'saved-filter-apply-list',
                lockedListId: true,
                hideAppBar: true,
                initialFilter: applied,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('套用命中的任务'), findsOneWidget);
    expect(find.text('套用不该出现的任务'), findsOneWidget);

    final poppedFuture =
        Navigator.of(
          tester.element(find.byType(TasksByListPage)),
        ).push<TaskFilter>(
          MaterialPageRoute(builder: (_) => const SavedFiltersPage()),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('saved-filter-${saved.id}')));
    await tester.pumpAndSettle();

    final popped = await poppedFuture;
    expect(popped, isNotNull);
    expect(popped, isNotNull);
    expect(popped!.priority, 3);
    expect(popped.listId, isNull);

    rebuild(() => applied = popped);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('套用命中的任务'), findsOneWidget);
    expect(
      find.text('套用不该出现的任务'),
      findsNothing,
      reason: '套用必须真的改变任务列表，否则只是把数据搬了个来回',
    );
  });
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  required Widget home,
  List<Override> Function(AppDatabase database)? overridesBuilder,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);
  await _repump(tester, fixture, home);
  return fixture;
}

/// 换页面要重挂整棵树；同类型同位置会复用 State，`initState` 不再执行。
Future<void> _repump(
  WidgetTester tester,
  TodoVisualFixture fixture,
  Widget page,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilterRepository _repo(TodoVisualFixture fixture) =>
    fixture.container.read(filterRepositoryProvider)!;

Future<List<TodoSyncChange>> _filterChanges(AppDatabase db) => (db.select(
  db.todoSyncChanges,
)..where((row) => row.entity.equals('filter'))).get();
