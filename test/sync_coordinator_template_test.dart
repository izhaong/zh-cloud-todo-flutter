import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  test(
    'private task template uses standard sync and propagates a pull tombstone',
    () async {
      final deviceA = AppDatabase.forTesting(NativeDatabase.memory());
      final deviceB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(deviceA.close);
      addTearDown(deviceB.close);
      final server = _TemplateSyncServer();
      final api = server.client();
      final queueA = SyncChangeQueue(deviceA);
      final templateRepositoryA = TemplateRepository(deviceA, queueA);
      final task = await TaskRepository(deviceA, queueA).create(
        listId: 'inbox',
        title: '撰写周报',
        description: '仅保存任务快照',
        priority: 2,
      );
      final localTemplate = await templateRepositoryA.saveTask(
        task: task,
        name: '周报模板',
      );
      final coordinatorA = _coordinator(deviceA, api);
      final coordinatorB = _coordinator(deviceB, api);

      expect(SyncEntities.syncable, contains(SyncEntities.template));
      expect(await coordinatorA.push(), 3);

      final acceptedTemplate = await (deviceA.select(
        deviceA.todoTemplates,
      )..where((row) => row.id.equals(localTemplate.id))).getSingle();
      expect(acceptedTemplate.serverId, 70);
      expect(acceptedTemplate.status, 'synced');
      expect(
        (await deviceA.select(deviceA.todoSyncChanges).get())
            .where((change) => change.entity == SyncEntities.template)
            .single
            .status,
        'synced',
      );
      expect(server.templatePushes, hasLength(1));
      expect(server.templatePushes.single['payload'], {
        'name': '周报模板',
        'content': jsonEncode({
          'title': '撰写周报',
          'description': '仅保存任务快照',
          'priority': 2,
        }),
      });
      expect(await coordinatorA.push(), 0);

      expect(await coordinatorB.pull(), 1);
      final pulledTemplate = await deviceB
          .select(deviceB.todoTemplates)
          .getSingle();
      expect(pulledTemplate.serverId, 70);
      expect(pulledTemplate.name, '周报模板');
      expect(pulledTemplate.contentJson, acceptedTemplate.contentJson);
      expect(pulledTemplate.status, 'synced');

      await templateRepositoryA.delete(localTemplate.id);
      expect(await deviceA.select(deviceA.todoTemplates).get(), isEmpty);
      final deleteChange = (await deviceA.select(deviceA.todoSyncChanges).get())
          .singleWhere(
            (change) =>
                change.entity == SyncEntities.template &&
                change.status == 'queued',
          );
      expect(deleteChange.op, SyncOps.delete);
      expect(deleteChange.entityLocalId, localTemplate.id);
      expect(deleteChange.entityServerId, 70);
      expect(deleteChange.status, 'queued');
      expect(await coordinatorA.push(), 1);
      expect(server.templateDeletes, hasLength(1));

      expect(await coordinatorB.pull(), 1);
      expect(await deviceB.select(deviceB.todoTemplates).get(), isEmpty);
    },
  );

  test(
    'retryable standard template sync retains the local template for retry',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 7, 16);
      await db
          .into(db.todoTemplates)
          .insert(
            TodoTemplatesCompanion.insert(
              id: 'template-local',
              name: '失败后重试',
              contentJson: '{"title":"保持本地副本"}',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'template-upsert',
              entity: SyncEntities.template,
              op: SyncOps.upsert,
              entityLocalId: const Value('template-local'),
              payloadJson:
                  '{"name":"失败后重试","content":"{\\"title\\":\\"保持本地副本\\"}"}',
              createdAt: now,
            ),
          );

      final pushed = await _coordinator(db, _failingSyncClient()).push();

      expect(pushed, 0);
      final template = await db.select(db.todoTemplates).getSingle();
      expect(template.serverId, isNull);
      final change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.status, 'retryable');
      expect(change.attemptCount, 1);
    },
  );
}

SyncCoordinator _coordinator(AppDatabase db, ApiClient client) =>
    SyncCoordinator(
      db: db,
      api: SyncApi(
        client,
        clientId: 'template-test',
        deviceId: 'template-test',
      ),
      todoApi: client,
    );

class _TemplateSyncServer {
  final List<Map<String, dynamic>> templatePushes = [];
  final List<Map<String, dynamic>> templateDeletes = [];
  var _pullCount = 0;

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/sync/push')) {
            final changes = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            for (final change in changes) {
              if (change['entityType'] != SyncEntities.template) continue;
              if (change['operation'] == SyncOps.delete) {
                templateDeletes.add(change);
              } else {
                templatePushes.add(change);
              }
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': changes
                        .map(
                          (change) => {
                            'entityType': change['entityType'],
                            'entityId': _serverIdFor(change['entityType']),
                            'operation': change['operation'],
                            'clientMutationId': change['clientMutationId'],
                          },
                        )
                        .toList(),
                    'conflicts': <Map<String, dynamic>>[],
                  },
                },
              ),
            );
            return;
          }
          if (options.path.endsWith('/sync/pull')) {
            _pullCount++;
            final isFirstPull = _pullCount == 1;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': isFirstPull
                        ? [
                            {
                              'entityType': SyncEntities.template,
                              'entityId': 70,
                              'operation': SyncOps.upsert,
                              'revision': 1,
                              'payload': {
                                'name': '周报模板',
                                'content': jsonEncode({
                                  'title': '撰写周报',
                                  'description': '仅保存任务快照',
                                  'priority': 2,
                                }),
                              },
                            },
                          ]
                        : <Map<String, dynamic>>[],
                    'tombstones': isFirstPull
                        ? <Map<String, dynamic>>[]
                        : [
                            {
                              'entityType': SyncEntities.template,
                              'entityId': 70,
                              'revision': 2,
                            },
                          ],
                    'nextCursor': isFirstPull ? 'template-1' : 'template-2',
                    'hasMore': false,
                  },
                },
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'template sync must not use ${options.path}',
            ),
          );
        },
      ),
    );
    return ApiClient(dio: dio);
  }

  int _serverIdFor(Object? entityType) => switch (entityType) {
    SyncEntities.list => 10,
    SyncEntities.task => 20,
    SyncEntities.template => 70,
    _ => 99,
  };
}

ApiClient _failingSyncClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(requestOptions: options, error: 'network unreachable'),
      ),
    ),
  );
  return ApiClient(dio: dio);
}
