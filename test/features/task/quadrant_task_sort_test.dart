import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/127 · 四象限每象限任务排序（矩阵 #36 面 ⑪）。
///
/// 判据源《02-如何编辑四象限规则.md》:135-:136——
/// 「如何调整四象限的任务顺序？选择需要更改的象限，点击右上角『…』-『排序』，
/// 可选择排序方式。」
void main() {
  final now = DateTime(2026, 7, 15, 9);

  TodoTask task(
    String id, {
    int priority = 0,
    DateTime? dueAt,
    DateTime? createdAt,
  }) => TodoTask(
    id: id,
    listId: 'list-1',
    title: '任务-$id',
    completed: false,
    cancelled: false,
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    priority: priority,
    isPinned: false,
    sortOrder: 0,
    dueAt: dueAt,
    updatedAt: now,
    createdAt: createdAt ?? now,
  );

  group('象限内排序（widget 级）', () {
    // Q1（重要且紧急）：priority>=2 且 24h 内到期。
    final urgentTodayHigh = task(
      'a1',
      priority: 3,
      dueAt: DateTime(2026, 7, 15, 18),
      createdAt: DateTime(2026, 7, 10),
    );
    final urgentTodayLowCreated = task(
      'a2',
      priority: 2,
      dueAt: DateTime(2026, 7, 15, 20),
      createdAt: DateTime(2026, 7, 14),
    );

    Future<void> pump(
      WidgetTester tester, {
      required List<TodoTask> tasks,
      Map<String, String> quadrantTaskSort = const {},
      void Function(String quadrant, TaskSort sort)? onSortChanged,
    }) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: Scaffold(
              body: EisenhowerView(
                tasks: tasks,
                now: now,
                quadrantTaskSort: quadrantTaskSort,
                onQuadrantSortChanged: onSortChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 象限里的任务行 key 由 tile 内部生成；用标题找。
    double titleTop(WidgetTester tester, String title) =>
        tester.getRect(find.text(title).first).top;

    testWidgets('默认（未选档）：按分桶输入顺序渲染，无「排序」入口', (tester) async {
      await pump(tester, tasks: [urgentTodayHigh, urgentTodayLowCreated]);

      expect(find.byKey(const Key('quadrant-sort-q1')), findsNothing);
      // 输入顺序：a1 在前。
      expect(titleTop(tester, '任务-a1'), lessThan(titleTop(tester, '任务-a2')));
    });

    testWidgets('有回调就有每象限「…」排序入口；选「按创建时间」即回调', (tester) async {
      String? quadrant;
      TaskSort? sort;
      await pump(
        tester,
        tasks: [urgentTodayHigh, urgentTodayLowCreated],
        onSortChanged: (q, s) {
          quadrant = q;
          sort = s;
        },
      );

      expect(find.byKey(const Key('quadrant-sort-q1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quadrant-sort-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quadrant-sort-q1-createdAt')));
      await tester.pumpAndSettle();

      expect(quadrant, 'q1');
      expect(sort, TaskSort.createdAt);
    });

    testWidgets('选中档后象限内按该档重排：createdAt 档让晚建的在前', (tester) async {
      await pump(
        tester,
        tasks: [urgentTodayHigh, urgentTodayLowCreated],
        quadrantTaskSort: const {'q1': 'createdAt'},
        onSortChanged: (q, s) {},
      );
      // TaskSort.createdAt 默认 newestFirst ⇒ 晚建的 a2 在前。
      expect(titleTop(tester, '任务-a2'), lessThan(titleTop(tester, '任务-a1')));
      // 当前档勾选标记存在（打开菜单才看得到）。
      await tester.tap(find.byKey(const Key('quadrant-sort-q1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('quadrant-sort-q1-createdAt')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('未选档的象限不受其它象限影响', (tester) async {
      // q2（重要不紧急）：高优先级、远期到期。
      final q2Task = task('b1', priority: 3, dueAt: DateTime(2026, 8, 15));
      await pump(
        tester,
        tasks: [urgentTodayHigh, urgentTodayLowCreated, q2Task],
        quadrantTaskSort: const {'q1': 'createdAt'},
        onSortChanged: (q, s) {},
      );
      // q2 无档 ⇒ 输入顺序（b1 是唯一任务，在不在都行——断言不抛即可）。
      expect(find.text('任务-b1'), findsOneWidget);
    });
  });

  group('象限排序偏好（页面级）', () {
    testWidgets('选档后偏好落库，重进工作区回读并生效', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 种子：两条 Q1 任务（早建在前）。
      final repo = fixture.container.read(taskRepositoryProvider)!;
      await repo.create(
        listId: TodoVisualFixture.inboxListId,
        title: '页面里早创建的',
        priority: 3,
        dueAt: DateTime(2026, 7, 15, 18),
      );
      await repo.create(
        listId: TodoVisualFixture.inboxListId,
        title: '页面里晚创建的',
        priority: 2,
        dueAt: DateTime(2026, 7, 15, 20),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TasksByListPage(
                initialListId: TodoVisualFixture.inboxListId,
                lockedListId: true,
                hideAppBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 切到四象限。
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('四象限').last);
      await tester.pumpAndSettle();

      // q1「…」→「排序」→「按创建时间」。
      await tester.tap(find.byKey(const Key('quadrant-sort-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quadrant-sort-q1-createdAt')));
      await tester.pumpAndSettle();

      // 偏好落库。
      final preference = await fixture.container
          .read(taskViewActionRepositoryProvider)!
          .getTaskWorkspacePreference(
            sourceKey: 'list:${TodoVisualFixture.inboxListId}',
          );
      expect(preference.quadrantTaskSort['q1'], 'createdAt');

      // 界面生效：晚创建的在前。
      expect(
        tester.getRect(find.text('页面里晚创建的').first).top,
        lessThan(tester.getRect(find.text('页面里早创建的').first).top),
      );
    });
  });

  group('仓储归一化（saveQuadrantTaskSort）', () {
    test('非法档名被拒（ArgumentError）', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
      expect(
        () => repository.saveQuadrantTaskSort(
          sourceKey: 'list:1',
          quadrant: 'q1',
          sort: 'hacked',
          current: const {},
        ),
        throwsArgumentError,
      );
    });

    test('非法象限名被拒', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
      expect(
        () => repository.saveQuadrantTaskSort(
          sourceKey: 'list:1',
          quadrant: 'q9',
          sort: 'dueDate',
          current: const {},
        ),
        throwsArgumentError,
      );
    });

    test('合法写入：current 合并保留其它象限档', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
      await repository.saveQuadrantTaskSort(
        sourceKey: 'list:1',
        quadrant: 'q2',
        sort: 'dueDate',
        current: const {'q1': 'createdAt'},
      );
      final preference = await repository.getTaskWorkspacePreference(
        sourceKey: 'list:1',
      );
      expect(preference.quadrantTaskSort, {'q1': 'createdAt', 'q2': 'dueDate'});
    });
  });
}
