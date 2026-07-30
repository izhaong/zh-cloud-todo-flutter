import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

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

  test(
    'deleting an unsynced folder cancels its create and ungroups local lists',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final folders = FolderRepository(db, queue);
      final folder = await folders.create('离线项目');
      final list = await ListRepository(
        db,
        queue,
      ).create(name: '离线清单', folderLocalId: folder.id);

      await folders.delete(folder.id);

      expect(await db.select(db.todoFolders).get(), isEmpty);
      final ungrouped = await db.listByLocalId(list.id);
      expect(ungrouped?.folderLocalId, isNull);
      expect(ungrouped?.folderId, isNull);
      final changes = await db.select(db.todoSyncChanges).get();
      expect(
        changes.where((change) => change.entity == SyncEntities.folder),
        isEmpty,
      );
      expect(
        changes.where((change) => change.entity == SyncEntities.list),
        hasLength(1),
      );

      Map<String, dynamic>? pushedList;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map>();
              pushedList = changes.single.cast<String, dynamic>();
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': SyncEntities.list,
                          'entityId': 101,
                          'operation': SyncOps.upsert,
                          'clientMutationId': pushedList!['clientMutationId'],
                        },
                      ],
                      'conflicts': const [],
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = ApiClient(dio: dio);
      expect(
        await SyncCoordinator(
          db: db,
          api: SyncApi(client, clientId: 'device-a', deviceId: 'device-a'),
          todoApi: client,
        ).push(),
        1,
      );
      expect(pushedList!['payload']['folderId'], isNull);
      expect(pushedList!['payload'], isNot(contains('folderLocalId')));
    },
  );
}
