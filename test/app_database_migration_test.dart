import 'dart:io';

import 'package:drift/drift.dart' show OrderingMode, OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';

void main() {
  test('upgrades schema 21 with task Sections and preserves tasks', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_section_schema21_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 7, 30, 16);
    await beforeUpgrade.batch((batch) {
      batch.insert(
        beforeUpgrade.todoLists,
        TodoListsCompanion.insert(
          id: 'list-before-section',
          name: '工作',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        beforeUpgrade.todoTasks,
        TodoTasksCompanion.insert(
          id: 'task-before-section',
          listId: 'list-before-section',
          title: '迁移前任务',
          updatedAt: now,
          createdAt: now,
        ),
      );
    });
    await beforeUpgrade.close();
    _downgradeToSchema21WithoutSections(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final task = await upgraded.select(upgraded.todoTasks).getSingle();
    final sectionTable = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'todo_task_sections'",
        )
        .getSingle();
    final taskColumns = await upgraded
        .customSelect("PRAGMA table_info('todo_tasks')")
        .get();

    expect(version.data['user_version'], 31);
    expect(task.title, '迁移前任务');
    expect(sectionTable.data['name'], 'todo_task_sections');
    expect(taskColumns.map((row) => row.data['name']), contains('section_id'));
  });

  test('v22→v23 升级把勾过固定的存量任务回填成「固定时间」，没勾的仍是浮动', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_time_mode_backfill_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final seeded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 9, 20, 8);
    await seeded.batch((batch) {
      batch.insert(
        seeded.todoLists,
        TodoListsCompanion.insert(
          id: 'list-time-mode',
          name: '工作',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        seeded.todoTasks,
        TodoTasksCompanion.insert(
          id: 'task-fixed',
          listId: 'list-time-mode',
          title: '勾过固定的老任务',
          fixedTimezone: const Value(true),
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        seeded.todoTasks,
        TodoTasksCompanion.insert(
          id: 'task-plain',
          listId: 'list-time-mode',
          title: '没勾固定的老任务',
          updatedAt: now,
          createdAt: now,
        ),
      );
    });
    await seeded.close();

    // 退回"表上还没有 time_mode 这一列"的 v22 形状：新列由 onUpgrade 自己加回来，
    // 这样测到的才是"加列 + 回填"这一整条路，而不是直接建好的 v23 库。
    final legacy = sqlite.sqlite3.open(databaseFile.path);
    try {
      legacy.execute('ALTER TABLE todo_tasks DROP COLUMN time_mode');
      legacy.execute('PRAGMA user_version = 22');
    } finally {
      legacy.dispose();
    }

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final rows = await upgraded
        .customSelect('SELECT id, time_mode FROM todo_tasks ORDER BY id')
        .get();

    expect(version.data['user_version'], 31);
    expect(
      rows.map((row) => '${row.data['id']}=${row.data['time_mode']}'),
      containsAll(<String>['task-fixed=2', 'task-plain=0']),
    );
  });

  test(
    'upgrades schema 20 by localizing persisted filter references',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b3_schema20_',
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
      final now = DateTime.utc(2026, 7, 30, 13);
      await beforeUpgrade.batch((batch) {
        batch.insert(
          beforeUpgrade.todoLists,
          TodoListsCompanion.insert(
            id: 'local-list',
            serverId: const Value(101),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          beforeUpgrade.todoTags,
          TodoTagsCompanion.insert(
            id: 'local-tag',
            serverId: const Value(201),
            name: '工作',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          beforeUpgrade.todoFilters,
          TodoFiltersCompanion.insert(
            id: 'local-filter',
            name: '项目工作',
            conditionJson: '{"listIds":[101],"tagIds":[201],"priorities":[3]}',
            updatedAt: now,
            createdAt: now,
          ),
        );
      });
      await beforeUpgrade.close();
      _downgradeToSchema20(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final filter = await upgraded.select(upgraded.todoFilters).getSingle();

      expect(version.data['user_version'], 31);
      expect(filter.conditionJson, contains('"local-list"'));
      expect(filter.conditionJson, contains('"local-tag"'));
      expect(filter.conditionJson, isNot(contains('[101]')));
      expect(filter.conditionJson, isNot(contains('[201]')));
    },
  );

  test(
    'upgrades schema 19 with local folder UUIDs and backfills existing lists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b3_schema19_',
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
      final now = DateTime.utc(2026, 7, 30, 10);
      await beforeUpgrade.batch((batch) {
        batch.insert(
          beforeUpgrade.todoFolders,
          TodoFoldersCompanion.insert(
            id: 'folder-before-local-reference',
            serverId: const Value(88),
            name: '迁移前文件夹',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          beforeUpgrade.todoLists,
          TodoListsCompanion.insert(
            id: 'list-before-local-reference',
            name: '迁移前清单',
            folderId: const Value(88),
            updatedAt: now,
            createdAt: now,
          ),
        );
      });
      await beforeUpgrade.close();
      _downgradeToSchema19WithoutFolderLocalId(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final list = await upgraded.listByLocalId('list-before-local-reference');

      expect(version.data['user_version'], 31);
      expect(list?.folderId, 88);
      expect(list?.folderLocalId, 'folder-before-local-reference');
    },
  );

  test(
    'upgrades schema 18 with list access defaults and preserves lists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b4_schema18_',
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
      final now = DateTime.utc(2026, 7, 30, 9);
      await beforeUpgrade
          .into(beforeUpgrade.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-before-access-role',
              name: '迁移前清单',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await beforeUpgrade.close();
      _downgradeToSchema18WithoutListAccess(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final access = await upgraded
          .customSelect(
            'SELECT id, access_role, writable FROM todo_lists '
            "WHERE id = 'list-before-access-role'",
          )
          .getSingle();

      expect(version.data['user_version'], 31);
      expect(access.data['id'], 'list-before-access-role');
      expect(access.data['access_role'], 'owner');
      expect(access.data['writable'], 1);
    },
  );

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
      expect(version.data['user_version'], 31);
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
      expect(version.data['user_version'], 31);

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
      final folderColumns = await upgraded
          .customSelect('PRAGMA table_info(todo_folders)')
          .get();
      expect(
        folderColumns.map((row) => row.data['name']),
        contains('parent_id'),
      );
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

      expect(version.data['user_version'], 31);
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

    expect(version.data['user_version'], 31);
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
              timeMode: const Value(2),
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
      expect(version.data['user_version'], 31);
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

  test(
    'upgrades schema 15 with board preferences table and preserves tasks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b4_schema15_',
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
      final now = DateTime.utc(2026, 7, 30, 10);
      await beforeUpgrade
          .into(beforeUpgrade.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-before-board-preference',
              listId: 'inbox',
              title: '迁移前看板任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await beforeUpgrade.close();
      _downgradeToSchema15WithoutBoardPreferences(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final task = await upgraded.select(upgraded.todoTasks).getSingle();
      final boardTable = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'todo_board_preferences'",
          )
          .getSingle();

      expect(version.data['user_version'], 31);
      expect(task.title, '迁移前看板任务');
      expect(boardTable.data['name'], 'todo_board_preferences');
    },
  );

  test('v23→v24 升级给提醒加 time_mode 并回填勾过固定的老提醒', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_reminder_time_mode_backfill_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final seeded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 9, 20, 8);
    await seeded.batch((batch) {
      batch.insert(
        seeded.todoLists,
        TodoListsCompanion.insert(
          id: 'list-reminder-time-mode',
          name: '工作',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        seeded.todoTasks,
        TodoTasksCompanion.insert(
          id: 'task-with-reminders',
          listId: 'list-reminder-time-mode',
          title: '带提醒的老任务',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        seeded.todoReminders,
        TodoRemindersCompanion.insert(
          id: 'reminder-fixed',
          taskId: 'task-with-reminders',
          remindAt: DateTime.utc(2026, 10, 1, 9),
          fixedTimezone: const Value(true),
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        seeded.todoReminders,
        TodoRemindersCompanion.insert(
          id: 'reminder-plain',
          taskId: 'task-with-reminders',
          remindAt: DateTime.utc(2026, 10, 1, 10),
          updatedAt: now,
          createdAt: now,
        ),
      );
    });
    await seeded.close();

    // 退回"提醒表上还没有 time_mode 这一列"的 v23 形状，测的是加列 + 回填整条路。
    final legacy = sqlite.sqlite3.open(databaseFile.path);
    try {
      legacy.execute('ALTER TABLE todo_reminders DROP COLUMN time_mode');
      legacy.execute('PRAGMA user_version = 23');
    } finally {
      legacy.dispose();
    }

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final rows = await upgraded
        .customSelect('SELECT id, time_mode FROM todo_reminders ORDER BY id')
        .get();

    expect(version.data['user_version'], 31);
    expect(
      rows.map((row) => '${row.data['id']}=${row.data['time_mode']}'),
      containsAll(<String>['reminder-fixed=2', 'reminder-plain=0']),
    );
  });

  test('v24→v25 升级给清单加 is_pinned，存量清单落未置顶且行不丢', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_list_pinned_backfill_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final seeded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 9, 28, 8);
    await seeded.batch((batch) {
      batch.insert(
        seeded.todoLists,
        TodoListsCompanion.insert(
          id: 'list-pin-migration',
          name: '工作',
          sortOrder: const Value(3),
          updatedAt: now,
          createdAt: now,
        ),
      );
    });
    await seeded.close();

    // 退回"清单表上还没有 is_pinned 这一列"的 v24 形状，测的是加列整条路。
    final legacy = sqlite.sqlite3.open(databaseFile.path);
    try {
      legacy.execute('ALTER TABLE todo_lists DROP COLUMN is_pinned');
      legacy.execute('PRAGMA user_version = 24');
    } finally {
      legacy.dispose();
    }

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final rows = await upgraded
        .customSelect('SELECT id, name, sort_order, is_pinned FROM todo_lists')
        .get();

    expect(version.data['user_version'], 31);
    expect(rows, hasLength(1), reason: '加列不能丢存量清单');
    expect(rows.single.data['id'], 'list-pin-migration');
    expect(rows.single.data['sort_order'], 3, reason: '原有 sortOrder 不能被迁移改写');
    expect(
      rows.single.data['is_pinned'],
      0,
      reason: '存量清单本来没有置顶位，未置顶就是它们的真实状态，不需要回填成别的值',
    );
  });

  test('v25→v26 升级给标签加 is_pinned，存量标签落未置顶且行不丢', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_tag_pinned_migration_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final seeded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 10, 3, 8);
    await seeded.batch((batch) {
      batch.insert(
        seeded.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-pin-migration',
          name: '重要',
          color: const Value('#E53935'),
          updatedAt: now,
          createdAt: now,
        ),
      );
    });
    await seeded.close();

    // 退回「标签表上还没有 is_pinned 这一列」的 v25 形状，测的是加列整条路。
    final legacy = sqlite.sqlite3.open(databaseFile.path);
    try {
      legacy.execute('ALTER TABLE todo_tags DROP COLUMN is_pinned');
      legacy.execute('PRAGMA user_version = 25');
    } finally {
      legacy.dispose();
    }

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final rows = await upgraded
        .customSelect('SELECT id, name, color, is_pinned FROM todo_tags')
        .get();

    expect(version.data['user_version'], 31);
    expect(rows, hasLength(1), reason: '加列不能丢存量标签');
    expect(rows.single.data['id'], 'tag-pin-migration');
    expect(rows.single.data['color'], '#E53935', reason: '原有颜色不能被迁移改写');
    expect(
      rows.single.data['is_pinned'],
      0,
      reason: '存量标签本来没有置顶位，未置顶就是它们的真实状态，不需要回填成别的值',
    );
  });

  test(
    'upgrades schema 16 with recovery metadata and recommendation cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zh_cloud_todo_b5_schema16_',
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
      final now = DateTime.utc(2026, 7, 30, 11);
      await beforeUpgrade
          .into(beforeUpgrade.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-before-reliability-closeout',
              listId: 'inbox',
              title: '迁移前可靠性任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await beforeUpgrade
          .into(beforeUpgrade.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'mutation-before-reliability-closeout',
              entity: 'task',
              op: 'upsert',
              entityLocalId: const Value('task-before-reliability-closeout'),
              payloadJson: '{"title":"迁移前可靠性任务"}',
              createdAt: now,
            ),
          );
      await beforeUpgrade.close();
      _downgradeToSchema16WithoutReliabilityColumns(databaseFile);

      final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      final task = await upgraded.select(upgraded.todoTasks).getSingle();
      final change = await upgraded
          .select(upgraded.todoSyncChanges)
          .getSingle();
      final recommendationTable = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'todo_recommendations'",
          )
          .getSingle();

      expect(version.data['user_version'], 31);
      expect(task.title, '迁移前可靠性任务');
      expect(change.status, 'queued');
      expect(change.nextAttemptAt, isNull);
      expect(change.failureReason, isNull);
      expect(recommendationTable.data['name'], 'todo_recommendations');
    },
  );

  test('v26→v28 给 todo_tags 加 sort_order，旧数据全 0、界面顺序不倒退', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_tag_sort_order_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final now = DateTime.utc(2026, 10, 1, 9);
    await beforeUpgrade.batch((batch) {
      batch.insert(
        beforeUpgrade.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-a',
          name: '专注',
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      );
      batch.insert(
        beforeUpgrade.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-b',
          name: '评审',
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      );
      batch.insert(
        beforeUpgrade.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-c',
          name: '跟进',
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      );
    });
    await beforeUpgrade.close();
    _downgradeToSchema26WithoutTagSortOrder(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await upgraded
        .customSelect("PRAGMA table_info('todo_tags')")
        .get();

    expect(version.data['user_version'], 31);
    expect(columns.map((row) => row.data['name']), contains('sort_order'));

    // watchAll/getAll 的排序键（isPinned DESC, sortOrder DESC, createdAt ASC）。
    final rows =
        await (upgraded.select(upgraded.todoTags)..orderBy([
              (t) =>
                  OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
              (t) => OrderingTerm(
                expression: t.sortOrder,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.createdAt),
            ]))
            .get();
    expect(
      rows.map((r) => r.id).toList(),
      ['tag-a', 'tag-b', 'tag-c'],
      reason: '迁移后全 0、并列塌到 createdAt ASC ⇒ 升级前后界面顺序一致，不回填、不推全量',
    );
    expect(rows.map((r) => r.sortOrder), everyElement(0));
  });

  test('v27→v28 给 todo_recommendations 加 #271 契约三列，存量行为 null、不回填', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_recommend_contract_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await beforeUpgrade
        .into(beforeUpgrade.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '升级前缓存的推荐',
            reasonCode: 'LONG_UNFINISHED',
            reason: '长时间未完成',
            score: 800,
            refreshedAt: DateTime.utc(2026, 10, 1, 9),
          ),
        );
    await beforeUpgrade.close();
    _downgradeToSchema27WithoutRecommendationContractColumns(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await upgraded
        .customSelect("PRAGMA table_info('todo_recommendations')")
        .get();
    final names = columns.map((row) => row.data['name']).toList();

    expect(version.data['user_version'], 31);
    expect(
      names,
      containsAll(['created_at', 'reschedule_count', 'unfinished_days']),
    );

    final rows = await upgraded.select(upgraded.todoRecommendations).get();
    expect(rows.single.taskServerId, 7);
    expect(
      rows.single.createdAt,
      isNull,
      reason: '三列来自服务端契约，缓存旧行没有就不猜，等下次 refresh 整表替换',
    );
    expect(rows.single.rescheduleCount, isNull);
    expect(rows.single.unfinishedDays, isNull);
  });

  test('v28→v29 给 todo_lists 加 color，存量行为 null、不回填', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_list_color_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final now = DateTime.utc(2026, 10, 1, 9);
    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await beforeUpgrade
        .into(beforeUpgrade.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-before-color',
            name: '工作',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await beforeUpgrade.close();
    _downgradeToSchema28WithoutListColor(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await upgraded
        .customSelect("PRAGMA table_info('todo_lists')")
        .get();
    final names = columns.map((row) => row.data['name']).toList();

    expect(version.data['user_version'], 31);
    expect(names, contains('color'));

    final rows = await upgraded.select(upgraded.todoLists).get();
    expect(rows.single.name, '工作');
    expect(
      rows.single.color,
      isNull,
      reason: '存量清单本来就没有颜色，null 即真实状态；服务端有值时下次 pull 补上',
    );
  });

  test('v29→v30 给 todo_lists 加四属性列，存量行走默认值、行不丢', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_list_properties_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final now = DateTime.utc(2026, 10, 1, 9);
    final beforeUpgrade = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await beforeUpgrade
        .into(beforeUpgrade.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-before-properties',
            name: '工作',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await beforeUpgrade.close();
    _downgradeToSchema29WithoutListPropertyColumns(databaseFile);

    final upgraded = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await upgraded
        .customSelect("PRAGMA table_info('todo_lists')")
        .get();
    final names = columns.map((row) => row.data['name']).toList();

    expect(version.data['user_version'], 31);
    expect(
      names,
      containsAll([
        'icon',
        'background_type',
        'background_value',
        'show_in_smart_list',
      ]),
    );

    final rows = await upgraded.select(upgraded.todoLists).get();
    expect(rows.single.name, '工作');
    expect(rows.single.icon, isNull, reason: '不回填，服务端有值时下次 pull 补上');
    expect(rows.single.backgroundType, 'theme', reason: '默认即改造前真实行为：跟随主题');
    expect(rows.single.backgroundValue, isNull);
    expect(rows.single.showInSmartList, isTrue, reason: '默认显示，不悄悄藏清单');
  });
}

