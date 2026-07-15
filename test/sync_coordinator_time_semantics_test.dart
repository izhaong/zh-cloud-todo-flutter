import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';

void main() {
  test('pushes a repeat skip with the same temporary rule ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 7, 15, 9);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            serverId: const Value(101),
            listId: 'list-1',
            title: '模板任务',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));
    final rule = await repeats.save(
      taskId: 'task-1',
      frequency: 'CUSTOM',
      weekdays: const [1, 3, 5],
      startAt: now,
    );
    await repeats.skip(
      repeatRuleId: rule.id,
      taskId: 'task-1',
      occurrenceAt: now.add(const Duration(days: 2)),
    );

    List<Map<String, dynamic>> sentChanges = const [];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sentChanges = ((options.data as Map)['changes'] as List)
              .cast<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList();
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'ok': true,
                  'accepted': [
                    for (final change in sentChanges)
                      {
                        'entityType': change['entityType'],
                        'entityId': change['entityType'] == 'repeat_rule'
                            ? 701
                            : 702,
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
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
      todoApi: client,
    );

    expect(await coordinator.push(), 2);
    final ruleChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'repeat_rule',
    );
    final skipChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'repeat_skip',
    );
    expect(ruleChange['entityId'], isNegative);
    expect(skipChange['payload']?['repeatRuleId'], ruleChange['entityId']);
    expect((await db.select(db.todoRepeatRules).getSingle()).serverId, 701);
    expect((await db.select(db.todoRepeatSkips).getSingle()).serverId, 702);
  });
}
