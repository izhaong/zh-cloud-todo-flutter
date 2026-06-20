import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/task_view_mode_tabs.dart';

/// M11-B3 c3 测试：四象限 Eisenhower 分类纯函数 + 视图 tab 渲染。
void main() {
  group('classifyEisenhower', () {
    final now = DateTime(2026, 6, 20, 12, 0, 0);

    TodoTask build({
      int priority = 0,
      DateTime? dueAt,
      bool completed = false,
    }) {
      return TodoTask(
        id: 1,
        listId: 1,
        title: 't',
        completed: completed,
        priority: priority,
        startAt: null,
        endAt: null,
        dueAt: dueAt,
        updatedAt: now,
        createdAt: now,
      );
    }

    test('Q1: priority>=2 且 due 在 24h 内', () {
      final t = build(priority: 2, dueAt: now.add(const Duration(hours: 6)));
      expect(classifyEisenhower(t, now), Quadrant.q1);
    });

    test('Q1: priority>=2 且 due 已过期', () {
      final t = build(priority: 3, dueAt: now.subtract(const Duration(hours: 1)));
      expect(classifyEisenhower(t, now), Quadrant.q1);
    });

    test('Q2: priority>=2 且 due > 24h', () {
      final t = build(priority: 2, dueAt: now.add(const Duration(days: 3)));
      expect(classifyEisenhower(t, now), Quadrant.q2);
    });

    test('Q2: priority>=2 且 无 due', () {
      final t = build(priority: 2);
      expect(classifyEisenhower(t, now), Quadrant.q2);
    });

    test('Q3: priority<2 且 due 在 24h 内', () {
      final t = build(priority: 1, dueAt: now.add(const Duration(hours: 2)));
      expect(classifyEisenhower(t, now), Quadrant.q3);
    });

    test('Q4: priority<2 且无 due', () {
      final t = build(priority: 0);
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });

    test('Q4: priority<2 且 due > 24h', () {
      final t = build(priority: 1, dueAt: now.add(const Duration(days: 5)));
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });

    test('Q4: 已完成任务', () {
      final t = build(priority: 2, dueAt: now, completed: true);
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });
  });

  testWidgets('TaskViewModeTabs 渲染 5 个 tab 并触发 onChanged', (tester) async {
    TaskViewMode? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskViewModeTabs(
            mode: TaskViewMode.list,
            onChanged: (m) => changed = m,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('列表'), findsWidgets);
    expect(find.text('看板'), findsOneWidget);
    expect(find.text('四象限'), findsOneWidget);

    // 点击"四象限"切换
    await tester.tap(find.text('四象限'));
    await tester.pumpAndSettle();
    expect(changed, TaskViewMode.eisenhower);
  });

  testWidgets('EisenhowerView 4 象限渲染', (tester) async {
    final now = DateTime(2026, 6, 20, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: 1,
        listId: 1,
        title: '紧急且重要',
        priority: 2,
        completed: false,
        dueAt: now.add(const Duration(hours: 1)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 2,
        listId: 1,
        title: '重要不紧急',
        priority: 3,
        completed: false,
        dueAt: now.add(const Duration(days: 5)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 3,
        listId: 1,
        title: '紧急不重要',
        priority: 0,
        completed: false,
        dueAt: now.add(const Duration(hours: 2)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: 4,
        listId: 1,
        title: '不重要不紧急',
        priority: 0,
        completed: false,
        updatedAt: now,
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EisenhowerView(tasks: tasks, now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Q1 · 重要且紧急'), findsOneWidget);
    expect(find.text('Q2 · 重要不紧急'), findsOneWidget);
    expect(find.text('Q3 · 紧急不重要'), findsOneWidget);
    expect(find.text('Q4 · 不紧急不重要'), findsOneWidget);

    // 计数
    for (final label in ['紧急且重要', '重要不紧急', '紧急不重要', '不重要不紧急']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
