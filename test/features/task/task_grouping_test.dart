import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('desktop list uses stable dated groups with title and count', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    final groups = [
      _ExpectedGroup('pinned', '置顶', 1),
      _ExpectedGroup('today', '今天', 4),
      _ExpectedGroup('upcoming', '接下来', 3),
      _ExpectedGroup('no-date', '无日期', 4),
      _ExpectedGroup('completed', '已完成', 1),
    ];

    var previousTop = -1.0;
    for (final group in groups) {
      final finder = find.byKey(Key('todo-task-group-${group.id}'));
      expect(finder, findsOneWidget);
      if (finder.evaluate().isEmpty) continue;

      expect(
        find.descendant(of: finder, matching: find.text(group.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: finder, matching: find.text('${group.count}')),
        findsOneWidget,
      );
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(36));

      final top = tester.getTopLeft(finder).dy;
      expect(top, greaterThan(previousTop));
      previousTop = top;
    }
  });

  testWidgets('1440 populated workspace builds at least ten scannable rows', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    expect(find.byType(TaskRowHost), findsAtLeastNWidgets(10));
  });

  testWidgets('desktop list groups fixed timezone task by wall-clock date', (
    tester,
  ) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: const HomeShell(),
    );
    final now = fixture.fixedNow;
    await fixture.database
        .into(fixture.database.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'fixed-zone-group',
            listId: 'inbox',
            title: '洛杉矶今天任务',
            allDay: const Value(false),
            timeZone: const Value('America/Los_Angeles'),
            fixedTimezone: const Value(true),
            dueAt: Value(DateTime.utc(2026, 7, 12, 2)),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await tester.pumpAndSettle();

    final todayGroup = find.byKey(const Key('todo-task-group-today'));
    expect(todayGroup, findsOneWidget);
    expect(find.text('洛杉矶今天任务'), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-upcoming')), findsNothing);
  });
}

class _ExpectedGroup {
  const _ExpectedGroup(this.id, this.title, this.count);

  final String id;
  final String title;
  final int count;
}
