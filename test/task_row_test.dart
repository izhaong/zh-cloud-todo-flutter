import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';

/// Phase 2：任务行日期徽章语义分类纯函数测试。
void main() {
  final base = TaskRowData(
    id: 'x',
    title: 't',
    completed: false,
    isPinned: false,
    priority: 0,
    dueAt: null,
    subtaskCount: 0,
    tagNames: const [],
  );

  test('无截止日期 → none', () {
    expect(base.badge(DateTime(2026, 7, 8)), DateBadge.none);
  });

  test('已完成 → none（忽略 dueAt）', () {
    final d = base.copyWith(completed: true, dueAt: DateTime(2026, 7, 7));
    expect(d.badge(DateTime(2026, 7, 8)), DateBadge.none);
  });

  test('逾期 → overdue', () {
    final d = base.copyWith(dueAt: DateTime(2026, 7, 7, 23));
    expect(d.badge(DateTime(2026, 7, 8)), DateBadge.overdue);
  });

  test('今天 → today', () {
    final d = base.copyWith(dueAt: DateTime(2026, 7, 8, 9));
    expect(d.badge(DateTime(2026, 7, 8)), DateBadge.today);
  });

  test('明天 → future', () {
    final d = base.copyWith(dueAt: DateTime(2026, 7, 9, 9));
    expect(d.badge(DateTime(2026, 7, 8)), DateBadge.future);
  });
}

extension on TaskRowData {
  TaskRowData copyWith({bool? completed, DateTime? dueAt}) => TaskRowData(
        id: id,
        title: title,
        completed: completed ?? this.completed,
        isPinned: isPinned,
        priority: priority,
        dueAt: dueAt ?? this.dueAt,
        subtaskCount: subtaskCount,
        tagNames: tagNames,
        listColor: listColor,
      );
}
