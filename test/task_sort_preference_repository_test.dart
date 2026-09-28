import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

void main() {
  test('1000 条任务按置顶、用户字段、手工顺序和 UUID 进行稳定多键排序', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskQueryRepository(db);
    final now = DateTime.utc(2026, 7, 19, 9);

    await db.batch((batch) {
      for (var index = 0; index < 1000; index++) {
        batch.insert(
          db.todoTasks,
          TodoTasksCompanion.insert(
            id: 'fixture-${index.toString().padLeft(4, '0')}',
            listId: 'inbox',
            title: index == 997 ? 'Alpha' : 'Task $index',
            priority: Value(index >= 997 ? 3 : index % 4),
            isPinned: Value(index == 999),
            sortOrder: Value(index == 997 || index == 998 ? 0 : index),
            updatedAt: now,
            createdAt: now,
          ),
        );
      }
    });

    final first = await repository.filter(
      const TaskQueryFilter(sort: TaskSort.priorityDesc),
    );
    final second = await repository.filter(
      const TaskQueryFilter(sort: TaskSort.priorityDesc),
    );

    expect(first.first.id, 'fixture-0999');
    expect(first.skip(1).take(2).map((task) => task.id), [
      'fixture-0997',
      'fixture-0998',
    ]);
    expect(second.map((task) => task.id), first.map((task) => task.id));
  });

  test('排序偏好按清单隔离，离线保存后入队并可重启读取', () async {
    final databasePath =
        '${Directory.systemTemp.path}/todo-sort-preference-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final db = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    final repository = TaskSortPreferenceRepository(db, SyncChangeQueue(db));

    await repository.save('list-a', TaskSort.dueDate);
    await repository.save('list-b', TaskSort.title);
    await db.close();

    final reopened = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    addTearDown(() async {
      await reopened.close();
      await File(databasePath).delete();
    });
    final restored = TaskSortPreferenceRepository(
      reopened,
      SyncChangeQueue(reopened),
    );

    expect((await restored.get('list-a')).sort, TaskSort.dueDate);
    expect((await restored.get('list-b')).sort, TaskSort.title);
    expect((await restored.get(null)).sort, TaskSort.smart);

    final rows = await reopened.select(reopened.todoViewPreferences).get();
    expect(rows.map((row) => row.sourceKey), ['list-a', 'list-b']);
    expect(rows.every((row) => row.sourceType == 'TASK_SORT'), isTrue);
    final changes = await reopened.select(reopened.todoSyncChanges).get();
    expect(changes, hasLength(2));
    expect(
      changes
          .map((change) => jsonDecode(change.payloadJson)['valueJson'])
          .map((value) => jsonDecode(value as String)['sort']),
      ['dueDate', 'title'],
    );
  });
}
