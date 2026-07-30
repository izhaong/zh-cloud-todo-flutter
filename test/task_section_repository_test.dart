import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_section_repository.dart';

void main() {
  late AppDatabase db;
  late SyncChangeQueue queue;
  late TaskSectionRepository sections;
  late TaskRepository tasks;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncChangeQueue(db);
    sections = TaskSectionRepository(db, queue);
    tasks = TaskRepository(db, queue);
    final now = DateTime(2026, 7, 30);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-a',
            name: '工作',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-b',
            name: '个人',
            updatedAt: now,
            createdAt: now,
          ),
        );
  });

  tearDown(() => db.close());

  test('离线创建分组后任务可立即归组且 outbox 保持依赖顺序', () async {
    final section = await sections.create(listId: 'list-a', name: ' 本周 ');
    final task = await tasks.create(
      listId: 'list-a',
      sectionId: section.id,
      title: '完成周报',
    );

    expect(section.name, '本周');
    expect(task.sectionId, section.id);
    final changes = await db.select(db.todoSyncChanges).get();
    expect(
      changes.map((change) => change.entity),
      [SyncEntities.taskSection, SyncEntities.task],
    );
  });

  test('分组只允许关联同一清单的任务', () async {
    final section = await sections.create(listId: 'list-a', name: '本周');

    await expectLater(
      tasks.create(
        listId: 'list-b',
        sectionId: section.id,
        title: '错误归组',
      ),
      throwsArgumentError,
    );
  });

  test('删除分组保留任务并原子归回未分组', () async {
    final section = await sections.create(listId: 'list-a', name: '本周');
    final task = await tasks.create(
      listId: 'list-a',
      sectionId: section.id,
      title: '完成周报',
    );

    await sections.delete(section.id);

    final remainingTask = await tasks.getById(task.id);
    expect(remainingTask, isNotNull);
    expect(remainingTask!.sectionId, isNull);
    expect(
      await (db.select(
        db.todoTaskSections,
      )..where((row) => row.id.equals(section.id))).getSingleOrNull(),
      isNull,
    );
    final changes = await db.select(db.todoSyncChanges).get();
    expect(
      changes.where((change) => change.entity == SyncEntities.task).length,
      2,
    );
    expect(
      changes.last,
      isA<TodoSyncChange>()
          .having(
            (change) => change.entity,
            'entity',
            SyncEntities.taskSection,
          )
          .having((change) => change.op, 'op', SyncOps.delete),
    );
  });

  test('改名与重排写入稳定顺序', () async {
    final first = await sections.create(listId: 'list-a', name: '第一组');
    final second = await sections.create(listId: 'list-a', name: '第二组');

    await sections.rename(first.id, '准备');
    await sections.reorder(
      listId: 'list-a',
      orderedSectionIds: [second.id, first.id],
    );

    final rows =
        await (db.select(db.todoTaskSections)
              ..where((row) => row.listId.equals('list-a'))
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    expect(rows.map((row) => row.id), [second.id, first.id]);
    expect(rows.last.name, '准备');
  });
}
