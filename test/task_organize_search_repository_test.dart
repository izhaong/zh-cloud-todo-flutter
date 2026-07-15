import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';

void main() {
  late AppDatabase db;
  late TaskQueryRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TaskQueryRepository(db);
    final now = DateTime.utc(2026, 7, 15, 9);

    await db.batch((batch) {
      batch.insert(
        db.todoLists,
        TodoListsCompanion.insert(
          id: 'list-inbox',
          name: '收集箱',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        db.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-collection',
          name: '收集',
          updatedAt: now,
          createdAt: now,
        ),
      );
      for (var index = 0; index < 1000; index++) {
        batch.insert(
          db.todoTasks,
          TodoTasksCompanion.insert(
            id: 'task-$index',
            listId: 'list-inbox',
            title: index == 700 ? '收集周报' : '常规任务 $index',
            description: Value(index == 700 ? '整理收集资料' : null),
            priority: Value(index % 4),
            sortOrder: Value(index),
            updatedAt: now,
            createdAt: now,
          ),
        );
      }
    });
  });

  tearDown(() => db.close());

  test('搜索在 1000 条 fixture 中稳定返回任务、清单和标签', () async {
    final first = await repository.search(' 收集 ');
    final secondQuery = await repository.search('收集');

    expect(first.map((result) => result.identity).toList(), [
      'task:task-700',
      'list:list-inbox',
      'tag:tag-collection',
    ]);
    expect(
      secondQuery.map((result) => result.identity).toList(),
      first.map((result) => result.identity).toList(),
    );
  });
}
