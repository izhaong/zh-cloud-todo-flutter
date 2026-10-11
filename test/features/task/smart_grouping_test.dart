import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/smart_grouping.dart';

/// specs/100 智能分组（矩阵 #20，FL Issue #321）。
///
/// 判据源：嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/03-用分组和排序管理任务.md》
/// 「智能分组」节的六个小节标题与桶词，逐字断言：
/// 按时间 =「今天/明天/最近 7 天/以后/已过期」（源文档没写无日期任务的去处，
/// 本端补「无日期」桶）；按优先级 =「高优先级/中优先级/低优先级/无优先级」。
/// 输入顺序故意与期望输出相反：实现若照抄入参顺序这些断言必须红。
void main() {
  final now = DateTime(2026, 10, 12, 12);

  TodoTask task({
    required String id,
    String title = '任务',
    DateTime? dueAt,
    bool allDay = false,
    int priority = 0,
    String? listId,
    String? assignee,
    DateTime? createdAt,
  }) {
    return TodoTask(
      id: id,
      listId: listId ?? 'list-1',
      title: '$title-$id',
      completed: false,
      cancelled: false,
      priority: priority,
      isPinned: false,
      sortOrder: 0,
      dueAt: dueAt,
      allDay: allDay,
      fixedTimezone: false,
      timeMode: 0,
      assigneeUserName: assignee,
      updatedAt: createdAt ?? now,
      createdAt: createdAt ?? now,
    );
  }

  List<String> titles(List<SmartTaskGroup> groups) =>
      groups.map((group) => group.title).toList();

  group('按时间分组', () {
    test('五个嘀嗒桶 + 无日期桶，桶词逐字对齐', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'later', dueAt: DateTime(2026, 10, 20)),
          task(id: 'no-date'),
          task(id: 'next7', dueAt: DateTime(2026, 10, 15, 9)),
          task(id: 'tomorrow', dueAt: DateTime(2026, 10, 13, 0, 5)),
          task(id: 'today', dueAt: DateTime(2026, 10, 12, 23)),
          task(id: 'overdue', dueAt: DateTime(2026, 10, 11, 8)),
        ],
        grouping: SmartGrouping.byTime,
        now: now,
      );
      expect(titles(groups), ['已过期', '今天', '明天', '最近 7 天', '以后', '无日期']);
      expect(groups[0].tasks.single.id, 'overdue');
      expect(groups[1].tasks.single.id, 'today');
      expect(groups[2].tasks.single.id, 'tomorrow');
      expect(groups[3].tasks.single.id, 'next7');
      expect(groups[4].tasks.single.id, 'later');
      expect(groups[5].tasks.single.id, 'no-date');
    });

    test('整天任务的当天 23:59 属今天、明天零点属明天（墙钟口径、不吃时区偏移）', () {
      final groups = groupTasksSmartly(
        [
          task(
            id: 'all-day-tomorrow',
            dueAt: DateTime(2026, 10, 13),
            allDay: true,
          ),
          task(
            id: 'all-day-today',
            dueAt: DateTime(2026, 10, 12),
            allDay: true,
          ),
        ],
        grouping: SmartGrouping.byTime,
        now: now,
      );
      expect(titles(groups), ['今天', '明天']);
    });

    test('空桶不输出：只有今天和已过期时只出两桶', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'a', dueAt: DateTime(2026, 10, 12, 8)),
          task(id: 'b', dueAt: DateTime(2026, 10, 10)),
        ],
        grouping: SmartGrouping.byTime,
        now: now,
      );
      expect(titles(groups), ['已过期', '今天']);
    });
  });

  group('按优先级分组', () {
    test('四桶词逐字对齐（3=高 2=中 1=低 0=无）', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'none', priority: 0),
          task(id: 'low', priority: 1),
          task(id: 'medium', priority: 2),
          task(id: 'high', priority: 3),
        ],
        grouping: SmartGrouping.byPriority,
        now: now,
      );
      expect(titles(groups), ['高优先级', '中优先级', '低优先级', '无优先级']);
      expect(groups[0].tasks.single.id, 'high');
      expect(groups[3].tasks.single.id, 'none');
    });
  });

  group('按标签分组', () {
    Set<String> tagsOf(TodoTask task) => switch (task.id) {
      'a' => {'工作', '紧急'},
      'b' => {'工作'},
      _ => {},
    };

    test('挂多标签的任务出现在每个标签组；无标签进「无标签」且排最后', () {
      final groups = groupTasksSmartly(
        [task(id: 'a'), task(id: 'b'), task(id: 'c')],
        grouping: SmartGrouping.byTag,
        now: now,
        tagNamesOf: tagsOf,
      );
      expect(titles(groups), ['工作', '紧急', '无标签']);
      expect(groups[0].tasks.map((t) => t.id), ['a', 'b']);
      expect(groups[1].tasks.single.id, 'a');
      expect(groups[2].tasks.single.id, 'c');
    });

    test('索引没到位（tagNamesOf 为 null）时全部任务进「无标签」，不丢弃', () {
      final groups = groupTasksSmartly(
        [task(id: 'a'), task(id: 'b')],
        grouping: SmartGrouping.byTag,
        now: now,
      );
      expect(titles(groups), ['无标签']);
      expect(groups.single.tasks, hasLength(2));
    });
  });

  group('按清单分组', () {
    test('清单名作组名；名称缺失进「未命名清单」', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'x', listId: 'l2'),
          task(id: 'y', listId: 'l1'),
          task(id: 'z', listId: 'l3'),
        ],
        grouping: SmartGrouping.byList,
        now: now,
        listNameOf: (task) => switch (task.listId) {
          'l1' => '收集箱',
          'l2' => '工作',
          _ => null,
        },
      );
      expect(titles(groups), ['工作', '收集箱', '未命名清单']);
      expect(groups[0].tasks.single.id, 'x');
      expect(groups[1].tasks.single.id, 'y');
      expect(groups[2].tasks.single.id, 'z');
    });
  });

  group('按指派人分组', () {
    test('按 assigneeUserName 分桶；无指派人进「无指派人」且排最后', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'solo'),
          task(id: 'li', assignee: '李四'),
          task(id: 'zhang', assignee: '张三'),
          task(id: 'li2', assignee: '李四'),
        ],
        grouping: SmartGrouping.byAssignee,
        now: now,
      );
      expect(titles(groups), ['李四', '张三', '无指派人']);
      expect(groups[0].tasks.map((t) => t.id), ['li', 'li2']);
      expect(groups[2].tasks.single.id, 'solo');
    });
  });

  group('按创建时间分组', () {
    test('四桶：今天/昨天/最近 7 天/更早', () {
      final groups = groupTasksSmartly(
        [
          task(id: 'old', createdAt: DateTime(2026, 10, 1)),
          task(id: 'last7', createdAt: DateTime(2026, 10, 8)),
          task(id: 'yesterday', createdAt: DateTime(2026, 10, 11, 9)),
          task(id: 'today', createdAt: DateTime(2026, 10, 12, 8)),
        ],
        grouping: SmartGrouping.byCreatedAt,
        now: now,
      );
      expect(titles(groups), ['今天', '昨天', '最近 7 天', '更早']);
      expect(groups[0].tasks.single.id, 'today');
      expect(groups[3].tasks.single.id, 'old');
    });
  });

  test('不分组输出空（页面沿用原状）', () {
    expect(
      groupTasksSmartly(
        [task(id: 'a')],
        grouping: SmartGrouping.none,
        now: now,
      ),
      isEmpty,
    );
  });
}
