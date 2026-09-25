import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/week_start_preference_repository.dart';

/// FR-4：偏好落在既有的 `todo_view_preferences`（不升 schemaVersion），
/// 并通过 `view_preference` outbox 跨端。
void main() {
  late AppDatabase db;
  late SyncChangeQueue queue;
  late WeekStartPreferenceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncChangeQueue(db);
    repo = WeekStartPreferenceRepository(db, queue);
  });

  tearDown(() async {
    await db.close();
  });

  test('库里没有行时取默认档（周一），不抛错', () async {
    expect(await repo.get(), WeekStartPreferenceRepository.defaultFirstDay);
    expect(await repo.get(), DateTime.monday);
  });

  test('save 之后 get 读回同一档，且第二次 save 是原地更新不是插新行', () async {
    await repo.save(DateTime.sunday);
    expect(await repo.get(), DateTime.sunday);

    await repo.save(DateTime.saturday);
    expect(await repo.get(), DateTime.saturday);

    final rows = await db.select(db.todoViewPreferences).get();
    expect(rows.length, 1, reason: '改档位应该更新同一行，而不是每次插一条');
  });

  test('watch 在写入后推新值（改档位即时生效的来源）', () async {
    final first = await repo.watch().first;
    expect(first, DateTime.monday);

    final next = repo.watch().skip(1).first;
    await repo.save(DateTime.sunday);
    expect(await next, DateTime.sunday);
  });

  test('只接受嘀嗒给的三档，其余值不入库也不改当前档', () async {
    await repo.save(DateTime.monday);

    for (final bad in [
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      0,
      8,
    ]) {
      await expectLater(
        repo.save(bad),
        throwsA(isA<ArgumentError>()),
        reason: 'firstDay=$bad 不是嘀嗒的档位，必须拒写',
      );
    }
    expect(await repo.get(), DateTime.monday);
  });

  test('save 排一条 view_preference 的 upsert 出箱，payload 带档位', () async {
    await repo.save(DateTime.sunday);

    final changes =
        await (db.select(db.todoSyncChanges)..where(
              (change) => change.entity.equals(SyncEntities.viewPreference),
            ))
            .get();
    expect(changes.length, 1);
    expect(changes.single.op, SyncOps.upsert);
    final payload =
        jsonDecode(changes.single.payloadJson) as Map<String, dynamic>;
    expect(payload['sourceType'], 'WEEK_START');
    expect(
      (jsonDecode(payload['valueJson'] as String)
          as Map<String, dynamic>)['weekStart'],
      DateTime.sunday,
    );
  });

  test('sync pull 的服务端实体包装格式也必须读得出来（否则第二设备静默退回默认档）', () async {
    // 本地 save 写的是 `{weekStart}`；服务端 pull 回来的行保留实体包装，
    // 档位落在被字符串化的 valueJson 字段内 —— specs/035 实测过的坑。
    final now = DateTime(2026, 9, 25);
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'pulled-row',
            sourceType: 'WEEK_START',
            sourceKey: 'global',
            valueJson: jsonEncode({
              'id': 991,
              'valueJson': jsonEncode({'weekStart': DateTime.sunday}),
            }),
            updatedAt: now,
            createdAt: now,
          ),
        );

    expect(await repo.get(), DateTime.sunday);
  });

  test('脏数据退回默认档而不是抛错（设置页不能因为一行坏 JSON 打不开）', () async {
    final now = DateTime(2026, 9, 25);
    for (final dirty in ['not json', '[]', '{"weekStart":"sunday"}']) {
      await db.delete(db.todoViewPreferences).go();
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'dirty-row',
              sourceType: 'WEEK_START',
              sourceKey: 'global',
              valueJson: dirty,
              updatedAt: now,
              createdAt: now,
            ),
          );
      expect(await repo.get(), DateTime.monday, reason: 'valueJson=$dirty');
    }
  });
}
