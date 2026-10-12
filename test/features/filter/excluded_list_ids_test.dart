import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

/// specs/105 / FL #337×#339：「在智能清单中显示」的排除闸门（specs/104 硬闸门同层）。
///
/// 嘀嗒《02-用清单管理任务.md》:73「在智能清单中显示/隐藏」——关掉后该清单
/// 的任务不进智能清单；点进清单本身仍能看到全部任务（嘀嗒同页），所以闸门
/// 只在 `selectedListId == null`（智能清单浏览）时生效。
void main() {
  TodoTask task(String id, String listId) {
    final stamp = DateTime(2026, 10, 1);
    return TodoTask(
      id: id,
      listId: listId,
      title: id,
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      updatedAt: stamp,
      createdAt: stamp,
    );
  }

  final tasks = [task('a', 'work'), task('b', 'home'), task('c', 'work')];
  final now = DateTime(2026, 10, 9, 10);

  test('智能清单浏览：被排除清单的任务整体消失', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(),
      null,
      now,
      excludedListIds: const {'home'},
    );
    expect(items.map((t) => t.id), ['a', 'c']);
  });

  test('选中清单本身：排除集不生效，该清单任务全量可见', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(),
      'home',
      now,
      excludedListIds: const {'home'},
    );
    expect(items.map((t) => t.id), ['b'], reason: '嘀嗒：点进清单仍能看到任务');
  });

  test('排除集为空 = 无闸门，fast-path 直通', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(),
      null,
      now,
      excludedListIds: null,
    );
    expect(items, same(tasks), reason: '空闸门不该把恒等过滤变成拷贝');
  });
}
