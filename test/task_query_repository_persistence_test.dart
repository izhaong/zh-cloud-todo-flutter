import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';

void main() {
  test('文件型数据库重启后仍可按稳定 UUID 搜索本地任务', () async {
    final directory = await Directory.systemTemp.createTemp('todo-search-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/todo.sqlite');
    final now = DateTime.utc(2026, 7, 16, 9);
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first
        .into(first.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-restart',
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await first
        .into(first.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-restart',
            listId: 'list-restart',
            title: '重启后可搜索的任务',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    final results = await TaskQueryRepository(reopened).search('重启后');

    expect(results.map((result) => result.identity), ['task:task-restart']);
  });
}
