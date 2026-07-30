import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('缩进、反缩进和解除关联均写入本地父关系与 task outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedHierarchy(db);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await repository.indent('root-b', 'root-a');
    expect((await repository.getById('root-b'))?.parentTaskId, 'root-a');

    await repository.outdent('root-b');
    expect((await repository.getById('root-b'))?.parentTaskId, isNull);

    await repository.detach('child-a');
    expect((await repository.getById('child-a'))?.parentTaskId, isNull);

    final changes = await db.select(db.todoSyncChanges).get();
    expect(changes, hasLength(3));
    expect(
      changes.every((change) => change.entity == SyncEntities.task),
      isTrue,
    );
    expect(
      changes
          .map((change) => jsonDecode(change.payloadJson)['parentTaskId'])
          .toList(),
      ['root-a', null, null],
    );
  });

  test('缩进只能使用同层前序任务且失败不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedHierarchy(db);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.indent('root-b', 'child-a'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '缩进目标必须是同层任务',
        ),
      ),
    );

    expect((await repository.getById('root-b'))?.parentTaskId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('同父级手工排序要求完整且同层，并逐项写入 task outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedHierarchy(db);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await repository.reorderSiblings(
      listId: 'list-a',
      parentTaskId: 'root-a',
      orderedTaskIds: const ['child-b', 'child-a'],
    );

    final children = await db.childrenOf('root-a');
    expect(children.map((task) => task.id), ['child-b', 'child-a']);
    expect(children.map((task) => task.sortOrder), [0, 1]);
    final changes = await db.select(db.todoSyncChanges).get();
    expect(changes, hasLength(2));
    expect(changes.map((change) => change.entityLocalId), [
      'child-b',
      'child-a',
    ]);

    await db.delete(db.todoSyncChanges).go();
    await expectLater(
      repository.reorderSiblings(
        listId: 'list-a',
        parentTaskId: 'root-a',
        orderedTaskIds: const ['child-a'],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '必须包含同一父任务下的全部直接子任务',
        ),
      ),
    );
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('层级关系、同父级排序和 outbox 在文件型数据库重启后保留', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zh_cloud_todo_hierarchy_',
    );
    final databaseFile = File('${directory.path}/todo.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final first = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await _seedHierarchy(first);
    final repository = TaskRepository(first, SyncChangeQueue(first));
    await repository.indent('root-b', 'root-a');
    await repository.reorderSiblings(
      listId: 'list-a',
      parentTaskId: 'root-a',
      orderedTaskIds: const ['root-b', 'child-b', 'child-a'],
    );
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(reopened.close);
    final children = await reopened.childrenOf('root-a');
    final changes = await reopened.select(reopened.todoSyncChanges).get();

    expect(children.map((task) => task.id), ['root-b', 'child-b', 'child-a']);
    expect(children.map((task) => task.sortOrder), [0, 1, 2]);
    expect(changes, hasLength(4));
    expect(changes.every((change) => change.status == 'queued'), isTrue);
  });
}

Future<void> _seedHierarchy(AppDatabase db) async {
  final now = DateTime.utc(2026, 7, 30, 16);
  await db.batch((batch) {
    batch.insert(
      db.todoLists,
      TodoListsCompanion.insert(
        id: 'list-a',
        name: '项目',
        updatedAt: now,
        createdAt: now,
      ),
    );
    for (final task in [
      (id: 'root-a', parentId: null, sortOrder: 0),
      (id: 'root-b', parentId: null, sortOrder: 1),
      (id: 'child-a', parentId: 'root-a', sortOrder: 0),
      (id: 'child-b', parentId: 'root-a', sortOrder: 1),
    ]) {
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: task.id,
          listId: 'list-a',
          parentTaskId: Value(task.parentId),
          title: task.id,
          sortOrder: Value(task.sortOrder),
          updatedAt: now,
          createdAt: now,
        ),
      );
    }
  });
}