void _downgradeToSchema29WithoutListPropertyColumns(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('ALTER TABLE todo_lists DROP COLUMN icon');
    database.execute('ALTER TABLE todo_lists DROP COLUMN background_type');
    database.execute('ALTER TABLE todo_lists DROP COLUMN background_value');
    database.execute('ALTER TABLE todo_lists DROP COLUMN show_in_smart_list');
    database.execute('PRAGMA user_version = 29');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema28WithoutListColor(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('ALTER TABLE todo_lists DROP COLUMN color');
    database.execute('PRAGMA user_version = 28');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema27WithoutRecommendationContractColumns(
  File databaseFile,
) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('ALTER TABLE todo_recommendations DROP COLUMN created_at');
    database.execute(
      'ALTER TABLE todo_recommendations DROP COLUMN reschedule_count',
    );
    database.execute(
      'ALTER TABLE todo_recommendations DROP COLUMN unfinished_days',
    );
    database.execute('PRAGMA user_version = 27');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema21WithoutSections(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('DROP TABLE todo_task_sections');
    database.execute('ALTER TABLE todo_tasks DROP COLUMN section_id');
    database.execute('PRAGMA user_version = 21');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema20(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('PRAGMA user_version = 20');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema19WithoutFolderLocalId(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('PRAGMA foreign_keys = OFF');
    database.execute('ALTER TABLE todo_lists RENAME TO todo_lists_schema20');
    database.execute('''
      CREATE TABLE todo_lists (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        name TEXT NOT NULL,
        folder_id INTEGER NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        access_role TEXT NOT NULL DEFAULT 'owner',
        writable INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO todo_lists (
        id, server_id, name, folder_id, sort_order, access_role, writable,
        updated_at, created_at
      )
      SELECT
        id, server_id, name, folder_id, sort_order, access_role, writable,
        updated_at, created_at
      FROM todo_lists_schema20
    ''');
    database.execute('DROP TABLE todo_lists_schema20');
    database.execute('PRAGMA user_version = 19');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema18WithoutListAccess(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('PRAGMA foreign_keys = OFF');
    database.execute('ALTER TABLE todo_lists RENAME TO todo_lists_schema19');
    database.execute('''
      CREATE TABLE todo_lists (
        id TEXT NOT NULL PRIMARY KEY,
        server_id INTEGER NULL,
        name TEXT NOT NULL,
        folder_id INTEGER NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO todo_lists (
        id, server_id, name, folder_id, sort_order, updated_at, created_at
      )
      SELECT
        id, server_id, name, folder_id, sort_order, updated_at, created_at
      FROM todo_lists_schema19
    ''');
    database.execute('DROP TABLE todo_lists_schema19');
    database.execute('PRAGMA user_version = 18');
  } finally {
    database.dispose();
  }
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

void _downgradeToSchema15WithoutBoardPreferences(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('DROP TABLE todo_board_preferences');
    database.execute('PRAGMA user_version = 15');
  } finally {
    database.dispose();
  }
}

void _downgradeToSchema16WithoutReliabilityColumns(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('DROP TABLE todo_recommendations');
    database.execute(
      'ALTER TABLE todo_sync_changes DROP COLUMN failure_reason',
    );
    database.execute(
      'ALTER TABLE todo_sync_changes DROP COLUMN next_attempt_at',
    );
    database.execute('PRAGMA user_version = 16');
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

void _downgradeToSchema26WithoutTagSortOrder(File databaseFile) {
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    database.execute('ALTER TABLE todo_tags DROP COLUMN sort_order');
    database.execute('PRAGMA user_version = 26');
  } finally {
    database.dispose();
  }
}
