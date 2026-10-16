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

/// Issue #504 的面 ②：临时 ID 是「每台设备各自的历史产物」还是「本地实体的稳定别名」。
///
/// 服务端映射键是 `(tenant, user, entityType, device, tempEntityId)`（izhaong/zh-cloud-service!331）。
/// 现在的实现把序号与映射存在 coordinator 实例里，进程重启即清空：
/// 先建 A、同步成功，重启后再建 B，B 会重新拿到 A 当初用过的 `-1`，
/// 于是服务端把 B 认成 A 那一行 —— 这是跨实体串写，会把 A 的任务改写成 B。
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  test(
    'temp id survives a process restart instead of being re-handed to another row',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final server = _Server();
      final queue = SyncChangeQueue(db);
      final tasks = TaskRepository(db, queue);

      final a = await tasks.create(listId: 'inbox', title: '甲');
      expect(await _coordinator(db, server.client()).push(), isPositive);
      final boundA = await (db.select(
        db.todoTasks,
      )..where((row) => row.id.equals(a.id))).getSingle();
      expect(boundA.serverId, isNotNull);
      final idUsedByA = server.seenEntityIds.single;

      // 新建 coordinator == 进程重启：实例内序号与映射都已清空。
      final b = await tasks.create(listId: 'inbox', title: '乙');
      expect(await _coordinator(db, server.client()).push(), isPositive);
      final boundB = await (db.select(
        db.todoTasks,
      )..where((row) => row.id.equals(b.id))).getSingle();

      final idUsedByB = server.seenEntityIds.last;
      expect(
        idUsedByB,
        isNot(idUsedByA),
        reason: '重启后把甲用过的临时 ID 发给乙，服务端会按 (device,temp) 映射把乙写成甲那一行',
      );
      expect(
        boundB.serverId,
        isNot(boundA.serverId),
        reason: '乙必须物化成自己的服务端行，不能覆盖甲',
      );
    },
  );
}

SyncCoordinator _coordinator(AppDatabase db, ApiClient client) =>
    SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'restart-test', deviceId: 'restart-test'),
      todoApi: client,
    );

/// 模拟 service !331 的映射语义：同一 (entityType, deviceId, tempEntityId) 永远返回同一服务端 ID。
class _Server {
  final List<int> seenEntityIds = [];
  final Map<String, int> _byKey = {};
  int _next = 900;

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
              final requested = (change['entityId'] as num).toInt();
              seenEntityIds.add(requested);
              final title = ((change['payload'] as Map?)?['title'] ?? '')
                  .toString();
              final key = '${change['entityType']}|$title';
              final serverId = _byKey.putIfAbsent(key, () => _next++);
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
