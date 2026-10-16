import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/smart_grouping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_grouping_preference_repository.dart';

/// specs/100 智能分组偏好：按清单隔离、离线保存入队、可重启读取；
/// 认不出的档位回退「不分组」（= 功能上线前唯一的行为）。
void main() {
  test('保存后 get 读回、按清单隔离、并入队 viewPreference 同步', () async {
    final databasePath =
        '${Directory.systemTemp.path}/todo-grouping-preference-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final db = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final repository = TaskGroupingPreferenceRepository(db, queue);

    expect(await repository.get('list-a'), SmartGrouping.none);
    await repository.save('list-a', SmartGrouping.byPriority);
    await repository.save('list-b', SmartGrouping.byTime);
    expect(await repository.get('list-a'), SmartGrouping.byPriority);
    expect(await repository.get('list-b'), SmartGrouping.byTime);
    // 收集箱是**真实清单**（id 就是字面量 `inbox`），与 `null`（智能清单等
    // 「无清单上下文」的页面）是两把键，FL #619 后半把它们分开了。
    await repository.save('inbox', SmartGrouping.byList);
    await repository.save(null, SmartGrouping.byTag);
    expect(await repository.get('inbox'), SmartGrouping.byList);
    expect(await repository.get(null), SmartGrouping.byTag);
    expect(await repository.get('list-a'), SmartGrouping.byPriority);

    final changes = await db.select(db.todoSyncChanges).get();
    expect(changes, isNotEmpty);
    expect(
      changes.every((change) => change.entity == 'view_preference'),
      isTrue,
    );
    expect(changes.every((change) => change.op == 'upsert'), isTrue);
  });

  test('重启（重新打开同一库文件）后偏好仍在', () async {
    final databasePath =
        '${Directory.systemTemp.path}/todo-grouping-restart-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final first = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    await TaskGroupingPreferenceRepository(
      first,
      SyncChangeQueue(first),
    ).save('list-a', SmartGrouping.byTag);
    await first.close();

    final second = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File(databasePath)),
    );
    addTearDown(second.close);
    expect(
      await TaskGroupingPreferenceRepository(
        second,
        SyncChangeQueue(second),
      ).get('list-a'),
      SmartGrouping.byTag,
    );
  });

  test('行里是认不出的档位名或坏 JSON 时回退「不分组」', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskGroupingPreferenceRepository(
      db,
      SyncChangeQueue(db),
    );

    Future<void> seed(String json) => db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'pref-1',
            sourceType: 'TASK_GROUP',
            sourceKey: 'list-a',
            valueJson: json,
            createdAt: DateTime(2026, 10, 12),
            updatedAt: DateTime(2026, 10, 12),
          ),
        );

    await seed('{"grouping":"byWhatever"}');
    expect(await repository.get('list-a'), SmartGrouping.none);
    await db
        .update(db.todoViewPreferences)
        .write(
          const TodoViewPreferencesCompanion(valueJson: Value('not-json')),
        );
    expect(await repository.get('list-a'), SmartGrouping.none);
  });
}
