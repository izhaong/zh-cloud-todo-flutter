import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';

/// M11-B3 c4 时间线视图：纯函数分类 + widget 渲染。
void main() {
  group('classifyTimelineBucket', () {
    // 把 "now" 固定到周一 12:00，使周范围可预期：
    // 2026-06-15 是周一；now 视为该周一 12:00
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final weekStart = DateTime(2026, 6, 15); // 周一 00:00
    final weekEnd = DateTime(2026, 6, 22); // 下周一 00:00
    final nextWeekEnd = DateTime(2026, 6, 29);

    TodoTask build({DateTime? dueAt, bool completed = false}) {
      return TodoTask(
        id: 1,
        listId: 1,
        title: 't',
        completed: completed,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: dueAt,
        updatedAt: now,
        createdAt: now,
      );
    }

    test('overdue: due 在今天 00:00 之前', () {
      final t = build(dueAt: DateTime(2026, 6, 14, 23, 59));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.overdue,
      );
    });

    test('today: due 落在今天 00:00 ~ 明天 00:00', () {
      final t = build(dueAt: DateTime(2026, 6, 15, 18, 0));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.today,
      );
    });

    test('tomorrow: due 落在明天 00:00 ~ 后天 00:00', () {
      final t = build(dueAt: DateTime(2026, 6, 16, 9, 0));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.tomorrow,
      );
    });

    test('thisWeek: due 落在本周 [weekStart, weekEnd)', () {
      final t = build(dueAt: DateTime(2026, 6, 18, 9, 0));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.thisWeek,
      );
    });

    test('nextWeek: due 落在下周 [weekEnd, nextWeekEnd)', () {
      final t = build(dueAt: DateTime(2026, 6, 23, 9, 0));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.nextWeek,
      );
    });

    test('later: due > nextWeekEnd', () {
      final t = build(dueAt: DateTime(2026, 7, 1, 9, 0));
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.later,
      );
    });

    test('later: 无 dueAt', () {
      final t = build();
      expect(
        classifyTimelineBucket(t, now,
            weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd),
        TimelineBucket.later,
      );
    });
  });

  testWidgets('TimelineView 按桶分组渲染', (tester) async {
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: 1,
        listId: 1,
        title: '昨天的事',
        completed: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 14, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 2,
        listId: 1,
        title: '今天要完成',
        completed: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 15, 18, 0),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 3,
        listId: 1,
        title: '本周要做',
        completed: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 18, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: TimelineView(tasks: tasks, now: now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('昨天的事'), findsOneWidget);
    expect(find.text('今天要完成'), findsOneWidget);
    expect(find.text('本周要做'), findsOneWidget);
  });
}
