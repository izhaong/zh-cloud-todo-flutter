import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';

void main() {
  test(
    'upgrades schema 4 scheduling and completion records across restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b2_migration_',
      );
      final databaseFile = File('${directory.path}/todo.sqlite');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final beforeUpgrade = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final createdAt = DateTime.utc(2026, 7, 16, 8);
      await beforeUpgrade
          .into(beforeUpgrade.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-1',
              listId: 'inbox',
              title: '迁移中的时间任务',
              startAt: Value(DateTime.utc(2026, 7, 16, 23, 30)),
              endAt: Value(DateTime.utc(2026, 7, 17, 1)),
              dueAt: Value(DateTime.utc(2026, 7, 17, 1)),
              allDay: const Value(true),
              timeZone: const Value('America/Los_Angeles'),
              fixedTimezone: const Value(true),
              updatedAt: createdAt,
              createdAt: createdAt,
            ),
          );
      await beforeUpgrade
          .into(beforeUpgrade.todoReminders)
          .insert(
            TodoRemindersCompanion.insert(
              id: 'reminder-1',
              taskId: 'task-1',
              remindAt: DateTime.utc(2026, 7, 16, 23),
              anchorType: const Value('END'),
              offsetMinutes: const Value(15),
              persistent: const Value(true),
              intervalMinutes: const Value(30),
              timeZone: const Value('America/Los_Angeles'),
              fixedTimezone: const Value(true),
              clientMutationId: const Value('reminder-mutation'),
              updatedAt: createdAt,
              createdAt: createdAt,
            ),
          );
      await beforeUpgrade
          .into(beforeUpgrade.todoRepeatRules)
          .insert(
            TodoRepeatRulesCompanion.insert(
              id: 'repeat-rule-1',
              taskId: 'task-1',
              freq: 'CUSTOM',
              interval: const Value(2),
              byDay: const Value('1,3,5'),
              monthDay: const Value(16),
              startAt: Value(DateTime.utc(2026, 7, 16, 23, 30)),
              countLimit: const Value(8),
              enabled: const Value(true),
              repeatMode: const Value('ON_COMPLETE'),
              timeZone: const Value('America/Los_Angeles'),
              updatedAt: createdAt,
              createdAt: createdAt,
            ),
          );
      await beforeUpgrade.close();

      _downgradeToSchema4(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data['user_version'], 10);
      await upgraded.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(reopened.close);

      final task = await (reopened.select(
        reopened.todoTasks,
      )..where((row) => row.id.equals('task-1'))).getSingle();
      final reminder = await (reopened.select(
        reopened.todoReminders,
      )..where((row) => row.id.equals('reminder-1'))).getSingle();
      final repeatRule = await (reopened.select(
        reopened.todoRepeatRules,
      )..where((row) => row.id.equals('repeat-rule-1'))).getSingle();

      expect(task.startAt?.toUtc(), DateTime.utc(2026, 7, 16, 23, 30));
      expect(task.endAt?.toUtc(), DateTime.utc(2026, 7, 17, 1));
      expect(task.dueAt?.toUtc(), DateTime.utc(2026, 7, 17, 1));
      expect(task.allDay, isFalse);
      expect(task.timeZone, isNull);
      expect(task.fixedTimezone, isFalse);
      expect(task.completedAt, isNull);
      expect(task.repeatParentTaskId, isNull);
      expect(task.repeatRuleId, isNull);
      expect(task.repeatOccurrenceAt, isNull);
      expect(reminder.anchorType, 'ABSOLUTE');
      expect(reminder.remindAt.toUtc(), DateTime.utc(2026, 7, 16, 23));
      expect(reminder.status, 'PENDING');
      expect(reminder.offsetMinutes, isNull);
      expect(reminder.persistent, isFalse);
      expect(reminder.intervalMinutes, isNull);
      expect(reminder.timeZone, isNull);
      expect(reminder.fixedTimezone, isFalse);
      expect(reminder.clientMutationId, isNull);
      expect(repeatRule.monthDay, isNull);
      expect(repeatRule.freq, 'CUSTOM');
      expect(repeatRule.interval, 2);
      expect(repeatRule.byDay, '1,3,5');
      expect(repeatRule.startAt, isNull);
      expect(repeatRule.countLimit, isNull);
      expect(repeatRule.enabled, isTrue);
      expect(repeatRule.repeatMode, 'ON_DUE');
      expect(repeatRule.timeZone, isNull);
    },
  );
}

void _downgradeToSchema4(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('''
      CREATE TABLE todo_tasks_v4 (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        list_id TEXT NOT NULL,
        parent_task_id TEXT NULL,
        title TEXT NOT NULL,
        description TEXT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        start_at INTEGER NULL,
        end_at INTEGER NULL,
        due_at INTEGER NULL,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO todo_tasks_v4 (
        id, server_id, list_id, parent_task_id, title, description, completed,
        priority, is_pinned, sort_order, start_at, end_at, due_at, updated_at,
        created_at
      ) SELECT
        id, server_id, list_id, parent_task_id, title, description, completed,
        priority, is_pinned, sort_order, start_at, end_at, due_at, updated_at,
        created_at
      FROM todo_tasks
    ''');
    database.execute('DROP TABLE todo_tasks');
    database.execute('ALTER TABLE todo_tasks_v4 RENAME TO todo_tasks');
    database.execute('''
      CREATE TABLE todo_reminders_v4 (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        task_id TEXT NOT NULL,
        remind_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO todo_reminders_v4 (
        id, server_id, task_id, remind_at, status, updated_at, created_at
      ) SELECT id, server_id, task_id, remind_at, status, updated_at, created_at
      FROM todo_reminders
    ''');
    database.execute('DROP TABLE todo_reminders');
    database.execute('ALTER TABLE todo_reminders_v4 RENAME TO todo_reminders');
    database.execute('''
      CREATE TABLE todo_repeat_rules_v4 (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        task_id TEXT NOT NULL,
        freq TEXT NOT NULL,
        interval INTEGER NOT NULL DEFAULT 1,
        by_day TEXT NULL,
        until INTEGER NULL,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO todo_repeat_rules_v4 (
        id, server_id, task_id, freq, interval, by_day, until, updated_at, created_at
      ) SELECT id, server_id, task_id, freq, interval, by_day, until, updated_at,
        created_at
      FROM todo_repeat_rules
    ''');
    database.execute('DROP TABLE todo_repeat_rules');
    database.execute(
      'ALTER TABLE todo_repeat_rules_v4 RENAME TO todo_repeat_rules',
    );
    database.execute('PRAGMA user_version = 4');
  } finally {
    database.dispose();
  }
}
