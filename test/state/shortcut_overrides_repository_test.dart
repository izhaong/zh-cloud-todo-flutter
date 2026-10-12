import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

/// specs/109 / FL #579 面③：改键要**落库**才算改过（嘀嗒《08-桌面快捷键.md》:26「可以修改」）。
///
/// 通道复用 `todo_view_preferences` 那一行（与 specs/107 的 `module.*` 同一套读法）
/// ⇒ 不新增表、不 bump schemaVersion，跨端走 `viewPreference` outbox。
void main() {
  const paletteKey = 'shortcut.openCommandPalette';
  const shortcutsKey = 'shortcut.showShortcuts';
  const ctrlAltJ = 'ctrl+alt+0x6a';
  const ctrlAltK = 'ctrl+alt+0x6b';

  Future<(AppDatabase, SidebarVisibilityRepository)> openRepo() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return (db, SidebarVisibilityRepository(db, SyncChangeQueue(db)));
  }

  Future<String> valueJsonOf(AppDatabase db) async {
    final row = await db.select(db.todoViewPreferences).getSingleOrNull();
    return row?.valueJson ?? '{}';
  }

  test('默认没有覆盖；坏形状与非字符串值一律丢掉', () async {
    final (db, repo) = await openRepo();
    expect(await repo.getShortcuts(), isEmpty, reason: '没改过 ⇒ 用注册表默认键位');

    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'seed',
            sourceType: SidebarVisibilityRepository.sourceType,
            sourceKey: SidebarVisibilityRepository.sourceKey,
            valueJson: jsonEncode({
              paletteKey: ctrlAltJ,
              shortcutsKey: 7,
              'shortcut.weird': 'x',
              'showTags': false,
            }),
            updatedAt: DateTime(2026, 10, 12),
            createdAt: DateTime(2026, 10, 12),
          ),
        );

    final overrides = await repo.getShortcuts();
    expect(overrides['openCommandPalette'], ctrlAltJ);
    expect(
      overrides.containsKey('showShortcuts'),
      isFalse,
      reason: '值是数字就不是规范串，读侧当场丢掉（生效键位仍按默认，不会绑到一个怪对象上）',
    );
    expect(
      overrides['weird'],
      'x',
      reason: '未知动作名原样带出来即可：注册表按 kind 取值，取不到就用默认',
    );
    expect(
      await repo.get(),
      isFalse,
      reason: '同一行里的 showTags 不许被 shortcut 键挤掉',
    );
  });

  test('写一档只 patch 自己那一键：另一档与标签偏好都不被顶回默认', () async {
    final (db, repo) = await openRepo();
    await repo.save(showTags: false);
    await repo.saveShortcut(kindName: 'openCommandPalette', combo: ctrlAltJ);

    expect(await repo.getShortcuts(), {'openCommandPalette': ctrlAltJ});
    expect(
      await repo.get(),
      isFalse,
      reason: '整块覆盖会把 showTags 顶回默认——这是加第二个键时就踩过的坑',
    );

    await repo.saveShortcut(kindName: 'showShortcuts', combo: ctrlAltK);
    final overrides = await repo.getShortcuts();
    expect(overrides, {
      'openCommandPalette': ctrlAltJ,
      'showShortcuts': ctrlAltK,
    }, reason: '写第二档不许把第一档改掉');
    expect(await valueJsonOf(db), contains(paletteKey));
  });

  test('重置是删键，不是留个空串', () async {
    final (db, repo) = await openRepo();
    await repo.saveFeature(module: TodoFeatureModule.pomodoro, enabled: false);
    await repo.saveShortcut(kindName: 'openCommandPalette', combo: ctrlAltJ);

    await repo.saveShortcut(kindName: 'openCommandPalette', combo: null);

    expect(await repo.getShortcuts(), isEmpty, reason: '删掉覆盖 ⇒ 回到默认键位');
    final json = await valueJsonOf(db);
    expect(json, isNot(contains(paletteKey)), reason: '留空串会给别的端一个含义不明的脏键');
    expect(json, contains('module.pomodoro'), reason: '删自己那键不许顺手把功能模块档也删了');
    expect(
      await repo.getFeature(TodoFeatureModule.pomodoro),
      isFalse,
      reason: '读侧同样要还是关掉的那档',
    );
  });

  test('改键出一条 viewPreference outbox，payload 带 shortcut.<动作名> 与规范串', () async {
    final (db, repo) = await openRepo();

    await repo.saveShortcut(kindName: 'openCommandPalette', combo: ctrlAltJ);

    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.viewPreference))).get();
    expect(rows, hasLength(1), reason: '一次改键只该出一条 outbox');
    final flattened = jsonEncode(jsonDecode(rows.single.payloadJson));
    expect(flattened, contains(paletteKey));
    expect(flattened, contains(ctrlAltJ));
  });

  test('watchShortcuts 是"跟着落库走"的流，不是只读一次', () async {
    final (_, repo) = await openRepo();
    final seen = <Map<String, String>>[];
    final sub = repo.watchShortcuts().listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen, [isEmpty], reason: '订阅时的当前值：没改过 ⇒ 空覆盖');

    await repo.saveShortcut(kindName: 'showShortcuts', combo: ctrlAltK);
    await pumpEventQueue();

    expect(seen.last, {
      'showShortcuts': ctrlAltK,
    }, reason: '写完必须再推一次，否则界面与工作区都停在旧键位上');
    expect(seen.length, greaterThanOrEqualTo(2));
  });
}
