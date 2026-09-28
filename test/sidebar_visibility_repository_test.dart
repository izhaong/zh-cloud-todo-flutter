import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md》:10/:23
/// 「使用前，确认侧边栏中是否已经开启显示标签」⇒ 这是一个要跨端、跨重启留得住的偏好。
void main() {
  Future<(AppDatabase, SidebarVisibilityRepository)> open({
    String? path,
  }) async {
    final db = path == null
        ? AppDatabase.forTesting(NativeDatabase.memory())
        : AppDatabase.forTesting(NativeDatabase.createInBackground(File(path)));
    return (db, SidebarVisibilityRepository(db, SyncChangeQueue(db)));
  }

  test('默认值必须是「显示」：没设置过时侧栏要能看到标签', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    expect(SidebarVisibilityRepository.defaultShowTags, isTrue);
    expect(await repository.get(), isTrue);
  });

  test('保存「隐藏」落同一行、入 outbox，重开库仍读得到', () async {
    final path =
        '${Directory.systemTemp.path}/todo-sidebar-visibility-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final (db, repository) = await open(path: path);

    await repository.save(showTags: false);
    await db.close();

    final (reopened, restored) = await open(path: path);
    addTearDown(() async {
      await reopened.close();
      await File(path).delete();
    });

    expect(await restored.get(), isFalse);

    final rows = await reopened.select(reopened.todoViewPreferences).get();
    expect(rows, hasLength(1));
    expect(rows.single.sourceType, SidebarVisibilityRepository.sourceType);
    expect(rows.single.sourceKey, SidebarVisibilityRepository.sourceKey);

    final changes = await reopened.select(reopened.todoSyncChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entity, SyncEntities.viewPreference);
    final payload =
        jsonDecode(changes.single.payloadJson) as Map<String, dynamic>;
    expect(payload['sourceType'], SidebarVisibilityRepository.sourceType);
    expect(jsonDecode(payload['valueJson'] as String), {'showTags': false});
  });

  test('重复切换只改写同一行，且最后一次点中的值生效（写入的是字面值不是取反）', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    // 每一次 save 之后都立刻回读：只在末尾断一次的话，
    // "id 漂移导致 update 命中 0 行" 这种 bug 会一路静默通过。
    await repository.save(showTags: false);
    expect(await repository.get(), isFalse);
    final rowId = (await db.select(db.todoViewPreferences).get()).single.id;

    await repository.save(showTags: false);
    expect(await repository.get(), isFalse);

    await repository.save(showTags: true);
    expect(await repository.get(), isTrue, reason: '改写必须真的落到那一行');

    await repository.save(showTags: false);
    expect(await repository.get(), isFalse);

    final rows = await db.select(db.todoViewPreferences).get();
    expect(rows, hasLength(1), reason: '同一偏好只能占一行');
    expect(rows.single.id, rowId, reason: '改写不能换新 id，否则同步会分裂成两条');
    expect(await db.select(db.todoSyncChanges).get(), hasLength(4));
  });

  test('同步拉回的服务端包装格式要能读出来，否则第二台设备静默退回默认', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    final wrapped = jsonEncode({
      'id': 9001,
      'valueJson': jsonEncode({'showTags': false}),
    });
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'from-server',
            sourceType: SidebarVisibilityRepository.sourceType,
            sourceKey: SidebarVisibilityRepository.sourceKey,
            valueJson: wrapped,
            updatedAt: DateTime(2026, 9, 25),
            createdAt: DateTime(2026, 9, 25),
          ),
        );

    expect(await repository.get(), isFalse);
  });

  test('读不懂的偏好退回「显示」而不是清空侧栏', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'broken',
            sourceType: SidebarVisibilityRepository.sourceType,
            sourceKey: SidebarVisibilityRepository.sourceKey,
            valueJson: '{不是 JSON',
            updatedAt: DateTime(2026, 9, 25),
            createdAt: DateTime(2026, 9, 25),
          ),
        );

    expect(await repository.get(), isTrue);
  });

  test('watch 在写之后立刻推新值，侧栏不必重进', () async {
    final (db, repository) = await open();
    addTearDown(db.close);

    final seen = <bool>[];
    final subscription = repository.watch().listen(seen.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    expect(seen, [true]);

    await repository.save(showTags: false);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [true, false]);
  });
}
