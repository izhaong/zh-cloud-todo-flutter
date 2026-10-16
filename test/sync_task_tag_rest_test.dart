import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

/// 真实闭环复现：任务挂标签在真机上永远同步不上去。
///
/// 实测（2026-10-15，release web + 真实后端）：
/// - 详情面板勾上「工作」后本地 `todo_task_tags` 有行、复选框 `aria-checked=true`；
/// - `/sync/push` 请求体里带着 `{"entityType":"task_tag","payload":{"taskId":…,"tagIds":[…]}}`；
/// - 服务端 `TodoSyncServiceImpl` 对 `ENTITY_TASK_TAG` 直接
///   `throw exception(TODO_SYNC_INVALID_ARGUMENT)`（设计如此：
///   「task_tag 关联表不支持客户端 push，所有变更走 /tag/{task-bind,task-unbind}」）；
/// - 响应 `{"code":1032001003,"msg":"Todo 同步参数无效"}`，而且**同一批里的检查事项
///   被一起拒掉**（整批一个事务），界面既无横幅也无错误。
///
/// 期望：标签绑定走服务端指定的 REST 通道，绝不进 `/sync/push`。
void main() {
  test('任务挂标签走 REST /tag/task-bind，不得塞进 /sync/push 的 task_tag', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.utc(2026, 10, 15);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-local',
            listId: 'list-local',
            title: '带标签的任务',
            serverId: const Value(1311),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            name: '收集箱',
            serverId: const Value(33),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'tag-local',
            name: '工作',
            serverId: const Value(2),
            updatedAt: now,
            createdAt: now,
          ),
        );

    final paths = <String>[];
    final pushedEntities = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path.contains('/sync/push')) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map>();
              pushedEntities.addAll(
                changes.map((c) => c['entityType'].toString()),
              );
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': <Map<String, dynamic>>[],
                      'conflicts': <Map<String, dynamic>>[],
                    },
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'code': 0, 'data': 1},
              ),
            );
          },
        ),
      );

    final api = ApiClient(dio: dio);
    final queue = SyncChangeQueue(db);
    await TagRepository(db, queue).setTaskTags('task-local', ['tag-local']);

    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(api, clientId: 'test', deviceId: 'device-a'),
      todoApi: api,
    );
    await coordinator.push();

    expect(
      paths.where((p) => p == '/app-api/todo/tag/task-bind'),
      isNotEmpty,
      reason: '标签绑定必须走服务端指定的 REST 通道 /tag/task-bind',
    );
    expect(
      pushedEntities,
      isNot(contains('task_tag')),
      reason:
          'task_tag 不在后端 /sync 白名单，塞进去会被整批拒绝（同批的检查事项一起丢）',
    );
  });
}
