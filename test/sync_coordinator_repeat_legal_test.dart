import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

/// specs/083 / FL Issue #324：服务端下发的 `legal-workday` 落到本地必须是 `LEGAL_WORKDAY`。
///
/// 这条是**行为级**覆盖入站调用点（`sync_coordinator` 的 `_upsertLocalRepeatRule`）：
/// helper 自身的往返用例量不到"调用点有没有被换回 `.toUpperCase()`"——
/// 把那一行还原成基线写法后，helper 单测 + 出库用例 + e2e 全绿（本轮实测 rc=0），
/// 所以必须有一条从 `pull()` 进来的用例钉住它。
void main() {
  Future<AppDatabase> seededDb() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-legal-pull',
            listId: 'list-legal-pull',
            title: '节假日晨跑',
            serverId: const Value(500),
            updatedAt: DateTime.parse('2026-02-13T09:00:00'),
            createdAt: DateTime.parse('2026-02-13T09:00:00'),
          ),
        );
    return db;
  }

  SyncCoordinator coordinatorWithRule(
    AppDatabase db,
    Map<String, dynamic> payload,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'changeId': 1,
                        'entityType': 'repeat_rule',
                        'entityId': 900,
                        'operation': 'upsert',
                        'revision': 1,
                        'tombstone': false,
                        'payload': payload,
                      },
                    ],
                    'tombstones': [],
                    'nextCursor': 'todo-core:1',
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
    final client = ApiClient(dio: dio);
    return SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'legal-pull', deviceId: 'legal-pull'),
      todoApi: client,
    );
  }

  test('入站 legal-workday 归一成 LEGAL_WORKDAY，且不落星期集', () async {
    final db = await seededDb();
    final coordinator = coordinatorWithRule(db, {
      'id': 900,
      'taskId': 500,
      'frequency': 'legal-workday',
      'intervalValue': 1,
      'startAt': '2026-02-13T09:00:00',
      'repeatMode': 'ON_DUE',
      'enabled': true,
    });

    await coordinator.pull();

    final rules = await db.select(db.todoRepeatRules).get();
    expect(rules, hasLength(1));
    expect(
      rules.single.freq,
      'LEGAL_WORKDAY',
      reason:
          '带连字符的档位若只 toUpperCase() 会存成 LEGAL-WORKDAY：'
          '匹配不上档位常量、查不到中文文案，用户在详情面看到裸枚举',
    );
    expect(rules.single.byDay, isNull);
  });

  test('入站 legal-holiday 归一成 LEGAL_HOLIDAY', () async {
    final db = await seededDb();
    final coordinator = coordinatorWithRule(db, {
      'id': 901,
      'taskId': 500,
      'frequency': 'legal-holiday',
      'intervalValue': 1,
      'startAt': '2026-05-01T09:00:00',
      'repeatMode': 'ON_DUE',
      'enabled': true,
    });

    await coordinator.pull();

    final rules = await db.select(db.todoRepeatRules).get();
    expect(rules.single.freq, 'LEGAL_HOLIDAY');
  });

  test('老档位入站形状不倒退（weekday 仍是 WEEKDAY）', () async {
    final db = await seededDb();
    final coordinator = coordinatorWithRule(db, {
      'id': 902,
      'taskId': 500,
      'frequency': 'weekday',
      'intervalValue': 1,
      'weekdays': '1,2,3,4,5',
      'startAt': '2026-02-13T09:00:00',
      'repeatMode': 'ON_DUE',
      'enabled': true,
    });

    await coordinator.pull();

    final rules = await db.select(db.todoRepeatRules).get();
    expect(rules.single.freq, 'WEEKDAY');
    expect(rules.single.byDay, '1,2,3,4,5');
  });
}
