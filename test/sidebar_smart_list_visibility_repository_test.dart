import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

/// specs/103：智能清单三态（显示 / 隐藏 / 有内容时显示）的存取。
///
/// 嘀嗒《02-用清单管理任务.md》:45「我们提供了三种显示状态」、
/// :20「（收集箱是不可以被隐藏或删除。）」。
void main() {
  Future<(AppDatabase, SidebarVisibilityRepository)> open() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return (db, SidebarVisibilityRepository(db, SyncChangeQueue(db)));
  }

  test('默认全「显示」：没写过的清单不出现在映射里，消费侧按缺键=show 兜底', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    expect(await repository.getSmartListStates(), isEmpty);
  });

  test('保存三态落同一行并进 outbox；patch 不冲掉 showTags 与其它清单键', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    await repository.save(showTags: false);
    await repository.saveSmartListState('today', SmartListVisibility.hide);
    expect(await repository.get(), isFalse, reason: '写智能清单三态不许把「显示标签」顶回默认');
    expect(
      (await repository.getSmartListStates())['today'],
      SmartListVisibility.hide,
    );

    await repository.saveSmartListState('upcoming', SmartListVisibility.auto);
    final states = await repository.getSmartListStates();
    expect(states['today'], SmartListVisibility.hide, reason: '第二个键的写入不许覆盖第一个');
    expect(states['upcoming'], SmartListVisibility.auto);

    final rows = await db.select(db.todoViewPreferences).get();
    expect(rows, hasLength(1), reason: '三态必须与既有偏好共行（同 sourceType/sourceKey）');
    final changes = await db.select(db.todoSyncChanges).get();
    final payload =
        jsonDecode(changes.last.payloadJson) as Map<String, dynamic>;
    final valueJson =
        jsonDecode(payload['valueJson'] as String) as Map<String, dynamic>;
    expect(valueJson['smartList.today'], 'hide');
    expect(valueJson['smartList.upcoming'], 'auto');
    expect(valueJson['showTags'], false);
  });

  test('watch 流跟着写走', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    expect(await repository.watchSmartListStates().first, isEmpty);
    await repository.saveSmartListState('tomorrow', SmartListVisibility.hide);
    expect(
      (await repository.watchSmartListStates().first)['tomorrow'],
      SmartListVisibility.hide,
    );
  });

  test('收集箱守卫：非「显示」一律 ArgumentError（嘀嗒 :20，显式保护不靠没入口）', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    // 守卫在进 Future 之前就同步抛 ⇒ 用同步 matcher，await expectLater 会先炸在调用点。
    expect(
      () => repository.saveSmartListState('inbox', SmartListVisibility.hide),
      throwsArgumentError,
    );
    expect(
      () => repository.saveSmartListState('inbox', SmartListVisibility.auto),
      throwsArgumentError,
    );
    expect(
      (await repository.getSmartListStates())['inbox'],
      isNull,
      reason: '被拒的写入不该留下半条状态',
    );
  });

  test('坏 JSON 回默认：读不懂的偏好不许锁死侧栏', () async {
    final (db, repository) = await open();
    addTearDown(db.close);
    final now = DateTime.now();
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'bad-json',
            sourceType: SidebarVisibilityRepository.sourceType,
            sourceKey: SidebarVisibilityRepository.sourceKey,
            valueJson: 'not-json',
            updatedAt: now,
            createdAt: now,
          ),
        );

    expect(await repository.getSmartListStates(), isEmpty);
  });
}
