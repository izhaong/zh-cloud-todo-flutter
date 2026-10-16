import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// Issue #504 的第 1 面：临时实体 ID 必须「一个本地实体一个，且不回收复用」。
///
/// 服务端已把 `todo_sync_temp_id` 的唯一键定在 `(tenant, user, entity_type, device, temp_entity_id)`
/// （izhaong/zh-cloud-service!331）。于是客户端一旦把某个临时 ID 让给另一条本地实体，
/// 服务端会把新实体认成老的那一行 —— 这不是重复物化，是跨实体串写。
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  test(
    'later batches must not hand an already-used temporary id to another local row',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final server = _TempIdServer();
      final queue = SyncChangeQueue(db);
      final tasks = TaskRepository(db, queue);
      final coordinator = _coordinator(db, server.client());

      final first = await tasks.create(listId: 'inbox', title: '甲');
      expect(await coordinator.push(), 1);
      final boundFirst = await (db.select(
        db.todoTasks,
      )..where((row) => row.id.equals(first.id))).getSingle();
      expect(boundFirst.serverId, isNotNull);
      final tempIdOfFirst = server.seenEntityIds.single;

      // 第二条未同步的本地任务：不能把甲用过的临时 ID 再发一遍（那个号在服务端已绑到甲的行）
      final second = await tasks.create(listId: 'inbox', title: '乙');
      expect(await coordinator.push(), 1);
      final boundSecond = await (db.select(
        db.todoTasks,
      )..where((row) => row.id.equals(second.id))).getSingle();

      expect(server.seenEntityIds, hasLength(2));
      expect(
        server.seenEntityIds.last,
        isNot(tempIdOfFirst),
        reason: '批次之间重新分配临时 ID，会让第二条任务复用第一条的号',
      );
      expect(
        boundSecond.serverId,
        isNot(boundFirst.serverId),
        reason: '乙复用甲用过的临时 ID，会被服务端 (device,temp) 映射认成甲那一行',
      );
    },
  );
}

SyncCoordinator _coordinator(AppDatabase db, ApiClient client) =>
    SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'temp-id-test', deviceId: 'temp-id-test'),
      todoApi: client,
    );

/// 只覆盖本用例需要的两个端点：push 按「临时 ID 首次出现即分配服务端 ID」应答，
/// pull 永远为空。分配规则与 service !331 的 `todo_sync_temp_id` 一致。
class _TempIdServer {
  final List<int> seenEntityIds = [];
  final Map<int, int> _serverIdByEntityId = {};
  int _nextServerId = 900;

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/sync/pull')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': <Map<String, dynamic>>[],
                    'tombstones': <Map<String, dynamic>>[],
                    'nextCursor': '0',
                    'hasMore': false,
                    'serverTime': 0,
                  },
                },
              ),
            );
            return;
          }
          if (options.path.endsWith('/sync/push')) {
            final changes = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final accepted = <Map<String, dynamic>>[];
            for (final change in changes) {
              if (change['entityType'] != SyncEntities.task) continue;
              final requestedId = (change['entityId'] as num).toInt();
              seenEntityIds.add(requestedId);
              final serverId = _serverIdByEntityId.putIfAbsent(
                requestedId,
                () => _nextServerId++,
              );
              accepted.add({
                'entityType': SyncEntities.task,
                'entityId': serverId,
                'operation': change['operation'],
                'revision': 1,
                'clientMutationId': change['clientMutationId'],
              });
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': accepted,
                    'conflicts': <Map<String, dynamic>>[],
                  },
                },
              ),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );
    return ApiClient(dio: dio);
  }
}
