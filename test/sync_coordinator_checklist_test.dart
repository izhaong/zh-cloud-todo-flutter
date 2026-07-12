import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

void main() {
  test(
    'offline parent and checklist share one temporary parent ID in a push batch',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 12);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'local-parent',
              listId: 'local-list',
              title: '周报',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoChecklistItems)
          .insert(
            TodoChecklistItemsCompanion.insert(
              id: 'local-checklist',
              taskId: 'local-parent',
              title: '整理数据',
              updatedAt: now,
              createdAt: now,
            ),
          );
      for (final change in [
        (
          mutationId: 'parent-mutation',
          localId: 'local-parent',
          payload: '{"listId":"local-list","title":"周报"}',
        ),
        (
          mutationId: 'checklist-mutation',
          localId: 'local-checklist',
          payload:
              '{"listId":"local-list","parentTaskId":"local-parent","title":"整理数据","isChecklistItem":true}',
        ),
      ]) {
        await db
            .into(db.todoSyncChanges)
            .insert(
              TodoSyncChangesCompanion.insert(
                clientMutationId: change.mutationId,
                entity: 'task',
                op: 'upsert',
                entityLocalId: Value(change.localId),
                payloadJson: change.payload,
                createdAt: now,
              ),
            );
      }

      List<Map<String, dynamic>>? sentChanges;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sentChanges = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>();
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': sentChanges!
                          .map(
                            (change) => {
                              'entityType': 'task',
                              'entityId': change['entityId'],
                              'operation': 'upsert',
                              'clientMutationId': change['clientMutationId'],
                            },
                          )
                          .toList(),
                      'conflicts': <Map<String, dynamic>>[],
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.push();

      final parent = sentChanges!.singleWhere(
        (change) => change['clientMutationId'] == 'parent-mutation',
      );
      final checklist = sentChanges!.singleWhere(
        (change) => change['clientMutationId'] == 'checklist-mutation',
      );
      expect(checklist['payload']['parentTaskId'], parent['entityId']);
    },
  );

  test(
    'accepted checklist mutation binds the server ID to the checklist row',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 12);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'local-parent',
              serverId: const Value(9),
              listId: 'local-list',
              title: '周报',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoChecklistItems)
          .insert(
            TodoChecklistItemsCompanion.insert(
              id: 'local-checklist',
              taskId: 'local-parent',
              title: '整理数据',
              sortOrder: const Value(2),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'mutation-1',
              entity: 'task',
              op: 'upsert',
              entityLocalId: const Value('local-checklist'),
              payloadJson:
                  '{"listId":"local-list","parentTaskId":"local-parent","title":"整理数据","isChecklistItem":true}',
              createdAt: now,
            ),
          );

      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': [
                      {
                        'entityType': 'task',
                        'entityId': 11,
                        'operation': 'upsert',
                        'revision': 1,
                        'clientMutationId': 'mutation-1',
                      },
                    ],
                    'conflicts': <Map<String, dynamic>>[],
                  },
                },
              ),
            ),
          ),
        );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.push();

      final checklist = await (db.select(
        db.todoChecklistItems,
      )..where((item) => item.id.equals('local-checklist'))).getSingle();
      expect(checklist.serverId, 11);
    },
  );

  test(
    'unsynced task capture default list never pushes its local UUID',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 12);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'local-unsynced-list',
              name: '离线项目',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'capture-defaults-mutation',
              entity: 'view_preference',
              op: 'upsert',
              entityLocalId: const Value('local-defaults'),
              payloadJson: jsonEncode({
                'sourceType': 'TASK_CAPTURE',
                'sourceKey': 'defaults',
                'valueJson': jsonEncode({
                  'defaultListId': 'local-unsynced-list',
                  'defaultPriority': 2,
                }),
              }),
              createdAt: now,
            ),
          );

      Map<String, dynamic>? pushedPayload;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final change = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>()
                  .single;
              pushedPayload = Map<String, dynamic>.from(
                change['payload'] as Map,
              );
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': 'view_preference',
                          'entityId': 12,
                          'operation': 'upsert',
                          'clientMutationId': 'capture-defaults-mutation',
                        },
                      ],
                      'conflicts': <Map<String, dynamic>>[],
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.push();

      final nested =
          jsonDecode(pushedPayload!['valueJson'] as String)
              as Map<String, dynamic>;
      expect(nested['defaultListId'], equals(null));
      expect(nested['defaultListServerId'], equals(null));
      expect(nested['defaultPriority'], 2);
    },
  );

  test(
    'pulled checklist task is restored into the local checklist table',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 12);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'local-parent',
              serverId: const Value(9),
              listId: 'local-list',
              title: '周报',
              updatedAt: now,
              createdAt: now,
            ),
          );

      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'entityType': 'task',
                        'entityId': 11,
                        'operation': 'upsert',
                        'revision': 1,
                        'payload': {
                          'listId': 10,
                          'parentTaskId': 9,
                          'title': '整理数据',
                          'isChecklistItem': true,
                          'status': 'TODO',
                          'sortOrder': 2,
                        },
                      },
                    ],
                    'tombstones': <Map<String, dynamic>>[],
                    'nextCursor': 'cursor-1',
                    'hasMore': false,
                  },
                },
              ),
            ),
          ),
        );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.pull();

      final checklist = await db.select(db.todoChecklistItems).getSingle();
      expect(checklist.serverId, 11);
      expect(checklist.taskId, 'local-parent');
      expect(checklist.title, '整理数据');
      expect(checklist.sortOrder, 2);
    },
  );
}
