import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// 嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》`:66`
/// 左滑三选项之一是「移动任务」——它是这一面里唯一**没有现成写库通道**的一件：
/// `update(listId:)` 只挪被点的那一行，子任务留在原清单，也不校验目标清单可写。
/// 所以本轮补 `moveToList`，测的就是这两条与"跨清单要清分组"。
void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TaskRepository(db, SyncChangeQueue(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('移动父任务时整棵子树一起走，跨清单的分组清空', () async {
    await _seed(db);

    final moved = await repo.moveToList('root-a', 'list-b');

    expect(moved.map((task) => task.id), ['root-a', 'child-a', 'grand-a']);
    for (final id in ['root-a', 'child-a', 'grand-a']) {
      final row = await _row(db, id);
      expect(row.listId, 'list-b', reason: '$id 应该跟着父级一起挪');
      expect(
        row.sectionId,
        isNull,
        reason: '$id 原来的分组属于 list-a，留在 list-b 上就是一个指向别的清单的野引用',
      );
    }
    // child-b 是 root-b 的子级，不在这棵树上，不该被牵连。
    expect((await _row(db, 'child-b')).listId, 'list-a');
    expect(
      (await _row(db, 'root-b')).sectionId,
      'section-a',
      reason: '没挪的行分组不动',
    );
  });

  test('目标清单只读时整笔拒绝：一行都不挪，也不排 outbox', () async {
    await _seed(db);

    await expectLater(
      repo.moveToList('root-a', 'list-readonly'),
      throwsA(isA<StateError>()),
      reason: '订阅/共享来的清单 writable=false，挪进去就是一行改不动的任务',
    );

    for (final id in ['root-a', 'child-a', 'grand-a']) {
      expect((await _row(db, id)).listId, 'list-a', reason: '$id 不该被挪');
    }
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('每个被挪的行各排一条 task upsert，payload 带新 listId', () async {
    await _seed(db);

    await repo.moveToList('root-a', 'list-b');

    final changes = await (db.select(
      db.todoSyncChanges,
    )..where((change) => change.entity.equals(SyncEntities.task))).get();
    expect(changes, hasLength(3), reason: '父 + 子 + 孙，各一条');
    expect(changes.every((change) => change.op == SyncOps.upsert), isTrue);
    expect(
      changes.map((change) => jsonDecode(change.payloadJson)['listId']).toSet(),
      {'list-b'},
    );
  });

  test('已经在目标清单时是 no-op：不写库也不排第二条 outbox', () async {
    await _seed(db);

    final moved = await repo.moveToList('root-a', 'list-a');

    expect(moved, hasLength(1), reason: 'no-op 时只回被点的那一行，不遍历子树');
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('移到收集箱：那一行清单不存在时先补出来再挪', () async {
    await _seed(db);

    await repo.moveToList('root-b', 'inbox');

    expect((await _row(db, 'root-b')).listId, 'inbox');
    final inbox = await db.listByLocalId('inbox');
    expect(inbox, isNotNull, reason: '收集箱是合成清单，挪进来要先把那一行建出来');
    expect(inbox!.writable, isTrue);
  });

  test('任务不存在时抛错，不静默造出一行', () async {
    await _seed(db);

    await expectLater(repo.moveToList('nope', 'list-b'), throwsA(anything));
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });
}

Future<TodoTask> _row(AppDatabase db, String id) =>
    (db.select(db.todoTasks)..where((t) => t.id.equals(id))).getSingle();

/// list-a 里两棵任务树 + 一个分组；list-b 是普通可写清单；list-readonly 是订阅来的只读清单。
Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 12, 9);
  await db.batch((batch) {
    for (final (id, name, writable) in [
      ('list-a', '项目', true),
      ('list-b', '生活', true),
      ('list-readonly', '订阅', false),
    ]) {
      batch.insert(
        db.todoLists,
        TodoListsCompanion.insert(
          id: id,
          name: name,
          writable: Value(writable),
          updatedAt: now,
          createdAt: now,
        ),
      );
    }
    batch.insert(
      db.todoTaskSections,
      TodoTaskSectionsCompanion.insert(
        id: 'section-a',
        listId: 'list-a',
        name: '进行中',
        updatedAt: now,
        createdAt: now,
      ),
    );
    for (final (id, sectionId, parentTaskId) in [
      ('root-a', 'section-a', null),
      ('root-b', 'section-a', null),
      ('child-a', null, 'root-a'),
      ('grand-a', null, 'child-a'),
      ('child-b', null, 'root-b'),
    ]) {
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: id,
          listId: 'list-a',
          title: id,
          sectionId: Value(sectionId),
          parentTaskId: Value(parentTaskId),
          updatedAt: now,
          createdAt: now,
        ),
      );
    }
  });
}
