import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_batch_edit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskQueryRepository repository;
  late TaskRepository taskRepository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TaskQueryRepository(db);
    taskRepository = TaskRepository(db, SyncChangeQueue(db));
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

  test('重设父任务拒绝自引用', () async {
    await expectLater(
      taskRepository.reparent('task-1', 'task-1'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('重设父任务拒绝形成循环', () async {
    await taskRepository.reparent('task-2', 'task-1');

    await expectLater(
      taskRepository.reparent('task-1', 'task-2'),
      throwsA(isA<StateError>()),
    );
  });

  test('重设父任务拒绝超过五级', () async {
    for (var index = 2; index <= 6; index++) {
      await taskRepository.reparent('task-$index', 'task-${index - 1}');
    }

    await expectLater(
      taskRepository.reparent('task-7', 'task-6'),
      throwsA(isA<StateError>()),
    );
  });

  test('过滤组合状态、清单、优先级和标签', () async {
    await db
        .into(db.todoTaskTags)
        .insert(
          TodoTaskTagsCompanion.insert(
            taskId: 'task-700',
            tagId: 'tag-collection',
          ),
        );
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-matching',
            listId: 'list-inbox',
            title: '待处理收集项',
            priority: const Value(3),
            isPinned: const Value(true),
            sortOrder: const Value(1),
            updatedAt: DateTime.utc(2026, 7, 15, 9),
            createdAt: DateTime.utc(2026, 7, 15, 9),
          ),
        );
    await db
        .into(db.todoTaskTags)
        .insert(
          TodoTaskTagsCompanion.insert(
            taskId: 'task-matching',
            tagId: 'tag-collection',
          ),
        );

    final results = await repository.filter(
      const TaskQueryFilter(
        listId: 'list-inbox',
        priority: 3,
        completed: false,
        tagIds: ['tag-collection'],
      ),
    );

    expect(results.map((task) => task.id), ['task-matching']);
  });

  test('过滤结果按置顶、手工顺序和 ID 稳定排序', () async {
    final now = DateTime.utc(2026, 7, 15, 9);
    for (final task in [
      ('task-ordered-b', true, 7),
      ('task-ordered-a', true, 7),
      ('task-ordered-unpinned', false, 0),
    ]) {
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: task.$1,
              listId: 'list-inbox',
              title: task.$1,
              priority: const Value(2),
              isPinned: Value(task.$2),
              sortOrder: Value(task.$3),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoTaskTags)
          .insert(
            TodoTaskTagsCompanion.insert(
              taskId: task.$1,
              tagId: 'tag-collection',
            ),
          );
    }

    final results = await repository.filter(
      const TaskQueryFilter(priority: 2, tagIds: ['tag-collection']),
    );

    expect(results.map((task) => task.id), [
      'task-ordered-a',
      'task-ordered-b',
      'task-ordered-unpinned',
    ]);
  });

  test('批量编辑为每个任务返回结果，成功项原子入队', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));

    final results = await batchRepository.apply(
      const TaskBatchEditCommand(
        taskIds: ['task-1', 'task-missing', 'task-2'],
        priority: 3,
        completed: true,
        isPinned: true,
      ),
    );

    expect(results.map((result) => result.status), [
      TaskBatchEditStatus.success,
      TaskBatchEditStatus.failed,
      TaskBatchEditStatus.success,
    ]);
    expect(results[1].reason, '任务不存在');

    final changed = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.isIn(['task-1', 'task-2']))).get();
    expect(changed, hasLength(2));
    expect(changed.every((task) => task.priority == 3), isTrue);
    expect(changed.every((task) => task.completed), isTrue);
    expect(changed.every((task) => task.isPinned), isTrue);

    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued, hasLength(2));
    expect(
      queued.every((change) => change.entity == SyncEntities.task),
      isTrue,
    );
    expect(queued.every((change) => change.op == SyncOps.upsert), isTrue);
    expect(queued.map((change) => change.entityLocalId).toSet(), {
      'task-1',
      'task-2',
    });
  });
}
