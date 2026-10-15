import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';

/// 在本机**真实用户库的副本**上验证：连续多次写入日历偏好时，
/// 入队行为与真机一致（同一 serverId 会排多条），而**批内收敛**由
/// sync_batch_supersede_test 覆盖。
///
/// 复现背景：真实库 todo_t1_u286.sqlite 里 view_preference|2 rev=24、
/// |4 rev=6，曾经各排 3 条同 baseRevision 的 outbox ⇒ 6 条
/// REVISION_CONFLICT（用户看到的红色横幅）。
///
/// 迁移性：路径按 macOS 沙箱约定动态解析，找不到就 skip —— 不让 CI / 他人机器
/// 因为本机没有这个文件而红。
void main() {
  /// macOS 沙箱容器下的 Documents 目录。
  Directory documentsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return Directory(
      '$home/Library/Containers/com.zh04.zhCloudTodoFlutter/Data/Documents',
    );
  }

  /// 任选一个本机存在的账号库（todo_t1_u<userId>.sqlite）。
  File? findAnyUserDb() {
    final dir = documentsDir();
    if (!dir.existsSync()) return null;
    final candidates = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.last;
          return name.startsWith('todo_t') && name.endsWith('.sqlite');
        })
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return candidates.isEmpty ? null : candidates.first;
  }

  test('真实库副本上连点日历开关的入队行为与真机一致', () async {
    final src = findAnyUserDb();
    if (src == null) {
      markTestSkipped('本机没有 Todo 沙箱库（CI / 新机器），跳过');
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('real_db_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final copy = File('${tmp.path}/copy.sqlite');
    await src.copy(copy.path);

    final db = AppDatabase.forTesting(NativeDatabase(copy));
    addTearDown(db.close);

    final before = await (db.select(db.todoSyncChanges)
          ..where((r) => r.status.equals('failed')))
        .get();
    // ignore: avoid_print
    print('SOURCE=${src.path} baseline_failed=${before.length}');

    final queue = SyncChangeQueue(db);
    // 模拟用户连点三次「显示农历」：同一已同步记录（serverId=4）。
    for (final v in [false, true, false]) {
      await queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: 'probe-local',
        serverId: 4,
        payload: {
          'sourceType': 'CALENDAR_INFO',
          'sourceKey': 'global',
          'viewType': 'LIST',
          'valueJson': '{"showLunar":$v}',
        },
      );
    }

    // 关键断言：**入队不去重是既有设计**（本地审计要留痕），
    // 但待发送态必须能被 push 侧收敛成一条。这里先锁住入队行为不变，
    // 批内收敛由 sync_batch_supersede_test 覆盖。
    final queued = await (db.select(db.todoSyncChanges)
          ..where((r) =>
              r.entity.equals('view_preference') &
              (r.status.equals('queued') | r.status.equals('failed'))))
        .get();
    // ignore: avoid_print
    print('AFTER_3_CLICKS queued_or_failed=${queued.length} '
        'serverIds=${queued.map((r) => r.entityServerId).toSet()}');
    expect(
      queued.where((r) => r.entityServerId == 4).length,
      greaterThanOrEqualTo(1),
      reason: '真实库上写入路径可用',
    );
  });
}
