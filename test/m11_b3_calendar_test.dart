import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';

/// M11-B3 c5 日历视图：纯函数 + 4 模式渲染。
void main() {
  group('resolveTaskDate', () {
    final base = DateTime(2026, 6, 15, 18, 30);
    TodoTask build({DateTime? startAt, DateTime? endAt, DateTime? dueAt}) {
      return TodoTask(
        id: 1,
        listId: 1,
        title: 't',
        completed: false,
        priority: 0,
        startAt: startAt,
        endAt: endAt,
        dueAt: dueAt,
        updatedAt: base,
        createdAt: base,
      );
    }

    test('优先 dueAt', () {
      final t = build(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 2, 1),
        dueAt: DateTime(2026, 6, 15, 18, 30),
      );
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 6, 15));
    });

    test('次选 endAt（无 dueAt）', () {
      final t = build(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 5, 1, 12),
      );
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 5, 1));
    });

    test('再次 startAt', () {
      final t = build(startAt: DateTime(2026, 4, 1, 9));
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 4, 1));
    });

    test('全空返回 null', () {
      expect(resolveTaskDate(build()), isNull);
    });
  });

  group('buildMonthGrid', () {
    test('7 列 × 6 行；从周一开始', () {
      final grid = buildMonthGrid(DateTime(2026, 6, 15));
      expect(grid.length, 6);
      for (final row in grid) {
        expect(row.length, 7);
      }
      // 第一格应为 6 月 1 日所在周的周一
      // 2026-06-01 是周一
      expect(grid.first.first, DateTime(2026, 6, 1));
      // 最后一格 = 第一格 + 41 天
      expect(grid.last.last, grid.first.first.add(const Duration(days: 41)));
    });

    test('跨月：6 月 1 日不是周一时，网格包含 5 月末尾 + 7 月开头', () {
      // 2026-11-01 是周日，所以 11 月的网格会跨到 10 月末尾和 12 月开头
      final grid = buildMonthGrid(DateTime(2026, 11, 15));
      final all = grid.expand((r) => r).toList();
      expect(all.any((d) => d.month == 10), isTrue);
      expect(all.any((d) => d.month == 12), isTrue);
    });

    test('6 月：1 日周一、30 日周二 → 6×6 网格跨到 7 月', () {
      // 2026-06-01 = 周一, 2026-06-30 = 周二 → 6 行 × 7 列 = 42 天会跨到 7 月
      final grid = buildMonthGrid(DateTime(2026, 6, 15));
      final all = grid.expand((r) => r).toList();
      expect(all.length, 42);
      expect(all.any((d) => d.month == 7), isTrue);
    });
  });

  testWidgets('CalendarView 月模式渲染工具栏 + 网格', (tester) async {
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: 1,
        listId: 1,
        title: '本月任务',
        completed: false,
        priority: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 20, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CalendarView(tasks: tasks, now: now)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 工具栏模式切换
    expect(find.text('月'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('列表'), findsOneWidget);
    // 6 月 20 日应被标记"1 项"
    expect(find.text('1 项'), findsOneWidget);
  });

  testWidgets('CalendarView 列表模式按日期排序', (tester) async {
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: 1,
        listId: 1,
        title: '晚一点',
        completed: false,
        priority: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 20, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 2,
        listId: 1,
        title: '早一点',
        completed: false,
        priority: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 10, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(
              tasks: tasks,
              now: now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 切到列表模式
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('早一点'), findsOneWidget);
    expect(find.text('晚一点'), findsOneWidget);
    // 早一点应排在晚一点前面
    final earlier = tester.getTopLeft(find.text('早一点'));
    final later = tester.getTopLeft(find.text('晚一点'));
    expect(earlier.dy < later.dy, isTrue);
  });
}
