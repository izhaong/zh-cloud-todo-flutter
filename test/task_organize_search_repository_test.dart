import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
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
        db.todoFolders,
        TodoFoldersCompanion.insert(
          id: 'folder-work',
          serverId: const Value(88),
          name: '工作',
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        db.todoLists,
        TodoListsCompanion.insert(
          id: 'list-inbox',
          name: '收集箱',
          folderId: const Value(88),
          updatedAt: now,
          createdAt: now,
        ),
      );
      batch.insert(
        db.todoLists,
        TodoListsCompanion.insert(
          id: 'list-target',
          name: '本周计划',
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
      batch.insert(
        db.todoTags,
        TodoTagsCompanion.insert(
          id: 'tag-target',
          name: '本周',
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
      batch.insert(
        db.todoTaskTags,
        TodoTaskTagsCompanion.insert(
          taskId: 'task-700',
          tagId: 'tag-collection',
        ),
      );
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

  test('本地搜索索引覆盖任务、清单和标签，并保持可用的标题', () async {
    final entries = await db.searchIndex('收集');

    expect(entries.map((entry) => entry.identity).toList(), [
      'task:task-700',
      'list:list-inbox',
      'tag:tag-collection',
    ]);
    expect(entries.map((entry) => entry.title).toList(), ['收集周报', '收集箱', '收集']);
  });

  test('文件型 SQLite 的千条任务首个搜索过滤和批量反馈均在 300ms 内', () async {
    final databasePath =
        '${Directory.systemTemp.path}/todo-b3-performance-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final previousMultipleDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final fileDb = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    addTearDown(() async {
      await fileDb.close();
      await File(databasePath).delete();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousMultipleDatabaseWarning;
    });
    final fileRepository = TaskQueryRepository(fileDb);
    final batchRepository = TaskBatchEditRepository(
      fileDb,
      SyncChangeQueue(fileDb),
    );
    final now = DateTime.utc(2026, 7, 27, 9);

    await fileDb.batch((batch) {
      batch.insert(
        fileDb.todoLists,
        TodoListsCompanion.insert(
          id: 'performance-list',
          name: '性能清单',
          updatedAt: now,
          createdAt: now,
        ),
      );
      for (var index = 0; index < 1000; index++) {
        batch.insert(
          fileDb.todoTasks,
          TodoTasksCompanion.insert(
            id: 'performance-task-$index',
            listId: 'performance-list',
            title: index == 700 ? '性能收集结果' : '性能常规任务 $index',
            priority: Value(index % 4),
            sortOrder: Value(index),
            updatedAt: now,
            createdAt: now,
          ),
        );
      }
    });

    await fileRepository.search('不存在的预热词');
    final searchWatch = Stopwatch()..start();
    final search = await fileRepository.search('性能收集');
    searchWatch.stop();

    final filterWatch = Stopwatch()..start();
    final filtered = await fileRepository.filter(
      const TaskQueryFilter(
        listId: 'performance-list',
        priority: 3,
        sort: TaskSort.priorityDesc,
      ),
    );
    filterWatch.stop();

    final batchWatch = Stopwatch()..start();
    final batch = await batchRepository.apply(
      const TaskBatchEditCommand(
        taskIds: [
          'performance-task-1',
          'performance-task-2',
          'performance-task-3',
        ],
        priority: 3,
      ),
    );
    batchWatch.stop();

    expect(search.single.identity, 'task:performance-task-700');
    expect(filtered, isNotEmpty);
    expect(
      batch.every((result) => result.status == TaskBatchEditStatus.success),
      isTrue,
    );
    expect(searchWatch.elapsedMilliseconds, lessThan(300));
    expect(filterWatch.elapsedMilliseconds, lessThan(300));
    expect(batchWatch.elapsedMilliseconds, lessThan(300));
    // 保留本机实际测量，供 Docs 验收记录而非将固定时间写死在断言中。
    // ignore: avoid_print
    print(
      'B3_PERF file-sqlite-1000 '
      'search=${searchWatch.elapsedMilliseconds}ms '
      'filter=${filterWatch.elapsedMilliseconds}ms '
      'batch3=${batchWatch.elapsedMilliseconds}ms',
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

  test('重设父任务拒绝不存在的本地父任务且不写 outbox', () async {
    await expectLater(
      taskRepository.reparent('task-1', 'task-missing'),
      throwsA(isA<StateError>()),
    );

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(task.parentTaskId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('重设父任务拒绝跨清单关系且不写 outbox', () async {
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-other-list',
            listId: 'list-target',
            title: '另一清单任务',
            updatedAt: DateTime.utc(2026, 7, 15, 9),
            createdAt: DateTime.utc(2026, 7, 15, 9),
          ),
        );

    await expectLater(
      taskRepository.reparent('task-1', 'task-other-list'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '父任务必须属于同一清单',
        ),
      ),
    );

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(task.parentTaskId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('新建子任务拒绝跨清单父任务且不写数据', () async {
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-other-list',
            listId: 'list-target',
            title: '另一清单任务',
            updatedAt: DateTime.utc(2026, 7, 15, 9),
            createdAt: DateTime.utc(2026, 7, 15, 9),
          ),
        );

    await expectLater(
      taskRepository.create(
        listId: 'list-inbox',
        title: '错误子任务',
        parentTaskId: 'task-other-list',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '父任务必须属于同一清单',
        ),
      ),
    );

    expect(
      await (db.select(
        db.todoTasks,
      )..where((row) => row.title.equals('错误子任务'))).get(),
      isEmpty,
    );
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('新建子任务拒绝超过五级且不写数据', () async {
    for (var index = 2; index <= 6; index++) {
      await taskRepository.reparent('task-$index', 'task-${index - 1}');
    }

    await expectLater(
      taskRepository.create(
        listId: 'list-inbox',
        title: '第六级子任务',
        parentTaskId: 'task-6',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '任务层级不能超过五级',
        ),
      ),
    );

    expect(
      await (db.select(
        db.todoTasks,
      )..where((row) => row.title.equals('第六级子任务'))).get(),
      isEmpty,
    );
  });

  test('重设不存在的任务在写入前拒绝且不写 outbox', () async {
    await expectLater(
      taskRepository.reparent('task-missing', 'task-1'),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', '任务不存在'),
      ),
    );

    final parent = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(parent.parentTaskId, isNull);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
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

  test('高级过滤按关键词和截止日期 UTC 闭区间返回稳定结果', () async {
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).write(
      TodoTasksCompanion(
        title: const Value('规划发布'),
        dueAt: Value(DateTime.utc(2026, 7, 20, 0)),
      ),
    );
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-2'))).write(
      TodoTasksCompanion(
        title: const Value('规划复盘'),
        dueAt: Value(DateTime.utc(2026, 7, 21, 0)),
      ),
    );

    final results = await repository.filter(
      TaskQueryFilter(
        keyword: '规划',
        dueAtFrom: DateTime.utc(2026, 7, 20, 0),
        dueAtTo: DateTime.utc(2026, 7, 20, 0),
      ),
    );

    expect(results.map((task) => task.id), ['task-1']);
  });

  test('截止日期过滤与排序使用任务固定时区墙钟日期', () async {
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).write(
      TodoTasksCompanion(
        dueAt: Value(DateTime.utc(2026, 7, 21, 2)),
        timeZone: const Value('America/Los_Angeles'),
        fixedTimezone: const Value(true),
      ),
    );
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-2'))).write(
      TodoTasksCompanion(
        dueAt: Value(DateTime.utc(2026, 7, 20, 18)),
        timeZone: const Value('UTC'),
        fixedTimezone: const Value(true),
      ),
    );

    final results = await repository.filter(
      TaskQueryFilter(
        dueAtFrom: DateTime(2026, 7, 20),
        dueAtTo: DateTime(2026, 7, 20),
        sort: TaskSort.dueDate,
      ),
    );

    expect(results.map((task) => task.id), ['task-2', 'task-1']);
  });

  test('高级过滤按负责人返回稳定结果', () async {
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).write(
      const TodoTasksCompanion(
        assigneeUserId: Value(101),
        assigneeUserName: Value('小周'),
      ),
    );
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-2'))).write(
      const TodoTasksCompanion(
        assigneeUserId: Value(102),
        assigneeUserName: Value('小李'),
      ),
    );

    final results = await repository.filter(
      const TaskQueryFilter(assigneeUserId: 101),
    );

    expect(results.map((task) => task.id), ['task-1']);
    expect(results.single.assigneeUserName, '小周');
  });

  test('高级过滤拒绝倒置的截止日期区间', () async {
    await expectLater(
      repository.filter(
        TaskQueryFilter(
          dueAtFrom: DateTime.utc(2026, 7, 21),
          dueAtTo: DateTime.utc(2026, 7, 20),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
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

  test('本地搜索索引随任务更新和删除保持一致', () async {
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-700'))).write(
      const TodoTasksCompanion(title: Value('已改名任务'), description: Value(null)),
    );

    final afterRename = await db.searchIndex('收集');
    expect(afterRename, [
      isA<TodoSearchIndexEntry>().having(
        (entry) => entry.identity,
        'identity',
        'list:list-inbox',
      ),
      isA<TodoSearchIndexEntry>().having(
        (entry) => entry.identity,
        'identity',
        'tag:tag-collection',
      ),
    ]);
    expect((await db.searchIndex('改名')).single.identity, 'task:task-700');

    await (db.delete(
      db.todoTags,
    )..where((row) => row.id.equals('tag-collection'))).go();
    expect((await db.searchIndex('收集')).map((entry) => entry.identity), [
      'list:list-inbox',
    ]);
  });

  test('批量编辑为每个任务返回结果，成功项原子入队', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));

    final results = await batchRepository.apply(
      const TaskBatchEditCommand(
        taskIds: ['task-1', 'task-1', 'task-missing', 'task-2'],
        priority: 3,
        completed: true,
        isPinned: true,
      ),
    );

    expect(results.map((result) => result.status), [
      TaskBatchEditStatus.success,
      TaskBatchEditStatus.skipped,
      TaskBatchEditStatus.failed,
      TaskBatchEditStatus.success,
    ]);
    expect(results[1].reason, '重复任务');
    expect(results[2].reason, '任务不存在');

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

  test('批量编辑在本地移动清单并更新截止时间后逐项入队', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));
    final dueAt = DateTime.utc(2026, 7, 20, 18);

    final results = await batchRepository.apply(
      TaskBatchEditCommand(
        taskIds: const ['task-1', 'task-2'],
        listId: 'list-target',
        dueAt: dueAt,
      ),
    );

    expect(results.map((result) => result.status), [
      TaskBatchEditStatus.success,
      TaskBatchEditStatus.success,
    ]);
    final changed = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.isIn(['task-1', 'task-2']))).get();
    expect(changed.every((task) => task.listId == 'list-target'), isTrue);
    expect(changed.map((task) => task.dueAt?.toUtc()).toList(), [dueAt, dueAt]);

    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued, hasLength(2));
    expect(queued.map((change) => change.entityLocalId).toSet(), {
      'task-1',
      'task-2',
    });
  });

  test('批量移动拒绝不存在的本地清单且不写 outbox', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));

    final results = await batchRepository.apply(
      const TaskBatchEditCommand(taskIds: ['task-1'], listId: 'list-missing'),
    );

    expect(results.single.status, TaskBatchEditStatus.failed);
    expect(results.single.reason, '清单不存在');
    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    expect(task.listId, 'list-inbox');
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('批量编辑清空截止时间后逐项入队', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));
    await (db.update(db.todoTasks)
          ..where((row) => row.id.isIn(['task-1', 'task-2'])))
        .write(TodoTasksCompanion(dueAt: Value(DateTime.utc(2026, 7, 20, 18))));

    final results = await batchRepository.apply(
      const TaskBatchEditCommand(
        taskIds: ['task-1', 'task-2'],
        clearDueAt: true,
      ),
    );

    expect(results.map((result) => result.status), [
      TaskBatchEditStatus.success,
      TaskBatchEditStatus.success,
    ]);
    final changed = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.isIn(['task-1', 'task-2']))).get();
    expect(changed.every((task) => task.dueAt == null), isTrue);

    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued, hasLength(2));
    expect(queued.map((change) => change.entityLocalId).toSet(), {
      'task-1',
      'task-2',
    });
  });

  test('批量编辑替换标签并为每个任务写 task_tag outbox', () async {
    final batchRepository = TaskBatchEditRepository(db, SyncChangeQueue(db));
    await db
        .into(db.todoTaskTags)
        .insert(
          TodoTaskTagsCompanion.insert(
            taskId: 'task-1',
            tagId: 'tag-collection',
          ),
        );

    final results = await batchRepository.apply(
      const TaskBatchEditCommand(
        taskIds: ['task-1', 'task-2'],
        tagIds: ['tag-target'],
      ),
    );

    expect(results.map((result) => result.status), [
      TaskBatchEditStatus.success,
      TaskBatchEditStatus.success,
    ]);
    final taskTags = await (db.select(
      db.todoTaskTags,
    )..where((row) => row.taskId.isIn(const ['task-1', 'task-2']))).get();
    expect(taskTags.map((row) => '${row.taskId}:${row.tagId}').toSet(), {
      'task-1:tag-target',
      'task-2:tag-target',
    });

    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued, hasLength(4));
    expect(
      queued
          .where((change) => change.entity == SyncEntities.taskTag)
          .map((change) => change.entityLocalId),
      containsAll(<String>['task-1', 'task-2']),
    );
  });
}
