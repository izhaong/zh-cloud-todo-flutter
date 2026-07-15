import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_dispatch_action_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('rejects an end time that is not after the start time', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.create(
        listId: 'inbox',
        title: '无效时段',
        startAt: DateTime(2026, 7, 13, 10),
        endAt: DateTime(2026, 7, 13, 10),
      ),
      throwsArgumentError,
    );
  });

  test('rejects an invalid time range when updating a task', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));
    final task = await repository.create(listId: 'inbox', title: '可编辑时段');

    await expectLater(
      repository.update(
        task.id,
        startAt: DateTime(2026, 7, 13, 10),
        endAt: DateTime(2026, 7, 13, 9, 30),
      ),
      throwsArgumentError,
    );
  });

  test('persists an explicit non-all-day default in the task outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    final task = await repository.create(listId: 'inbox', title: '默认日期任务');
    final payload =
        jsonDecode(
              (await db.select(db.todoSyncChanges).getSingle()).payloadJson,
            )
            as Map<String, dynamic>;

    expect(task.toJson()['allDay'], isFalse);
    expect(payload['allDay'], isFalse);
  });

  test('persists an all-day choice when creating and editing a task', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    final task =
        await (repository as dynamic).create(
              listId: 'inbox',
              title: '全天活动',
              allDay: true,
            )
            as TodoTask;
    expect(task.toJson()['allDay'], isTrue);

    final edited =
        await (repository as dynamic).update(task.id, allDay: false)
            as TodoTask;
    expect(edited.toJson()['allDay'], isFalse);
    final payload =
        jsonDecode((await db.select(db.todoSyncChanges).get()).last.payloadJson)
            as Map<String, dynamic>;
    expect(payload['allDay'], isFalse);
  });

  test('preserves a fixed task timezone in Drift and task outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    final task = await repository.create(
      listId: 'inbox',
      title: '固定时区任务',
      startAt: DateTime.utc(2026, 7, 13, 16, 30),
      endAt: DateTime.utc(2026, 7, 13, 18),
      dueAt: DateTime.utc(2026, 7, 13, 18),
      timeZone: 'America/Los_Angeles',
      fixedTimezone: true,
    );
    final payload =
        jsonDecode(
              (await db.select(db.todoSyncChanges).getSingle()).payloadJson,
            )
            as Map<String, dynamic>;

    expect(task.timeZone, 'America/Los_Angeles');
    expect(task.fixedTimezone, isTrue);
    expect(payload['timeZone'], 'America/Los_Angeles');
    expect(payload['fixedTimezone'], isTrue);
  });

  test(
    'stores multiple reminder rules and their outbox mutations locally',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final reminders = ReminderRepository(db, SyncChangeQueue(db));

      final first = await reminders.create(
        taskId: 'task-1',
        fireAt: DateTime(2026, 7, 13, 9),
        anchorType: 'START',
        offsetMinutes: 15,
      );
      final second = await reminders.create(
        taskId: 'task-1',
        fireAt: DateTime(2026, 7, 13, 10),
        anchorType: 'END',
      );

      final rows = await db.select(db.todoReminders).get();
      final changes = await db.select(db.todoSyncChanges).get();
      final firstPayload =
          jsonDecode(changes.first.payloadJson) as Map<String, dynamic>;

      expect(rows, hasLength(2));
      expect(rows.map((row) => row.id), containsAll([first.id, second.id]));
      expect(first.anchorType, 'START');
      expect(first.offsetMinutes, 15);
      expect(first.clientMutationId, isNotEmpty);
      expect(changes, hasLength(2));
      expect(changes.first.clientMutationId, first.clientMutationId);
      expect(changes.first.entity, 'reminder');
      expect(firstPayload['taskId'], 'task-1');
      expect(firstPayload['fireAt'], isNotNull);
      expect(firstPayload['anchorType'], 'START');
    },
  );

  test('updates and deletes reminder rules through the outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final reminders = ReminderRepository(db, SyncChangeQueue(db));

    final first = await reminders.create(
      taskId: 'task-1',
      fireAt: DateTime(2026, 7, 13, 9),
    );
    final second = await reminders.create(
      taskId: 'task-1',
      fireAt: DateTime(2026, 7, 13, 10),
    );

    final updated = await reminders.update(
      id: first.id,
      fireAt: DateTime(2026, 7, 13, 9, 30),
      anchorType: 'END',
      persistent: true,
      intervalMinutes: 30,
      timeZone: 'Asia/Shanghai',
      fixedTimezone: true,
    );
    await reminders.remove(second.id);

    final rows = await db.select(db.todoReminders).get();
    final changes = await db.select(db.todoSyncChanges).get();
    final updatePayload =
        jsonDecode(changes[2].payloadJson) as Map<String, dynamic>;

    expect(rows, hasLength(1));
    expect(rows.single.id, first.id);
    expect(updated.anchorType, 'END');
    expect(updated.persistent, isTrue);
    expect(updated.intervalMinutes, 30);
    expect(updated.clientMutationId, isNot(first.clientMutationId));
    expect(changes, hasLength(4));
    expect(changes[2].op, 'upsert');
    expect(changes[2].clientMutationId, updated.clientMutationId);
    expect(updatePayload['fixedTimezone'], isTrue);
    expect(changes[3].op, 'delete');
    expect(changes[3].entityLocalId, second.id);
  });

  test('queues reminder dispatch actions by dispatch ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final actions = ReminderDispatchActionRepository(SyncChangeQueue(db));

    final mutationId = await actions.snooze(
      reminderDispatchId: 400,
      minutes: 10,
    );

    final change = await db.select(db.todoSyncChanges).getSingle();
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(change.entity, 'reminder_dispatch_action');
    expect(change.entityServerId, 400);
    expect(change.clientMutationId, mutationId);
    expect(payload, {
      'reminderDispatchId': 400,
      'action': 'snooze',
      'minutes': 10,
    });
  });

  test(
    'enables persistent reminder by the server rule ID through outbox',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final reminders = ReminderRepository(db, SyncChangeQueue(db));
      final reminder = await reminders.create(
        taskId: 'task-1',
        fireAt: DateTime(2026, 7, 13, 9),
      );
      await (db.update(db.todoReminders)
            ..where((t) => t.id.equals(reminder.id)))
          .write(const TodoRemindersCompanion(serverId: Value(600)));

      final updated = await reminders.enablePersistentByServerId(
        reminderServerId: 600,
        intervalMinutes: 30,
      );

      final changes = await db.select(db.todoSyncChanges).get();
      final payload =
          jsonDecode(changes.last.payloadJson) as Map<String, dynamic>;
      expect(updated.persistent, isTrue);
      expect(updated.intervalMinutes, 30);
      expect(changes.last.entityServerId, 600);
      expect(payload['persistent'], isTrue);
      expect(payload['intervalMinutes'], 30);
    },
  );

  test('stores a custom repeat rule and its skip through the outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));

    final rule = await repeats.save(
      taskId: 'task-1',
      frequency: 'CUSTOM',
      intervalValue: 2,
      weekdays: const [1, 3, 5],
      startAt: DateTime(2026, 7, 13, 9),
      repeatMode: 'ON_DUE',
      timeZone: 'Asia/Shanghai',
    );
    final skip = await repeats.skip(
      repeatRuleId: rule.id,
      taskId: 'task-1',
      occurrenceAt: DateTime(2026, 7, 15, 9),
    );

    final rules = await db.select(db.todoRepeatRules).get();
    final skips = await db.select(db.todoRepeatSkips).get();
    final changes = await db.select(db.todoSyncChanges).get();
    final rulePayload =
        jsonDecode(changes.first.payloadJson) as Map<String, dynamic>;
    final skipPayload =
        jsonDecode(changes.last.payloadJson) as Map<String, dynamic>;

    expect(rules, hasLength(1));
    expect(rule.repeatMode, 'ON_DUE');
    expect(rule.timeZone, 'Asia/Shanghai');
    expect(skips.single.id, skip.id);
    expect(changes.map((change) => change.entity), [
      'repeat_rule',
      'repeat_skip',
    ]);
    expect(rulePayload['frequency'], 'custom');
    expect(rulePayload['weekdays'], '1,3,5');
    expect(skipPayload['repeatRuleId'], rule.id);
  });

  test('rejects a custom repeat rule without explicit weekdays', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));

    await expectLater(
      repeats.save(
        taskId: 'task-1',
        frequency: 'CUSTOM',
        startAt: DateTime(2026, 7, 13, 9),
        repeatMode: 'ON_DUE',
      ),
      throwsArgumentError,
    );
  });

  test('stores all six supported repeat frequencies locally', () async {
    const frequencies = [
      'DAILY',
      'WEEKLY',
      'MONTHLY',
      'YEARLY',
      'WEEKDAY',
      'CUSTOM',
    ];
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));
    for (final frequency in frequencies) {
      final rule = await repeats.save(
        taskId: 'task-$frequency',
        frequency: frequency,
        weekdays: frequency == 'CUSTOM' ? const [1, 3, 5] : null,
        startAt: DateTime(2026, 7, 13, 9),
      );

      expect(rule.freq, frequency);
      if (frequency == 'WEEKDAY') {
        expect(rule.byDay, '1,2,3,4,5');
      }
    }
  });
}
