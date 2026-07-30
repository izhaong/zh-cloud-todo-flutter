import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  final now = DateTime(2026, 7, 30, 12);
  final tasks = [
    _task('today', DateTime(2026, 7, 30, 18)),
    _task('tomorrow', DateTime(2026, 7, 31, 9)),
    _task('day-seven', DateTime(2026, 8, 6, 18)),
    _task('past', DateTime(2026, 7, 29, 9)),
    _task('later', DateTime(2026, 8, 7, 9)),
  ];

  test('TaskStats distinguishes tomorrow from future seven days', () {
    final stats = TaskStats.fromTasks(tasks, now: now);
    expect(stats.today, 1);
    expect(stats.tomorrow, 1);
    expect(stats.upcoming, 2);
  });

  test('tomorrow and next7days filters align with sidebar counters', () {
    expect(
      applyTaskFilter(
        tasks,
        TaskFilter(dueRange: 'tomorrow'),
        null,
        now,
      ).map((task) => task.id),
      ['tomorrow'],
    );
    expect(
      applyTaskFilter(
        tasks,
        TaskFilter(dueRange: 'next7days'),
        null,
        now,
      ).map((task) => task.id),
      ['tomorrow', 'day-seven'],
    );
  });

  test(
    'fixed timezone wall-clock date aligns sidebar counters and filters',
    () {
      final fixedZoneTasks = [
        _task(
          'los-angeles-today',
          DateTime.utc(2026, 7, 31, 2),
          fixedTimezone: true,
          timeZone: 'America/Los_Angeles',
        ),
        _task(
          'all-day-tomorrow',
          DateTime.utc(2026, 7, 31),
          fixedTimezone: true,
          timeZone: 'America/Los_Angeles',
          allDay: true,
        ),
      ];

      final stats = TaskStats.fromTasks(fixedZoneTasks, now: now);
      expect(stats.today, 1);
      expect(stats.tomorrow, 1);
      expect(
        applyTaskFilter(
          fixedZoneTasks,
          TaskFilter(dueRange: 'today'),
          null,
          now,
        ).map((task) => task.id),
        ['los-angeles-today'],
      );
      expect(
        applyTaskFilter(
          fixedZoneTasks,
          TaskFilter(dueRange: 'tomorrow'),
          null,
          now,
        ).map((task) => task.id),
        ['all-day-tomorrow'],
      );
    },
  );
}

TodoTask _task(
  String id,
  DateTime dueAt, {
  bool fixedTimezone = false,
  String? timeZone,
  bool allDay = false,
}) {
  final stamp = DateTime(2026, 7, 1);
  return TodoTask(
    id: id,
    listId: 'inbox',
    title: id,
    completed: false,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: dueAt,
    allDay: allDay,
    timeZone: timeZone,
    fixedTimezone: fixedTimezone,
    updatedAt: stamp,
    createdAt: stamp,
  );
}
