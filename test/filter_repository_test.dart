import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

void main() {
  test(
    'save writes filter and outbox atomically then resolves local list IDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 19);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'local-list',
              serverId: const Value(101),
              name: '项目',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final repository = FilterRepository(db, SyncChangeQueue(db));

      final filter = await repository.save(
        name: '项目高优先级',
        conditions: const TodoFilterConditions(
          listIds: ['local-list'],
          priorities: [3],
          keyword: '周报',
        ),
        sortOrders: const [
          TodoFilterSortOrder(field: 'title', direction: 'ASC'),
        ],
        isSmart: true,
      );

      expect(jsonDecode(filter.conditionJson), {
        'listIds': ['local-list'],
        'priorities': [3],
        'keyword': '周报',
      });
      final change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.entity, 'filter');

      Map<String, dynamic>? sent;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent =
                  ((options.data as Map)['changes'] as List).single['payload']
                      as Map<String, dynamic>;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': 'filter',
                          'entityId': 201,
                          'operation': 'upsert',
                          'clientMutationId': change.clientMutationId,
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
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.push(), 1);
      expect(jsonDecode(sent!['conditionsJson'] as String), {
        'listIds': [101],
        'priorities': [3],
        'keyword': '周报',
      });
      expect(sent!['sortOrdersJson'], '[{"field":"title","direction":"ASC"}]');
      expect(sent!['isSmart'], true);
      expect((await db.select(db.todoFilters).getSingle()).serverId, 201);
    },
  );

  test(
    'filter waits for unsynced list and tag server IDs before it is pushed',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final now = DateTime.utc(2026, 7, 19);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'local-list',
              name: '项目',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoTags)
          .insert(
            TodoTagsCompanion.insert(
              id: 'local-tag',
              name: '工作',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await queue.enqueue(
        entity: 'list',
        op: 'upsert',
        localId: 'local-list',
        payload: const {'name': '项目'},
      );
      await queue.enqueue(
        entity: 'tag',
        op: 'upsert',
        localId: 'local-tag',
        payload: const {'name': '工作'},
      );
      final filter = await FilterRepository(db, queue).save(
        name: '项目工作',
        conditions: const TodoFilterConditions(
          listIds: ['local-list'],
          tagIds: ['local-tag'],
        ),
      );

      final pushedBatches = <List<Map<String, dynamic>>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map>()
                  .map((entry) => entry.cast<String, dynamic>())
                  .toList();
              pushedBatches.add(changes);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        for (final change in changes)
                          {
                            'entityType': change['entityType'],
                            'entityId': switch (change['entityType']) {
                              'list' => 101,
                              'tag' => 201,
                              _ => 301,
                            },
                            'operation': 'upsert',
                            'clientMutationId': change['clientMutationId'],
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
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.push(), 2);
      expect(pushedBatches.single.map((change) => change['entityType']), [
        'list',
        'tag',
      ]);
      final filterChange = await (db.select(
        db.todoSyncChanges,
      )..where((row) => row.entityLocalId.equals(filter.id))).getSingle();
      expect(filterChange.status, 'queued');

      expect(await coordinator.push(), 1);
      expect(pushedBatches, hasLength(2));
      final filterPayload =
          pushedBatches.last.single['payload'] as Map<String, dynamic>;
      expect(jsonDecode(filterPayload['conditionsJson'] as String), {
        'listIds': [101],
        'tagIds': [201],
      });
    },
  );

  test(
    'pulled filter restores list and tag associations as local UUIDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/folder/list')) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': const []},
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'changes': [
                        {
                          'entityType': 'filter',
                          'entityId': 301,
                          'operation': 'upsert',
                          'revision': 3,
                          'payload': {
                            'name': '项目工作',
                            'conditionsJson': jsonEncode({
                              'listIds': [101],
                              'tagIds': [201],
                              'priorities': [3],
                            }),
                          },
                        },
                        {
                          'entityType': 'tag',
                          'entityId': 201,
                          'operation': 'upsert',
                          'revision': 2,
                          'payload': {'name': '工作'},
                        },
                        {
                          'entityType': 'list',
                          'entityId': 101,
                          'operation': 'upsert',
                          'revision': 1,
                          'payload': {'name': '项目'},
                        },
                      ],
                      'tombstones': const [],
                      'nextCursor': '3',
                      'hasMore': false,
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
          api: SyncApi(client, clientId: 'test', deviceId: 'device-b'),
          todoApi: client,
        ).pull(),
        3,
      );

      final list = await db.listByServerId(101);
      final tag = await db.tagByServerId(201);
      final filter = await db.select(db.todoFilters).getSingle();
      expect(jsonDecode(filter.conditionJson), {
        'listIds': [list!.id],
        'tagIds': [tag!.id],
        'priorities': [3],
      });
    },
  );
}
