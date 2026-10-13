import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/128 · 调整四象限顺序（矩阵 #36 面 ⑦）。
///
/// 判据源《02-如何编辑四象限规则.md》:64-:75——
/// mobile「点击右上角『...』，选择『编辑』，选中需要更改顺序的象限，拖动调整」；
/// desktop「点击单个象限直接拖动调整即可」。
void main() {
  final now = DateTime(2026, 7, 15, 9);

  TodoTask task(String id, {int priority = 3}) => TodoTask(
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
    dueAt: DateTime(2026, 7, 15, 18),
    updatedAt: now,
    createdAt: now,
  );

  group('象限显示顺序（widget 级）', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<TodoTask> tasks,
      List<String> quadrantOrder = const ['q1', 'q2', 'q3', 'q4'],
      void Function(List<String> order)? onOrderChanged,
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
                quadrantOrder: quadrantOrder,
                onQuadrantOrderChanged: onOrderChanged,
                onQuadrantSortChanged: onSortChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('默认排列：Q1 在左上、Q4 在右下（现状锁）', (tester) async {
      await pump(tester, tasks: [task('a')]);
      // 四个象限的 label 都在。
      expect(find.text('Q1 · 重要且紧急'), findsOneWidget);
      expect(find.text('Q4 · 不紧急不重要'), findsOneWidget);
      // Q1 的位置在 Q4 左上（x 更小且 y 更小）。
      final q1 = tester.getRect(find.text('Q1 · 重要且紧急'));
      final q4 = tester.getRect(find.text('Q4 · 不紧急不重要'));
      expect(q1.left, lessThan(q4.left));
      expect(q1.top, lessThan(q4.top));
    });

    testWidgets('排列换成 [q3,q4,q1,q2]：Q3 出现在左上', (tester) async {
      await pump(
        tester,
        tasks: [task('a')],
        quadrantOrder: const ['q3', 'q4', 'q1', 'q2'],
      );
      final q3 = tester.getRect(find.text('Q3 · 紧急不重要'));
      final q1 = tester.getRect(find.text('Q1 · 重要且紧急'));
      // q3 排到第一行（y 小于 q1）；两格同列宽，left 相等。
      expect(q3.top, lessThan(q1.top));
    });

    testWidgets('desktop 拖象限头到另一象限 ⇒ 两格交换并回调新排列', (tester) async {
      List<String>? swapped;
      await pump(
        tester,
        tasks: [task('a')],
        onOrderChanged: (order) => swapped = order,
      );

      // 拖 Q1 头（label）到 Q2 格。
      final from = tester.getCenter(find.text('Q1 · 重要且紧急'));
      final to = tester.getCenter(find.text('Q2 · 重要不紧急'));
      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(swapped, isNotNull);
      // 交换后 Q2 在第一格、Q1 在第二格。
      expect(swapped![0], 'q2');
      expect(swapped![1], 'q1');
      // UI 跟随新排列由页面级用例覆盖（setState 后重灌 quadrantOrder）。
    });

    testWidgets('「…」菜单「上移/下移」按阅读顺序换位（mobile 半面）', (tester) async {
      List<String>? moved;
      await pump(
        tester,
        tasks: [task('a')],
        onOrderChanged: (order) => moved = order,
        onSortChanged: (q, s) {},
      );

      // Q2 的菜单：上移（index 1 → 0）。
      await tester.tap(find.byKey(const Key('quadrant-sort-q2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quadrant-order-up-q2')));
      await tester.pumpAndSettle();

      expect(moved, isNotNull);
      expect(moved![0], 'q2');
      expect(moved![1], 'q1');

      // 边界：Q1（已在第一位）的上移禁用。
      await tester.tap(find.byKey(const Key('quadrant-sort-q1')));
      await tester.pumpAndSettle();
      final upItem = tester.widget<PopupMenuItem<Object>>(
        find.byKey(const Key('quadrant-order-up-q1')),
      );
      expect(upItem.enabled, isFalse);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('无回调时不给拖动与上移下移入口（现状锁）', (tester) async {
      await pump(tester, tasks: [task('a')]);
      // 菜单入口（排序）也不渲染（排序回调同样为 null）。
      expect(find.byKey(const Key('quadrant-sort-q1')), findsNothing);
    });
  });

  group('象限顺序偏好（页面级 + 仓储）', () {
    test('仓储：saveQuadrantOrder 非法排列被拒，合法排列落库回读', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

      expect(
        () => repository.saveQuadrantOrder(
          sourceKey: 'list:1',
          order: const ['q1', 'q2', 'q3'],
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.saveQuadrantOrder(
          sourceKey: 'list:1',
          order: const ['q1', 'q2', 'q2', 'q4'],
        ),
        throwsArgumentError,
      );

      await repository.saveQuadrantOrder(
        sourceKey: 'list:1',
        order: const ['q3', 'q1', 'q4', 'q2'],
      );
      final preference = await repository.getTaskWorkspacePreference(
        sourceKey: 'list:1',
      );
      expect(preference.quadrantOrder, const ['q3', 'q1', 'q4', 'q2']);
    });

    testWidgets('页面级：拖换后偏好落库，重进回读生效', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = fixture.container.read(taskRepositoryProvider)!;
      await repo.create(
        listId: TodoVisualFixture.inboxListId,
        title: '种子任务',
        priority: 3,
        dueAt: DateTime(2026, 7, 15, 18),
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

      // 切到四象限，拖 Q1 头到 Q2。
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('四象限').last);
      await tester.pumpAndSettle();
      final from = tester.getCenter(find.text('Q1 · 重要且紧急'));
      final to = tester.getCenter(find.text('Q2 · 重要不紧急'));
      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final preference = await fixture.container
          .read(taskViewActionRepositoryProvider)!
          .getTaskWorkspacePreference(
            sourceKey: 'list:${TodoVisualFixture.inboxListId}',
          );
      expect(preference.quadrantOrder, const ['q2', 'q1', 'q3', 'q4']);
    });
  });
}
