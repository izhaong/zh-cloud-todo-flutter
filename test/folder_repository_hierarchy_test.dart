import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';

void main() {
  test('create and move persist parentId in Drift and outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FolderRepository(db, SyncChangeQueue(db));

    final parent = await repository.create('项目');
    final child = await repository.create('后端', parentId: parent.id);
    expect(child.parentId, parent.id);

    final moved = await repository.moveToParent(child.id, null);
    expect(moved.parentId, isNull);
    final changes = await db.select(db.todoSyncChanges).get();
    expect(
      jsonDecode(changes.last.payloadJson)['parentId'],
      isNull,
      reason: '显式移动到顶层必须进入 REST outbox',
    );
  });

  test('moving a folder below its descendant is rejected', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FolderRepository(db, SyncChangeQueue(db));
    final parent = await repository.create('项目');
    final child = await repository.create('后端', parentId: parent.id);

    await expectLater(
      repository.moveToParent(parent.id, child.id),
      throwsA(isA<StateError>()),
    );
  });
}
