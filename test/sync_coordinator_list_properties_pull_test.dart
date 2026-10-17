import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

/// specs/105：sync pull 对清单四属性（icon/backgroundType/backgroundValue/
/// showInSmartList）的三态——键在场跟随对端（显式 null 即清除）、键缺席保留
/// 本地值、backgroundType 空串按 theme 归一化。
void main() {
  test('pull 四键三态：跟随/清除/保留 + 空串归 theme', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    List<Map<String, dynamic>>? nextChanges;
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/folder/list')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {'code': 0, 'data': []},
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
                    'changes': nextChanges ?? const [],
                    'tombstones': [],
                    'nextCursor': 'todo-core:0',
                    'hasMore': false,
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
      api: SyncApi(client, clientId: 'props-pull', deviceId: 'props-pull'),
      todoApi: client,
    );

    Future<Map<String, dynamic>?> rowByServer(int serverId) async {
      final rows = await db.select(db.todoLists).get();
      final match = rows.where((r) => r.serverId == serverId).toList();
      return match.isEmpty ? null : match.single.toJson();
    }

    Map<String, dynamic> change(
      Map<String, dynamic> payload, {
      int revision = 1,
    }) => {
      'changeId': revision,
      'entityType': 'list',
      'entityId': 101,
      'operation': 'upsert',
      'revision': revision,
      'tombstone': false,
      'payload': payload,
    };

    // 1) 首次 pull：四键全带。
    nextChanges = [
      change({
        'id': 101,
        'name': '旅行',
        'icon': '✈️',
        'backgroundType': 'gradient',
        'backgroundValue': '#A1C4FD,#C2E9FB',
        'showInSmartList': false,
        'sortOrder': 0,
      }),
    ];
    await coordinator.pull();
    var row = await rowByServer(101);
    expect(row, isNotNull);
    expect(row!['icon'], '✈️');
    expect(row['backgroundType'], 'gradient');
    expect(row['backgroundValue'], '#A1C4FD,#C2E9FB');
    expect(row['showInSmartList'], isFalse);

    // 2) 显式 null：对端清除，本地跟着清。
    nextChanges = [
      change({
        'id': 101,
        'name': '旅行',
        'icon': null,
        'backgroundType': 'theme',
        'backgroundValue': null,
        'showInSmartList': true,
        'sortOrder': 0,
      }, revision: 2),
    ];
    await coordinator.pull();
    row = await rowByServer(101);
    expect(row!['icon'], isNull);
    expect(row['backgroundType'], 'theme');
    expect(row['backgroundValue'], isNull);
    expect(row['showInSmartList'], isTrue);

    // 3) 先把本地摆出非默认值，再拉一条缺四键的 payload：保留本地。
    await (db.update(db.todoLists)..where((t) => t.serverId.equals(101))).write(
      const TodoListsCompanion(
        icon: Value('🏨'),
        backgroundType: Value('color'),
        backgroundValue: Value('#4772FA'),
        showInSmartList: Value(false),
      ),
    );
    nextChanges = [
      change({'id': 101, 'name': '旅行', 'sortOrder': 0}, revision: 3),
    ];
    await coordinator.pull();
    row = await rowByServer(101);
    expect(row!['icon'], '🏨', reason: '缺键 = 对端没说，保留本地');
    expect(row['backgroundType'], 'color');
    expect(row['backgroundValue'], '#4772FA');
    expect(row['showInSmartList'], isFalse);

    // 4) backgroundType 空串按 theme 归一化，值同时清空由服务端口径兜底。
    nextChanges = [
      change({
        'id': 101,
        'name': '旅行',
        'backgroundType': '',
        'backgroundValue': '#4772FA',
        'sortOrder': 0,
      }, revision: 4),
    ];
    await coordinator.pull();
    row = await rowByServer(101);
    expect(row!['backgroundType'], 'theme');
  });

  test('FL #559：pull 带下「在用成员数」；缺键时**保留旧值**而不是退回 1', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    List<Map<String, dynamic>>? nextChanges;
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/folder/list')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {'code': 0, 'data': []},
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
                    'changes': nextChanges ?? const [],
                    'tombstones': [],
                    'nextCursor': 'todo-core:0',
                    'hasMore': false,
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
      api: SyncApi(client, clientId: 'member-count', deviceId: 'member-count'),
      todoApi: client,
    );

    Map<String, dynamic> change(Map<String, dynamic> payload, int revision) => {
      'changeId': revision,
      'entityType': 'list',
      'entityId': 101,
      'operation': 'upsert',
      'revision': revision,
      'tombstone': false,
      'payload': payload,
    };

    // 1) 服务端带 `memberCount` ⇒ 落库。
    nextChanges = [
      change({
        'id': 101,
        'name': '我建的共享清单',
        'accessRole': 'owner',
        'memberCount': 3,
      }, 1),
    ];
    await coordinator.pull();
    var rows = await db.select(db.todoLists).get();
    expect(rows.single.accessRole, 'owner');
    expect(
      rows.single.memberCount,
      3,
      reason: '判「是不是共享清单」只能用这个数 —— accessRole=owner 时它才是唯一线索',
    );

    // 2) 服务端**不带**这个键（旧版本）⇒ 保留旧值，**不许退回 1**。
    //    退回 1 会把"共享清单"误判成"个人清单"，那是**静默丢掉**用户该看到的任务，
    //    比多显示几条更错。
    nextChanges = [
      change({'id': 101, 'name': '我建的共享清单'}, 2),
    ];
    await coordinator.pull();
    rows = await db.select(db.todoLists).get();
    expect(
      rows.single.memberCount,
      3,
      reason: '缺键保留旧值；退回 1 = 静默丢掉共享清单里指派给我的任务',
    );
  });
}
