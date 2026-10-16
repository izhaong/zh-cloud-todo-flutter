import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';

/// 复现并锁住真实用户库里的冲突：
///
/// v1.0.8 机器上 `todo_t1_u286.sqlite` 出现 6 条
/// `view_preference / REVISION_CONFLICT` failed，界面弹
/// 「6 项同步需要处理 / 其中 6 项与其他设备冲突，已采用服务器版本」。
///
/// 成因：同实体（serverId=2）排了 3 条 outbox，各自带相同 baseRevision=24，
/// 同批推送时第一条被接受（服务端 revision→25），其余两条必然冲突；而 push()
/// 只取 queued|retryable，failed 行永不被重取 ⇒ 横幅永久挂着。
///
/// 修复：批内同实体只发最后一条（payload 是全量快照，后写覆盖前写）。
void main() {
  /// 服务端按 "同一实体只接受第一条、其余冲突" 的真实语义模拟：
  /// 每次接收都让该实体的 revision +1，并把与当前 revision 不符的判为冲突。
  Dio revisionAwareDio({
    required List<Map<String, dynamic>> received,
    required Map<String, int> serverRevision,
    required List<String> conflictMutationIds,
  }) {
    return Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final changes = ((options.data as Map)['changes'] as List)
                .cast<Map>();
            final accepted = <Map<String, dynamic>>[];
            final conflicts = <Map<String, dynamic>>[];
            for (final change in changes) {
              final map = change.cast<String, dynamic>();
              received.add(map);
              final key = '${map['entityType']}#${map['entityId']}';
              final current = serverRevision[key] ?? 0;
              final base = (map['baseRevision'] as num?)?.toInt() ?? 0;
              if (base == current) {
                // 接受并将其 revision 推进一版。
                serverRevision[key] = current + 1;
                accepted.add({
                  'clientMutationId': map['clientMutationId'],
                  'entityType': map['entityType'],
                  'entityId': map['entityId'],
                  'operation': map['operation'],
                  'revision': current + 1,
                });
              } else {
                conflicts.add({
                  'clientMutationId': map['clientMutationId'],
                  'entityType': map['entityType'],
                  'entityId': map['entityId'],
                  'reason': 'REVISION_CONFLICT',
                  'serverRevision': current,
                });
                conflictMutationIds.add(map['clientMutationId'] as String);
              }
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': accepted,
                    'conflicts': conflicts,
                  },
                },
              ),
            );
          },
        ),
      );
  }

  SyncCoordinator coordinatorFor(AppDatabase db, ApiClient api) =>
      SyncCoordinator(
        db: db,
        api: SyncApi(api, clientId: 'test', deviceId: 'device-a'),
        todoApi: api,
      );

  Future<AppDatabase> seedPreference() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // 已同步的日历偏好：服务端 id=2，本地镜像 revision=24（复刻真实库）。
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'pref-local',
            serverId: const Value(2),
            sourceType: 'CALENDAR_INFO',
            sourceKey: 'global',
            valueJson: '{"showLunar":false}',
            updatedAt: DateTime.utc(2026, 8, 1),
            createdAt: DateTime.utc(2026, 8, 1),
          ),
        );
    await db.writeRevision(SyncEntities.viewPreference, 2, 24);
    return db;
  }

  test('同实体多条 outbox 只发最后一条：不再出现 REVISION_CONFLICT（用户 bug 复现）', () async {
    final db = await seedPreference();
    final queue = SyncChangeQueue(db);

    // 用户连点三次「显示农历」开关 ⇒ 真实库里就是 3 条同 serverId 的 outbox。
    for (final showLunar in [true, false, true]) {
      await queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: 'pref-local',
        serverId: 2,
        payload: {
          'sourceType': 'CALENDAR_INFO',
          'sourceKey': 'global',
          'viewType': 'LIST',
          'valueJson': '{"showLunar":$showLunar}',
        },
      );
    }
    expect(
      await (db.select(
        db.todoSyncChanges,
      )..where((r) => r.status.equals('queued'))).get(),
      hasLength(3),
      reason: '前提：enqueue 不去重，真实库里确实排出 3 条',
    );

    final received = <Map<String, dynamic>>[];
    final conflicts = <String>[];
    final serverRevision = <String, int>{'view_preference#2': 24};
    final coordinator = coordinatorFor(
      db,
      ApiClient(
        dio: revisionAwareDio(
          received: received,
          serverRevision: serverRevision,
          conflictMutationIds: conflicts,
        ),
      ),
    );

    await coordinator.push();

    expect(
      received,
      hasLength(1),
      reason: '同实体只应发一条；发多条会让后续条目撞 REVISION_CONFLICT',
    );
    expect(conflicts, isEmpty, reason: '这正是用户看到的「与其他设备冲突」横幅来源，必须为空');
    expect(received.single['baseRevision'], 24, reason: '发出去的那条带当前基线');

    // 最后一条（showLunar=true）胜出；被取代的两条留痕但不再是待发送态。
    final all = await db.select(db.todoSyncChanges).get();
    expect(all, hasLength(3), reason: '不物理删除，保留审计与幂等键');
    expect(
      all.where((r) => r.status == 'resolved').length,
      2,
      reason: '被取代的两条置 resolved',
    );
    expect(
      all.where((r) => r.status == 'queued' || r.status == 'synced').length,
      1,
    );
  });

  test('不同操作的 task outbox 不被合并（缩进 + 排序都必须送达）', () async {
    // 与 task_hierarchy_actions_test 的契约一致：同一 task 的缩进与排序是
    // 两次不同字段的写入，虽然 payload 都是全量快照，但本地审计要求两条都留。
    // 真正的约束是"同批只发最后一条"，这里验证不同 localId 不互相取代。
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 8, 1);
    final queue = SyncChangeQueue(db);

    await queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: 'task-a',
      payload: {'title': 'A'},
    );
    await queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: 'task-b',
      payload: {'title': 'B'},
    );

    final received = <Map<String, dynamic>>[];
    final coordinator = coordinatorFor(
      db,
      ApiClient(
        dio: revisionAwareDio(
          received: received,
          serverRevision: {},
          conflictMutationIds: [],
        ),
      ),
    );
    await coordinator.push();

    expect(received, hasLength(2), reason: '不同实体行的变更都要送达，不能被合并逻辑吞掉');
    expect(now.year, 2026);
  });
}
