import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';

void main() {
  test(
    'upgrades schema 13 with assignee columns and preserves tasks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b3_schema13_',
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
      final now = DateTime.utc(2026, 7, 30, 8);
      await beforeUpgrade
          .into(beforeUpgrade.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-before-assignee-filter',
              listId: 'inbox',
              title: '迁移前任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await beforeUpgrade.close();
      _downgradeToSchema13WithoutAssignee(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data['user_version'], 15);
      final task = await upgraded.select(upgraded.todoTasks).getSingle();
      expect(task.title, '迁移前任务');
      expect(task.assigneeUserId, isNull);
      expect(task.assigneeUserName, isNull);
    },
  );

  test(
    'upgrades the released B1 schema 9 without losing its aggregate tables',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b1_schema9_',
      );
      final databaseFile = File('${directory.path}/todo.sqlite');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      _createB1Schema9(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data['user_version'], 15);

      final taskColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_tasks)')
          .get();
      final columnNames = taskColumns.map((row) => row.data['name']).toSet();
      expect(
        columnNames,
        containsAll(<String>{
          'cancelled',
          'all_day',
          'time_zone',
          'fixed_timezone',
          'completed_at',
          'repeat_parent_task_id',
          'repeat_rule_id',
          'repeat_occurrence_at',
          'assignee_user_id',
          'assignee_user_name',
        }),
      );

      final reminderColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_reminders)')
          .get();
      expect(
        reminderColumns.map((row) => row.data['name']),
        containsAll(<String>{
          'anchor_type',
          'offset_minutes',
          'fired_at',
          'persistent',
          'interval_minutes',
          'time_zone',
          'fixed_timezone',
          'client_mutation_id',
        }),
      );
      final repeatRuleColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_repeat_rules)')
          .get();
      expect(
        repeatRuleColumns.map((row) => row.data['name']),
        containsAll(<String>{
          'month_day',
          'start_at',
          'count_limit',
          'enabled',
          'repeat_mode',
          'time_zone',
          'selected_dates_json',
        }),
      );

      final preservedTables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('todo_checklist_items', 'todo_attachments', 'todo_activities', "
            "'todo_templates')",
          )
          .get();
      expect(preservedTables.map((row) => row.data['name']), hasLength(4));
      final b3Dependencies = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('todo_lists', 'todo_tags', 'todo_task_tags')",
          )
          .get();
      expect(b3Dependencies.map((row) => row.data['name']), hasLength(3));
      final tagColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_tags)')
          .get();
      expect(tagColumns.map((row) => row.data['name']), contains('parent_id'));
      final filterColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_filters)')
          .get();
      expect(
        filterColumns.map((row) => row.data['name']),
        containsAll(<String>{'sort_orders_json', 'is_smart', 'is_pinned'}),
      );
      final indexTable = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'todo_search_index'",
          )
          .getSingle();
      expect(indexTable.data['name'], 'todo_search_index');
    },
  );

  test(
    'upgrades schema 14 with selected dates and preserves repeat rules',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b2_schema14_',
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
      final createdAt = DateTime.utc(2026, 7, 30, 9);
      await beforeUpgrade
          .into(beforeUpgrade.todoRepeatRules)
          .insert(
            TodoRepeatRulesCompanion.insert(
              id: 'repeat-rule-before-b2-b3-merge',
              taskId: 'task-1',
              freq: 'CUSTOM',
              byDay: const Value('1,3,5'),
              updatedAt: createdAt,
              createdAt: createdAt,
            ),
          );
      await beforeUpgrade.close();
      _downgradeToSchema14WithoutSelectedDates(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final rule = await upgraded.select(upgraded.todoRepeatRules).getSingle();

      expect(version.data['user_version'], 15);
      expect(rule.id, 'repeat-rule-before-b2-b3-merge');
      expect(rule.byDay, '1,3,5');
      expect(rule.selectedDatesJson, isNull);
    },
  );

  test('upgrades schema 10 repeat rules without losing rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_b2_schema10_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final createdAt = DateTime.utc(2026, 7, 13, 8);
    await beforeUpgrade
        .into(beforeUpgrade.todoRepeatRules)
        .insert(
          TodoRepeatRulesCompanion.insert(
            id: 'repeat-rule-1',
            taskId: 'task-1',
            freq: 'CUSTOM',
            byDay: const Value('1,3,5'),
            startAt: Value(DateTime(2026, 7, 13, 9, 30)),
            repeatMode: const Value('ON_DUE'),
            timeZone: const Value('Asia/Shanghai'),
            updatedAt: createdAt,
            createdAt: createdAt,
          ),
        );
    await beforeUpgrade.close();
    _downgradeToSchema10(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final rule = await upgraded.select(upgraded.todoRepeatRules).getSingle();

    expect(version.data['user_version'], 15);
    expect(rule.freq, 'CUSTOM');
    expect(rule.byDay, '1,3,5');
    expect(rule.repeatMode, 'ON_DUE');
    expect(rule.timeZone, 'Asia/Shanghai');
    expect(rule.selectedDatesJson, isNull);
  });

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
      expect(version.data['user_version'], 15);
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
      expect(repeatRule.selectedDatesJson, isNull);
    },
  );
}

