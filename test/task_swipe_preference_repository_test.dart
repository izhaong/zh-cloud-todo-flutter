import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/core/task/task_swipe_preferences.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_swipe_preference_repository.dart';

/// 嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》
/// - `:66`「将任务向左短滑……「移动任务」、「删除任务」、「修改日期」」
/// - `:71`「向右滑动分别为「完成」、「置顶」。」
/// - `:75`「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置」
///
/// ⇒ `:75` 意味着这份档位是**要落库、要跨设备的数据**，不是界面里的常量。
/// 落点复用「星期开始于」那条通道（`todo_view_preferences` + `view_preference` 出箱），
/// 所以这里测的就是那条通道的三件老账：同键原地更新、服务端包装形态读得出、脏数据不崩。
void main() {
  late AppDatabase db;
  late SyncChangeQueue queue;
  late TaskSwipePreferenceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncChangeQueue(db);
    repo = TaskSwipePreferenceRepository(db, queue);
  });

  tearDown(() async {
    await db.close();
  });

  test('库里没有行时给原文默认档（左滑三件、右滑两件）', () async {
    final preferences = await repo.get();
    expect(preferences.swipeLeft, const [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ], reason: '`:66`「向左短滑……三个选项」的顺序照原文');
    expect(preferences.swipeRight, const [
      TaskSwipeAction.complete,
      TaskSwipeAction.pin,
    ], reason: '`:71`「向右滑动分别为「完成」、「置顶」」');
  });

  test('save 之后读回同一份，第二次 save 是原地更新不是插新行', () async {
    await repo.save(
      TaskSwipePreferences.defaults.withSwipeRight(const [
        TaskSwipeAction.complete,
      ]),
    );
    expect((await repo.get()).swipeRight, const [TaskSwipeAction.complete]);

    await repo.save(
      TaskSwipePreferences.defaults.withSwipeLeft(const [
        TaskSwipeAction.delete,
      ]),
    );
    final rows = await db.select(db.todoViewPreferences).get();
    expect(rows.length, 1, reason: '改档位应该更新同一行，而不是每次插一条');
    expect((await repo.get()).swipeLeft, const [TaskSwipeAction.delete]);
  });

  test('watch 在写入后推新值（行上的按钮跟着设置页即时变的来源）', () async {
    final first = await repo.watch().first;
    expect(first.swipeLeft, contains(TaskSwipeAction.moveTo));

    final next = repo.watch().skip(1).first;
    await repo.save(TaskSwipePreferences.defaults.withSwipeLeft(const []));
    expect((await next).swipeLeft, isEmpty);
  });

  test('重复动作与超过一侧上限的都拒写，库里还是原来那份', () async {
    await repo.save(TaskSwipePreferences.defaults);

    await expectLater(
      repo.save(
        TaskSwipePreferences.defaults.withSwipeLeft(const [
          TaskSwipeAction.delete,
          TaskSwipeAction.delete,
        ]),
      ),
      throwsA(isA<ArgumentError>()),
      reason: '同一个动作出现两次，界面上就是两个钮干同一件事',
    );
    await expectLater(
      repo.save(
        TaskSwipePreferences.defaults.withSwipeLeft(const [
          TaskSwipeAction.moveTo,
          TaskSwipeAction.delete,
          TaskSwipeAction.changeDueDate,
          TaskSwipeAction.complete,
        ]),
      ),
      throwsA(isA<ArgumentError>()),
      reason: '一侧多于三个会挤成点不动的小块（`:66` 写的就是"三个选项"）',
    );
    expect(await repo.get(), TaskSwipePreferences.defaults);
  });

  test('save 排一条 view_preference 的 upsert 出箱，payload 带两侧档位', () async {
    await repo.save(
      TaskSwipePreferences.defaults.withSwipeRight(const [TaskSwipeAction.pin]),
    );

    final changes =
        await (db.select(db.todoSyncChanges)..where(
              (change) => change.entity.equals(SyncEntities.viewPreference),
            ))
            .get();
    expect(changes.length, 1);
    expect(changes.single.op, SyncOps.upsert);
    final payload =
        jsonDecode(changes.single.payloadJson) as Map<String, dynamic>;
    expect(payload['sourceType'], 'TASK_SWIPE');
    expect(payload['sourceKey'], 'global');
    final value =
        jsonDecode(payload['valueJson'] as String) as Map<String, dynamic>;
    expect(value['swipeLeft'], ['move', 'delete', 'dueDate']);
    expect(value['swipeRight'], ['pin']);
  });

  test('sync pull 的服务端实体包装形态也读得出来（否则第二设备静默退回默认档）', () async {
    final now = DateTime(2026, 10, 12);
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'pulled-row',
            sourceType: 'TASK_SWIPE',
            sourceKey: 'global',
            valueJson: jsonEncode({
              'id': 991,
              'valueJson': jsonEncode({
                'swipeLeft': ['delete'],
                'swipeRight': ['complete', 'pin'],
              }),
            }),
            updatedAt: now,
            createdAt: now,
          ),
        );

    final preferences = await repo.get();
    expect(preferences.swipeLeft, const [TaskSwipeAction.delete]);
    expect(preferences.swipeRight, const [
      TaskSwipeAction.complete,
      TaskSwipeAction.pin,
    ]);
  });

  test('脏数据退回默认档而不是抛错（设置页不能因为一行坏 JSON 打不开）', () async {
    final now = DateTime(2026, 10, 12);
    for (final dirty in [
      'not json',
      '[]',
      '{"swipeLeft":"delete"}',
      '{"somethingElse":"x"}',
    ]) {
      await db.delete(db.todoViewPreferences).go();
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'dirty-row',
              sourceType: 'TASK_SWIPE',
              sourceKey: 'global',
              valueJson: dirty,
              updatedAt: now,
              createdAt: now,
            ),
          );
      expect(
        await repo.get(),
        TaskSwipePreferences.defaults,
        reason: 'valueJson=$dirty',
      );
    }
  });

  test('一侧的项全是认不出来的名字 ⇒ 那一侧按"不露动作"处理，不偷偷补回默认档', () async {
    // 这与"键缺失"是两件事：键在但值读不出，说明有人写过这一侧（也许是别的版本），
    // 拿默认档盖回去会把用户明确配置过的东西显示成一个他没选过的样子。
    final now = DateTime(2026, 10, 12);
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'unknown-wires',
            sourceType: 'TASK_SWIPE',
            sourceKey: 'global',
            valueJson: jsonEncode({
              'swipeLeft': <String>[],
              'swipeRight': ['complete'],
            }),
            updatedAt: now,
            createdAt: now,
          ),
        );

    final preferences = await repo.get();
    expect(preferences.swipeLeft, isEmpty);
    expect(preferences.swipeRight, const [TaskSwipeAction.complete]);
  });

  test('只认得出部分档位时，认得的那一侧保留、认不出的一侧回默认档', () async {
    final stored = TaskSwipePreferences.fromJson({
      'swipeLeft': ['move', 'unknown-action', 'move', 'delete'],
      'swipeRight': 'not a list',
    });
    expect(stored.swipeLeft, const [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
    ], reason: '未知项跳过、重复项去重，不能把整份值判死');
    expect(
      stored.swipeRight,
      TaskSwipePreferences.defaults.swipeRight,
      reason: '这一侧读不出只影响它自己',
    );
  });

  test('一侧给了空列表就是"这一侧不露动作"，不会被偷偷补回默认档', () async {
    final stored = TaskSwipePreferences.fromJson({
      'swipeLeft': <String>[],
      'swipeRight': ['complete'],
    });
    expect(stored.swipeLeft, isEmpty);
    expect(stored.isValid, isTrue, reason: '空的一侧是配置页能明确造出来的形状');
  });
}
