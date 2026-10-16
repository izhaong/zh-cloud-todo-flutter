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
import 'package:zh_cloud_todo_flutter/features/task/smart_grouping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_grouping_preference_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

/// 清单作用域视图偏好的跨设备键（FL #619）。
///
/// 缺陷形状：`TASK_SORT`/`TASK_GROUP` 把**本设备生成的清单 UUID** 当 sourceKey 发出去，
/// 而同步层只对 `task_view` 做 `list:<本地id>` ⇄ `list-server:<serverId>` 归一
/// （`sync_coordinator.dart:610`/`:1921`）。两台设备对同一个服务端清单各写各的键 ⇒
/// 服务端里是两条互不相干的行 ⇒ 「每清单排序/智能分组」其实从没跨端生效过。
void main() {
  Future<void> seedList(
    AppDatabase db, {
    required String id,
    int? serverId,
  }) async {
    final now = DateTime.utc(2026, 7, 30, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: id,
            serverId: serverId == null ? const Value.absent() : Value(serverId),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
  }

  /// 抓出站那一条 view_preference 的 payload。
  Dio pushCatchingDio(List<Map<String, dynamic>> sink) => Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          for (final change in (options.data as Map)['changes'] as List) {
            final map = (change as Map).cast<String, dynamic>();
            if (map['entityType'] == 'view_preference') sink.add(map);
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'ok': true,
                  'accepted': [
                    for (final change
                        in (options.data as Map)['changes'] as List)
                      {
                        'entityType': (change as Map)['entityType'],
                        'entityId': 401,
                        'operation': change['operation'],
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

  SyncCoordinator coordinatorFor(AppDatabase db, ApiClient api) =>
      SyncCoordinator(
        db: db,
        api: SyncApi(api, clientId: 'test', deviceId: 'device-a'),
        todoApi: api,
      );
  test('排序偏好出站按服务端清单编号归一键（不是本设备 UUID）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedList(db, id: 'list-local-a', serverId: 101);
    await TaskSortPreferenceRepository(
      db,
      SyncChangeQueue(db),
    ).save('list-local-a', TaskSort.tag);

    final sent = <Map<String, dynamic>>[];
    final coordinator = coordinatorFor(
      db,
      ApiClient(dio: pushCatchingDio(sent)),
    );

    expect(await coordinator.push(), greaterThanOrEqualTo(1));
    final payload = sent.single['payload'] as Map<String, dynamic>;
    expect(payload['sourceType'], 'TASK_SORT');
    expect(
      payload['sourceKey'],
      'list-server:101',
      reason: '本地 UUID 只有这台设备认识；跨端必须用服务端清单编号',
    );
    final local = await (db.select(db.todoViewPreferences)).getSingle();
    expect(
      local.sourceKey,
      'list-local-a',
      reason: '归一只发生在出箱 payload，本地行仍按本设备形状存',
    );
  });

  test('智能分组偏好出站同样按服务端清单编号归一键', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedList(db, id: 'list-local-a', serverId: 101);
    await TaskGroupingPreferenceRepository(
      db,
      SyncChangeQueue(db),
    ).save('list-local-a', SmartGrouping.byTag);

    final sent = <Map<String, dynamic>>[];
    final coordinator = coordinatorFor(
      db,
      ApiClient(dio: pushCatchingDio(sent)),
    );

    expect(await coordinator.push(), greaterThanOrEqualTo(1));
    final payload = sent.single['payload'] as Map<String, dynamic>;
    expect(payload['sourceType'], 'TASK_GROUP');
    expect(payload['sourceKey'], 'list-server:101');
  });

  test('收集箱的排序偏好与设备无关，出站保持固定串、也不许被吞掉', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // 收集箱传的是**它自己的清单 id** `'inbox'`（`home_shell.dart` 的
    // `_effectiveListId` 对 `SmartList.inbox` 就返回这个字面量）。
    // `null` 是另一回事：智能清单等「无清单上下文」的页面（FL #619 后半）。
    await TaskSortPreferenceRepository(
      db,
      SyncChangeQueue(db),
    ).save('inbox', TaskSort.dueDate);

    final sent = <Map<String, dynamic>>[];
    final coordinator = coordinatorFor(
      db,
      ApiClient(dio: pushCatchingDio(sent)),
    );

    expect(await coordinator.push(), greaterThanOrEqualTo(1));
    final payload = sent.single['payload'] as Map<String, dynamic>;
    expect(
      payload['sourceKey'],
      'inbox',
      reason: '收集箱在每台设备上都是同一个字面量，本来就是跨端一致的键',
    );
  });

  test('清单还没上服务端时排序偏好不发（与视图模式同口径）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedList(db, id: 'list-local-new');
    await TaskSortPreferenceRepository(
      db,
      SyncChangeQueue(db),
    ).save('list-local-new', TaskSort.tag);

    final sent = <Map<String, dynamic>>[];
    final coordinator = coordinatorFor(
      db,
      ApiClient(dio: pushCatchingDio(sent)),
    );

    await coordinator.push();
    expect(
      sent.where((change) => change['entityType'] == 'view_preference'),
      isEmpty,
      reason: '发一个别的设备认不出的本地 UUID，等于把脏键写进服务端',
    );
  });

  test('排序偏好入站写回本设备形状，仓储按本地清单读得到对方的档位', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'entityType': 'list',
                        'entityId': 101,
                        'operation': 'upsert',
                        'revision': 1,
                        'payload': jsonDecode('{"name":"项目","sortOrder":0}'),
                      },
                      {
                        'entityType': 'view_preference',
                        'entityId': 501,
                        'operation': 'upsert',
                        'revision': 2,
                        'payload': {
                          'sourceType': 'TASK_SORT',
                          'sourceKey': 'list-server:101',
                          'valueJson':
                              '{"sort":"tag","direction":"newestFirst"}',
                        },
                      },
                    ],
                    'tombstones': const [],
                    'nextCursor': '2',
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
    final api = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(api, clientId: 'test', deviceId: 'device-b'),
      todoApi: api,
    );

    expect(await coordinator.pull(), 2);
    final localList = await db.listByServerId(101);
    expect(localList, isNotNull);
    final row =
        await (db.select(
              db.todoViewPreferences,
            )..where((preference) => preference.sourceType.equals('TASK_SORT')))
            .getSingle();
    expect(
      row.sourceKey,
      localList!.id,
      reason: '入站必须把规范键换回本设备的清单 id，否则读取侧按 listId 找不到这行',
    );
    final readBack = await TaskSortPreferenceRepository(
      db,
      SyncChangeQueue(db),
    ).get(localList.id);
    expect(
      readBack.sort,
      TaskSort.tag,
      reason: '端到端判据：别的设备设的档位，这台设备按自己的清单 id 读得到',
    );
  });

  test('入站遇到本设备还没有的清单就跳过，不留下没人认识的键', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'entityType': 'view_preference',
                        'entityId': 502,
                        'operation': 'upsert',
                        'revision': 1,
                        'payload': {
                          'sourceType': 'TASK_GROUP',
                          'sourceKey': 'list-server:999',
                          'valueJson': '{"grouping":"byTag"}',
                        },
                      },
                    ],
                    'tombstones': const [],
                    'nextCursor': '1',
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
    final api = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(api, clientId: 'test', deviceId: 'device-c'),
      todoApi: api,
    );

    await coordinator.pull();
    expect(
      await db.select(db.todoViewPreferences).get(),
      isEmpty,
      reason: '清单还没落地时写入规范键，只会攒下一条本地读不到的死行',
    );
  });
}
