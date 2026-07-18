import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('offline B1 aggregate survives a local database restart', () async {
    final directory = await Directory.systemTemp.createTemp('todo-b1-restart-');
    final databaseFile = File('${directory.path}/todo.sqlite');
    final first = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final queue = SyncChangeQueue(first);
    final tasks = TaskRepository(first, queue);
    final tags = TagRepository(first, queue);

    final task = await tasks.create(
      listId: 'inbox',
      title: '离线完成 B1 验收',
      description: '## 恢复后仍可编辑',
      priority: 2,
    );
    await tasks.createChecklistItem(taskId: task.id, title: '验证重启回显');
    await tasks.queueAttachment(
      taskId: task.id,
      name: 'evidence.txt',
      localPath: '/tmp/evidence.txt',
      mimeType: 'text/plain',
      size: 12,
    );
    final tag = await tags.create(name: 'B1');
    await tags.setTaskTags(task.id, [tag.id]);
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(() async {
      await reopened.close();
      await directory.delete(recursive: true);
    });

    final restored = await (reopened.select(
      reopened.todoTasks,
    )..where((row) => row.id.equals(task.id))).getSingle();
    expect(restored.description, '## 恢复后仍可编辑');
    expect(restored.priority, 2);
    expect(
      await reopened.select(reopened.todoChecklistItems).get(),
      hasLength(1),
    );
    expect(await reopened.select(reopened.todoAttachments).get(), hasLength(1));
    expect(await reopened.select(reopened.todoTaskTags).get(), hasLength(1));
    expect(await reopened.select(reopened.todoSyncChanges).get(), isNotEmpty);
  });
}
