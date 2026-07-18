import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'setting task tags persists the aggregate and one deduplicated outbox',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final task = await TaskRepository(
        db,
        queue,
      ).create(listId: 'inbox', title: '整理验收证据');
      final tags = TagRepository(db, queue);
      final focus = await tags.create(name: '专注');
      final review = await tags.create(name: '评审');

      await tags.setTaskTags(task.id, [focus.id, review.id, focus.id]);

      expect(
        await tags.tagIdsOf(task.id),
        unorderedEquals([focus.id, review.id]),
      );
      final tagChange = (await db.select(db.todoSyncChanges).get()).last;
      expect(tagChange.entity, 'task_tag');
      expect(jsonDecode(tagChange.payloadJson), {
        'taskId': task.id,
        'tagIds': [focus.id, review.id],
      });
    },
  );

  test(
    'creating a child tag persists its parent and tag outbox payload',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final tags = TagRepository(db, SyncChangeQueue(db));
      final parent = await tags.create(name: '项目');

      final child = await tags.create(name: '客户端', parentId: parent.id);

      expect(child.parentId, parent.id);
      final change = (await db.select(db.todoSyncChanges).get()).last;
      expect(change.entity, 'tag');
      expect(jsonDecode(change.payloadJson)['parentId'], parent.id);
    },
  );

  test(
    'offline child tag survives a file-database restart with its outbox',
    () async {
      final directory = await Directory.systemTemp.createTemp('todo-tag-tree-');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/todo.sqlite');
      final first = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final firstTags = TagRepository(first, SyncChangeQueue(first));
      final parent = await firstTags.create(name: '项目');
      final child = await firstTags.create(name: '客户端', parentId: parent.id);
      await first.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(reopened.close);
      final restored = await (reopened.select(
        reopened.todoTags,
      )..where((tag) => tag.id.equals(child.id))).getSingle();
      expect(restored.parentId, parent.id);
      final changes = await reopened.select(reopened.todoSyncChanges).get();
      expect(
        changes.map((change) => jsonDecode(change.payloadJson)['parentId']),
        contains(parent.id),
      );
    },
  );
}
