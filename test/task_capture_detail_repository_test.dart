import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'batch capture skips blank lines and preserves each nonblank title',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));

      final tasks = await repository.createBatch(
        listId: 'inbox',
        input: '写周报\n\n  整理数据  \n',
        dueAtResolver: (title) =>
            title == '写周报' ? DateTime(2026, 7, 13, 10) : null,
      );

      expect(tasks.map((task) => task.title), ['写周报', '整理数据']);
      expect(tasks.first.dueAt, DateTime(2026, 7, 13, 10));
      expect(tasks.last.dueAt, isNull);
      expect(await db.select(db.todoTasks).get(), hasLength(2));
    },
  );

  test('task creation rejects a blank title', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.create(listId: 'inbox', title: '   '),
      throwsArgumentError,
    );
  });

  test(
    'attachment starts queued locally and can be marked failed then retried',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '撰写周报');

      final attachment = await repository.queueAttachment(
        taskId: task.id,
        name: 'weekly-report.pdf',
        localPath: '/tmp/weekly-report.pdf',
        mimeType: 'application/pdf',
        size: 1024,
      );
      expect(attachment.status, 'queued');
      expect(
        (await db.select(db.todoSyncChanges).get()).where(
          (change) => change.entity == 'attachment',
        ),
        hasLength(1),
      );

      await repository.markAttachmentFailed(
        attachment.id,
        'network unreachable',
      );
      expect(
        (await db.select(db.todoAttachments).getSingle()).status,
        'failed',
      );
      await repository.retryAttachment(attachment.id);
      expect(
        (await db.select(db.todoAttachments).getSingle()).status,
        'queued',
      );
    },
  );

  test(
    'deleting an unsynced attachment removes its local row and outbox entry',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final attachment = await repository.queueAttachment(
        taskId: task.id,
        name: 'weekly-report.pdf',
        localPath: '/tmp/weekly-report.pdf',
        mimeType: 'application/pdf',
        size: 1024,
      );

      await repository.deleteAttachment(attachment.id);

      expect(await db.select(db.todoAttachments).get(), isEmpty);
      final attachmentChanges = (await db.select(db.todoSyncChanges).get())
          .where((change) => change.entity == 'attachment');
      expect(attachmentChanges, isEmpty);
    },
  );

  test('copying a task creates an independent local mutation', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));
    final original = await repository.create(
      listId: 'inbox',
      title: '撰写周报',
      description: '## 本周目标',
      priority: 2,
      dueAt: DateTime(2026, 7, 15, 9),
      isPinned: true,
    );

    final copied = await repository.copy(original.id);

    expect(copied.id, isNot(original.id));
    expect(copied.title, '撰写周报（副本）');
    expect(copied.description, original.description);
    expect(copied.priority, original.priority);
    expect(copied.dueAt, original.dueAt);
    expect(copied.isPinned, isFalse);
    final outbox = await db.select(db.todoSyncChanges).get();
    expect(
      outbox.where((change) => change.entityLocalId == copied.id),
      hasLength(1),
    );
  });

  test(
    'abandoning a task persists a cancelled state and sync payload',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '过期方案');

      final abandoned = await repository.abandon(task.id);

      expect(abandoned.cancelled, isTrue);
      expect(abandoned.completed, isFalse);
      final change = (await db.select(db.todoSyncChanges).get()).last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['status'], 'cancelled');
    },
  );

  test('detail can explicitly clear an already persisted due date', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));
    final task = await repository.create(
      listId: 'inbox',
      title: '清理日期',
      dueAt: DateTime(2026, 7, 13, 9),
    );

    final cleared = await repository.update(task.id, clearDueAt: true);

    expect(cleared.dueAt, isNull);
    final payload =
        jsonDecode((await db.select(db.todoSyncChanges).get()).last.payloadJson)
            as Map<String, dynamic>;
    expect(payload['dueAt'], isNull);
  });

  test(
    'detail persists and explicitly clears its start and end times',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '安排时段');
      final start = DateTime(2026, 7, 13, 9);
      final end = DateTime(2026, 7, 13, 10, 30);

      final scheduled = await repository.update(
        task.id,
        startAt: start,
        endAt: end,
      );
      expect(scheduled.startAt, start);
      expect(scheduled.endAt, end);

      final cleared = await repository.update(
        task.id,
        clearStartAt: true,
        clearEndAt: true,
      );
      expect(cleared.startAt, isNull);
      expect(cleared.endAt, isNull);
    },
  );

  test(
    'offline checklist creation persists locally and enqueues a mutation',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));

      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理数据',
      );

      expect(item.taskId, task.id);
      expect(item.title, '整理数据');
      final stored = await db.select(db.todoChecklistItems).get();
      expect(stored, hasLength(1));
      final outbox = await db.select(db.todoSyncChanges).get();
      final checklistChange = outbox.singleWhere(
        (change) => change.entity == 'task' && change.entityLocalId == item.id,
      );
      final payload =
          jsonDecode(checklistChange.payloadJson) as Map<String, dynamic>;
      expect(payload['isChecklistItem'], isTrue);
      expect(payload['parentTaskId'], task.id);
      expect(payload['listId'], task.listId);
    },
  );

  test(
    'offline checklist edits and deletion stay local and enqueue task mutations',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理数据',
      );

      final completed = await repository.toggleChecklistItem(item.id);
      expect(completed.completed, isTrue);

      await repository.deleteChecklistItem(item.id);
      expect(await db.select(db.todoChecklistItems).get(), isEmpty);
      final outbox = await db.select(db.todoSyncChanges).get();
      expect(
        outbox.where((change) => change.entityLocalId == item.id),
        isEmpty,
      );
    },
  );

  test(
    'offline checklist rename and reorder preserve the aggregate sync payload',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理数据',
        sortOrder: 2,
      );

      final updated = await repository.updateChecklistItem(
        item.id,
        title: '复核数据',
        sortOrder: 1,
      );

      expect(updated.title, '复核数据');
      expect(updated.sortOrder, 1);
      final change = (await db.select(db.todoSyncChanges).get()).last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['title'], '复核数据');
      expect(payload['sortOrder'], 1);
      await expectLater(
        repository.updateChecklistItem(item.id, title: '   '),
        throwsArgumentError,
      );
    },
  );
}
