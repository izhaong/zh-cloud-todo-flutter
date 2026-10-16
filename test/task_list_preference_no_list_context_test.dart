import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/list_view_preference_scope.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/smart_grouping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_grouping_preference_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

/// FL #619 后半：**「没有清单上下文」与「收集箱」共用一把键**。
///
/// `TasksByListPage._selectedListId` 在智能清单 / 四象限 / 全部这类页面上是 `null`
/// （`home_shell.dart` 的 `_effectiveListId` 对这些档返回 null），而收集箱那一档显式返回
/// 字面量 `'inbox'`。两个仓储都把 null 落成 `'inbox'` ⇒ 在「今天」里改排序，
/// 会连带把收集箱的排序档位改掉。
///
/// 修法：给「无清单上下文」一档独立键 `no-list`，并把该键加进同步层的
/// `deviceNeutralKeys`（它**不是**清单 UUID，绝不能按清单去归一）。
void main() {
  late AppDatabase db;
  late SyncChangeQueue queue;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncChangeQueue(db);
  });

  tearDown(() => db.close());

  test('排序：智能清单（null）不得改写收集箱档位', () async {
    final repo = TaskSortPreferenceRepository(db, queue);
    await repo.save('inbox', TaskSort.tag);
    await repo.save(null, TaskSort.priorityDesc);

    expect(
      (await repo.get('inbox')).sort,
      TaskSort.tag,
      reason: '在「今天」里改排序不该连带改掉收集箱；两把键混用就会',
    );
    expect(
      (await repo.get(null)).sort,
      TaskSort.priorityDesc,
      reason: '无清单上下文自己有档位，不能从收集箱读',
    );
  });

  test('分组：智能清单（null）不得改写收集箱档位', () async {
    final repo = TaskGroupingPreferenceRepository(db, queue);
    await repo.save('inbox', SmartGrouping.byTag);
    await repo.save(null, SmartGrouping.byPriority);

    expect(await repo.get('inbox'), SmartGrouping.byTag);
    expect(await repo.get(null), SmartGrouping.byPriority);
  });

  test('空串与 null 同档；反向也成立（不会误伤真实清单）', () async {
    final repo = TaskSortPreferenceRepository(db, queue);
    await repo.save(null, TaskSort.tag);
    expect(
      (await repo.get('')).sort,
      TaskSort.tag,
      reason: '空串同样代表「无清单上下文」，与 null 一档',
    );
    await repo.save('some-list-uuid', TaskSort.dueDate);
    expect(
      (await repo.get(null)).sort,
      TaskSort.tag,
      reason: '往真实清单写不该动到无清单上下文那一档',
    );
  });

  test('no-list 是设备无关键：不许被当成清单 UUID 去归一', () async {
    // 若它被归一，出站会被换成 `list-server:<id>`，两台设备就各写各的
    // —— 与 #619 前半同一个病。
    expect(
      ListViewPreferenceScope.localListId('TASK_SORT', 'no-list'),
      isNull,
      reason: 'no-list 必须按原样发送，不能被认成一个还没上服务端的清单',
    );
    expect(
      ListViewPreferenceScope.localListId('TASK_GROUP', 'no-list'),
      isNull,
    );
    // 正对照：真实清单 UUID 仍要被归一（否则前半的修复就失效了）。
    expect(
      ListViewPreferenceScope.localListId('TASK_SORT', 'uuid-of-list-42'),
      'uuid-of-list-42',
    );
  });
}
