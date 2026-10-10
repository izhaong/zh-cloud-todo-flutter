import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

/// 嘀嗒《05-过滤器》`:71`「……并且，在同一个筛选条件（仅标签支持）内，也可以选择使用“且”逻辑、“或”逻辑。」
///
/// FL Issue #334 面 ①：标签这一条条件内部要能在「且 / 或」之间切。缺省仍是「且」——
/// 口径与服务端一致（`TodoFilterConditionsDO.LOGIC_AND`，且 `TodoFilterServiceImpl:359-361`
/// 把「键不存在」当 AND），所以客户端**不写这个键**与**写 and** 必须等价。
void main() {
  TodoTask task(String id) {
    final stamp = DateTime(2026, 10, 1);
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
  final now = DateTime(2026, 10, 9, 10);
  final tagIdsByTask = <String, Set<String>>{
    'a': {'work', 'urgent'},
    'b': {'work'},
    'c': <String>{},
  };

  List<String> hit(TaskFilter filter) =>
      applyTaskFilter(
        tasks,
        filter,
        null,
        now,
        taskTagIds: tagIdsByTask,
      ).map((t) => t.id).toList();

  test('「或」档：只含其一的任务也算命中', () {
    expect(
      hit(const TaskFilter(tagIds: ['work', 'urgent'], tagLogic: 'or')),
      ['a', 'b'],
    );
  });

  test('缺省与显式 and 都是「且」，两者结果逐字相同', () {
    final implicit = hit(const TaskFilter(tagIds: ['work', 'urgent']));
    final explicit = hit(
      const TaskFilter(tagIds: ['work', 'urgent'], tagLogic: 'and'),
    );
    expect(implicit, ['a']);
    expect(explicit, implicit);
  });

  test('大写「OR」按或服务端 equalsIgnoreCase 同口径，不当成未知值退回且', () {
    // 同样要选两个标签：一个标签时 AND/OR 同结果，测不出大小写有没有被认下来。
    expect(
      hit(const TaskFilter(tagIds: ['work', 'urgent'], tagLogic: 'OR')),
      ['a', 'b'],
    );
  });

  test('零标签时「或」不参与求值，不能把全量拦成零命中', () {
    expect(hit(const TaskFilter(tagLogic: 'or')), ['a', 'b', 'c']);
  });

  test('未知逻辑词按缺省「且」求值（不在求值层猜新词表）', () {
    // 必须选两个标签：只选一个时「且」与「或」结果相同，这条断言就没有区分度了。
    expect(hit(const TaskFilter(tagIds: ['work', 'urgent'], tagLogic: 'xor')), ['a']);
  });

  test('索引未就位时求值层不动作：「等不等」是调用方的责任，不在这里放行或拦死', () {
    // 现有口径（!523 同款）：`taskTagIds == null` 表示标签索引还没到位，
    // 求值层跳过标签分支，由列表/预览两个调用方决定转圈还是给空图。
    // 这条钉住的是：加了「或」档之后不许改成「null 当成零命中」，那会把整张列表清空。
    final orItems = applyTaskFilter(
      tasks,
      const TaskFilter(tagIds: ['work', 'urgent'], tagLogic: 'or'),
      null,
      now,
    );
    expect(orItems.map((t) => t.id), ['a', 'b', 'c']);
  });
}