void _downgradeToSchema10(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute(
      'ALTER TABLE todo_repeat_rules DROP COLUMN selected_dates_json',
    );
    database.execute('PRAGMA user_version = 10');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema13WithoutAssignee(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('DROP INDEX IF EXISTS idx_todo_tasks_b3_assignee_filter');
    database.execute('ALTER TABLE todo_tasks DROP COLUMN assignee_user_name');
    database.execute('ALTER TABLE todo_tasks DROP COLUMN assignee_user_id');
    database.execute('PRAGMA user_version = 13');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema14WithoutSelectedDates(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute(
      'ALTER TABLE todo_repeat_rules DROP COLUMN selected_dates_json',
    );
    database.execute('PRAGMA user_version = 14');
  } finally {
    database.dispose();
  }
}

void _createB1Schema9(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('''
      CREATE TABLE todo_tasks (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        list_id TEXT NOT NULL,
        parent_task_id TEXT NULL,
        title TEXT NOT NULL,
        description TEXT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        cancelled INTEGER NOT NULL DEFAULT 0,
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
      CREATE TABLE todo_checklist_items (
        id TEXT NOT NULL PRIMARY KEY, server_id INTEGER NULL, task_id TEXT NOT NULL,
        title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE todo_reminders (
        id TEXT NOT NULL PRIMARY KEY, server_id INTEGER NULL, task_id TEXT NOT NULL,
        remind_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'PENDING',
        updated_at INTEGER NOT NULL, created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE todo_repeat_rules (
        id TEXT NOT NULL PRIMARY KEY, server_id INTEGER NULL, task_id TEXT NOT NULL,
        freq TEXT NOT NULL, interval INTEGER NOT NULL DEFAULT 1, by_day TEXT NULL,
        until INTEGER NULL, updated_at INTEGER NOT NULL, created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE todo_attachments (
        id TEXT NOT NULL PRIMARY KEY, server_id INTEGER NULL, task_id TEXT NOT NULL,
        name TEXT NOT NULL, local_path TEXT NULL, remote_url TEXT NULL,
        mime_type TEXT NOT NULL, size INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'queued',
        error TEXT NULL, updated_at INTEGER NOT NULL, created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE todo_activities (
        server_id INTEGER NOT NULL PRIMARY KEY, task_server_id INTEGER NOT NULL,
        actor_user_id INTEGER NULL, actor_user_name TEXT NULL, action TEXT NOT NULL,
        detail TEXT NULL, occurred_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE todo_templates (
        id TEXT NOT NULL PRIMARY KEY, server_id INTEGER NULL, name TEXT NOT NULL,
        content_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'queued',
        updated_at INTEGER NOT NULL, created_at INTEGER NOT NULL
      )
    ''');
    database.execute('PRAGMA user_version = 9');
  } finally {
    database.dispose();
  }
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
