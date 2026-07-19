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
}
