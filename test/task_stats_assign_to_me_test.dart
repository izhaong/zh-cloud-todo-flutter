import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

/// specs/104：「指派给我」徽章的计数口径。
///
/// 嘀嗒《02-用清单管理任务.md》:21「「指派给我」是收集来自不同共享清单中分配给你的任务」。
void main() {
  final now = DateTime(2026, 7, 30, 12);

  test('只数本人的未完成任务：他人、未指派、已完成都不算', () {
    final tasks = [
      _task('mine-1', assigneeUserId: 7),
      _task('mine-2', assigneeUserId: 7),
      _task('other', assigneeUserId: 8),
      _task('unassigned'),
      _task('mine-done', assigneeUserId: 7, completed: true),
    ];

    expect(
      TaskStats.fromTasks(tasks, now: now, assigneeUserId: 7).assignToMe,
      2,
      reason: '嘀嗒口径＝分配给你的任务；已完成的不该还挂在徽章上',
    );
  });

  test('没有会话 ⇒ 0：绝不把"未指派"当成"给我"', () {
    final tasks = [_task('mine', assigneeUserId: 7), _task('free')];

    expect(TaskStats.fromTasks(tasks, now: now).assignToMe, 0);
  });

  test('有会话但库里没有指派记录 ⇒ 0', () {
    expect(
      TaskStats.fromTasks(
        [_task('free')],
        now: now,
        assigneeUserId: 7,
      ).assignToMe,
      0,
    );
  });

  test('取消的任务不计入', () {
    expect(
      TaskStats.fromTasks(
        [_task('cancelled', assigneeUserId: 7, cancelled: true)],
        now: now,
        assigneeUserId: 7,
      ).assignToMe,
      0,
    );
  });
}

TodoTask _task(
  String id, {
  int? assigneeUserId,
  bool completed = false,
  bool cancelled = false,
}) {
  final stamp = DateTime(2026, 7, 1);
  return TodoTask(
    id: id,
    listId: 'inbox',
    title: id,
    completed: completed,
    cancelled: cancelled,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: null,
    allDay: false,
    timeZone: null,
    fixedTimezone: false,
    timeMode: TaskTimeMode.floating.wire,
    assigneeUserId: assigneeUserId,
    updatedAt: stamp,
    createdAt: stamp,
  );
}
