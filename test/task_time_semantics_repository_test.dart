import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
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
}
