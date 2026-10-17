import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/kanban_axis_move.dart';
import 'package:zh_cloud_todo_flutter/features/task/smart_grouping.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';

/// specs/118 · 看板按「智能分组」轴开列（矩阵 #15 面 ⑦）。
///
/// 判据源《01-任务/08-不同的视图查看任务/02-看板视图：分类管理任务.md》
/// `:55`「也可以排序中选择**时间+优先级**」、`:59`「…选择清单+时间」、
/// `:78`「在排序中选择**指派人+时间**」、常见问题「智能清单支持看板视图」。
void main() {
  final now = DateTime(2026, 7, 15, 9, 30);

  TodoTask task(
    String id, {
    int priority = 0,
    DateTime? dueAt,
    String listId = 'list-inbox',
  }) {
    return TodoTask(
      id: id,
      listId: listId,
      title: '任务-$id',
      completed: false,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      priority: priority,
      isPinned: false,
      sortOrder: 0,
      updatedAt: now,
      createdAt: now,
      dueAt: dueAt,
    );
  }

  TodoList list(String id, String name) => TodoList(
    id: id,
    name: name,
    sortOrder: 0,
    isPinned: false,
    accessRole: 'owner',
    writable: true,
    memberCount: 1,
    backgroundType: 'theme',
    showInSmartList: true,
    updatedAt: now,
    createdAt: now,
  );

  group('kanbanAxisMove 换算（纯函数）', () {
    test('byTime 拖进「明天」：dueAt = 明天同一时刻', () {
      final t = task('t1', dueAt: DateTime(2026, 7, 20, 14, 5));
      final result = kanbanAxisMove(
        grouping: SmartGrouping.byTime,
        groupId: 'time-明天',
        task: t,
        lists: const [],
        now: now,
      );
      expect(result, isA<KanbanAxisUpdate>());
      expect((result as KanbanAxisUpdate).dueAt, DateTime(2026, 7, 16, 14, 5));
    });

    test('byTime 拖进「无日期」：清 dueAt', () {
      final t = task('t1', dueAt: DateTime(2026, 7, 20, 9));
      final result = kanbanAxisMove(
        grouping: SmartGrouping.byTime,
        groupId: 'time-无日期',
        task: t,
        lists: const [],
        now: now,
      );
      expect((result as KanbanAxisUpdate).clearDueAt, isTrue);
    });

    test('byTime 拖进「已过期」：不支持，给可见错误', () {
      final result = kanbanAxisMove(
        grouping: SmartGrouping.byTime,
        groupId: 'time-已过期',
        task: task('t1'),
        lists: const [],
        now: now,
      );
      expect(result, isA<KanbanAxisUnsupportedError>());
    });

    test('byPriority 拖进「高优先级」：priority=3；「无优先级」=0', () {
      final high = kanbanAxisMove(
        grouping: SmartGrouping.byPriority,
        groupId: 'prio-高优先级',
        task: task('t1'),
        lists: const [],
        now: now,
      );
      expect((high as KanbanAxisUpdate).priority, 3);
      final none = kanbanAxisMove(
        grouping: SmartGrouping.byPriority,
        groupId: 'prio-无优先级',
        task: task('t2', priority: 2),
        lists: const [],
        now: now,
      );
      expect((none as KanbanAxisUpdate).priority, 0);
    });

    test('byList 拖进同名清单列：listId = 该清单 id；重名取第一个', () {
      final lists = [list('l1', '工作'), list('l2', '工作'), list('l3', '生活')];
      final result = kanbanAxisMove(
        grouping: SmartGrouping.byList,
        groupId: 'list-工作',
        task: task('t1', listId: 'l3'),
        lists: lists,
        now: now,
      );
      expect((result as KanbanAxisUpdate).listId, 'l1');
    });

    test('byList 拖进不存在的清单名：可见错误不静默', () {
      final result = kanbanAxisMove(
        grouping: SmartGrouping.byList,
        groupId: 'list-不存在',
        task: task('t1'),
        lists: [list('l1', '工作')],
        now: now,
      );
      expect(result, isA<KanbanAxisUnsupportedError>());
    });

    test('byAssignee / byTag / byCreatedAt：不可拖，给可见错误', () {
      for (final (grouping, prefix) in [
        (SmartGrouping.byAssignee, 'assignee-张三'),
        (SmartGrouping.byTag, 'tag-工作'),
        (SmartGrouping.byCreatedAt, 'created-今天'),
      ]) {
        final result = kanbanAxisMove(
          grouping: grouping,
          groupId: prefix,
          task: task('t1'),
          lists: const [],
          now: now,
        );
        expect(result, isA<KanbanAxisUnsupportedError>(), reason: '$grouping');
      }
    });
  });

  group('KanbanView 轴列渲染与拖拽（widget）', () {
    SmartTaskGroup group(String id, String title, List<TodoTask> tasks) =>
        SmartTaskGroup(id: id, title: title, tasks: tasks);

    Future<void> pump(
      WidgetTester tester, {
      required List<TodoTask> tasks,
      required List<SmartTaskGroup> smartGroups,
      Future<void> Function(TodoTask task, String groupId)? onMove,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanbanView(
              tasks: tasks,
              listId: 'list-inbox',
              smartGroups: smartGroups,
              onSmartGroupMove: onMove,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('轴列 = 传入的分组桶；组内任务各归其列', (tester) async {
      final today = task('a', dueAt: DateTime(2026, 7, 15, 9));
      final tomorrow = task('b', dueAt: DateTime(2026, 7, 16, 9));
      await pump(
        tester,
        tasks: [today, tomorrow],
        smartGroups: [
          group('time-今天', '今天', [today]),
          group('time-明天', '明天', [tomorrow]),
        ],
      );

      expect(find.text('今天'), findsOneWidget);
      expect(find.text('明天'), findsOneWidget);
      // priority 四列的档名不该出现。
      expect(find.text('未开始'), findsNothing);
      expect(find.text('任务-a'), findsOneWidget);
      expect(find.text('任务-b'), findsOneWidget);
    });

    testWidgets('拖进另一列：回调带目标列 id', (tester) async {
      final today = task('a', dueAt: DateTime(2026, 7, 15, 9));
      String? movedGroup;
      await pump(
        tester,
        tasks: [today],
        smartGroups: [
          group('time-今天', '今天', [today]),
          group('time-明天', '明天', const []),
        ],
        onMove: (task, groupId) async => movedGroup = groupId,
      );

      final target = find
          .descendant(
            of: find.byKey(const Key('col-time-明天')),
            matching: find.text('空'),
          )
          .first;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('任务-a')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedGroup, 'time-明天');
    });

    testWidgets('轴列不给列重排（嘀嗒该形态没有列序要求）', (tester) async {
      final today = task('a');
      await pump(
        tester,
        tasks: [today],
        smartGroups: [
          group('time-今天', '今天', [today]),
          group('time-明天', '明天', const []),
        ],
      );

      // 列头没有左右移动按钮。
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });
}
