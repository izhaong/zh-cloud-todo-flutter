import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filter_mapping.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

/// FL Issue #417：带标签的已存过滤器点不动，根因是 `applyTaskFilter` 里**没有标签分支**。
///
/// 判据源（zh-cloud-docs 镜像《05-过滤器：随心所欲筛选你想看的任务.md》）：
/// `:50`「按照清单名称、标签、日期等属性进行多维度筛选，还可以按照关键词做内容筛选。」
/// `:71`「……在同一个筛选条件（仅标签支持）内，也可以选择使用“且”逻辑、“或”逻辑。」
/// 本轮只做「标签维度真正生效 + 默认“且”」；「或」是 FL Issue #334，不在这里顺手做。
/// 默认取「且」的理由：服务端已合并的契约把缺省定为 AND
/// （`TodoFilterConditionsDO.LOGIC_AND = "and"`，`LOGIC_OR = "or"`，zh-cloud-service develop
/// `dal/dataobject/filter/TodoFilterConditionsDO.java:61-62`），客户端不许自创第三种口径。
void main() {
  TodoTask task(String id) {
    final stamp = DateTime(2026, 9, 1);
    return TodoTask(
      id: id,
      listId: 'inbox',
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

  final tasks = [task('a'), task('b'), task('c')];
  final now = DateTime(2026, 9, 30, 10);

  // 与「多维筛选」的字面含义一致：选了「工作 + 紧急」，只有同时带两个标签的任务才是命中。
  test('标签条件按“且”求值：只含其一的任务不该出现', () {
    final tagIdsByTask = <String, Set<String>>{
      'a': {'work', 'urgent'},
      'b': {'work'},
      'c': <String>{},
    };
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(tagIds: ['work', 'urgent']),
      null,
      now,
      taskTagIds: tagIdsByTask,
    );
    expect(items.map((t) => t.id), ['a']);
  });

  test('任务标签是所选集合的超集时仍命中（多打标签不该被筛掉）', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(tagIds: ['work']),
      null,
      now,
      taskTagIds: {
        'a': {'work', 'urgent'},
        'b': {'personal'},
        'c': <String>{},
      },
    );
    expect(items.map((t) => t.id), ['a']);
  });

  test('没选标签时不该因为映射缺失而改变结果（其余维度照旧）', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(priority: 0),
      null,
      now,
      taskTagIds: null,
    );
    expect(items.map((t) => t.id), ['a', 'b', 'c']);
  });

  // 这条是 #417 的用户可见面：守卫存在时带标签的过滤器一律标「不支持套用」。
  test('带标签的已存过滤器应能还原成本机条件，不再被判成不支持', () {
    final restored = taskFilterFromSaved(
      const TodoFilterConditions(tagIds: ['work', 'urgent']),
      unsupportedKeys: <String>{},
    );
    expect(restored, isNotNull);
    expect(restored!.tagIds, ['work', 'urgent']);
  });
}
