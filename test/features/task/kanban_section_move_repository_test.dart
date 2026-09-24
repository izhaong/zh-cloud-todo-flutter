import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

/// 看板跨列写入「分组」的仓储语义（矩阵 #15，specs/044 后半）。
void main() {
  final now = DateTime.utc(2026, 7, 15, 9);

  Future<AppDatabase> seeded({bool addOtherListSection = false}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-inbox',
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-other',
            name: '别的清单',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTaskSections)
        .insert(
          TodoTaskSectionsCompanion.insert(
            id: 'sec-en',
            listId: 'list-inbox',
            name: '英语',
            updatedAt: now,
            createdAt: now,
          ),
        );
    if (addOtherListSection) {
      await db
          .into(db.todoTaskSections)
          .insert(
            TodoTaskSectionsCompanion.insert(
              id: 'sec-other',
              listId: 'list-other',
              name: '别人的分组',
              updatedAt: now,
              createdAt: now,
            ),
          );
    }
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            listId: 'list-inbox',
            title: '跨列任务',
            priority: const Value(2),
            updatedAt: now,
            createdAt: now,
          ),
        );
    return db;
  }

  test('拖到分组列只写 sectionId，不动 priority 与 completed，并入 outbox', () async {
    final db = await seeded();
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.moveKanbanTaskToSection('task-1', sectionId: 'sec-en');

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.sectionId, 'sec-en');
    expect(task.priority, 2);
    expect(task.completed, isFalse);
    expect(queued, hasLength(1));
    expect(queued.single.entity, SyncEntities.task);
    expect(queued.single.op, SyncOps.upsert);
    expect(jsonDecode(queued.single.payloadJson)['sectionId'], 'sec-en');
  });

  test('拖到未分组列会把 sectionId 清空', () async {
    final db = await seeded();
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    await repository.moveKanbanTaskToSection('task-1', sectionId: 'sec-en');

    await repository.moveKanbanTaskToSection('task-1', sectionId: null);

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(task.sectionId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), hasLength(2));
  });

  test('分组不属于任务所在清单时拒绝写入，任务与 outbox 都不变', () async {
    final db = await seeded(addOtherListSection: true);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveKanbanTaskToSection('task-1', sectionId: 'sec-other'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '分组必须属于任务所在清单',
        ),
      ),
    );

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(task.sectionId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('分组不存在时拒绝写入', () async {
    final db = await seeded();
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveKanbanTaskToSection('task-1', sectionId: 'sec-ghost'),
      throwsA(isA<ArgumentError>()),
    );
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });
}
