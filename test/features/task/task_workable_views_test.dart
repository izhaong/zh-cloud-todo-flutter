import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';

void main() {
  testWidgets('看板拖到进行中列会请求共享任务写操作', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final task = TodoTask(
      id: 'task-1',
      listId: 'list-inbox',
      title: '待移动任务',
      completed: false,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      updatedAt: now,
      createdAt: now,
    );
    (String, int, bool)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: [task],
            onTaskMove: (moved, priority, completed) async {
              request = (moved.id, priority, completed);
            },
          ),
        ),
      ),
    );

    final source = find.text('待移动任务');
    final target = find.text('空').first;
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(request, ('task-1', 1, false));
  });

  testWidgets('看板跨列写入失败时显示可见反馈', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final task = TodoTask(
      id: 'task-failed',
      listId: 'list-inbox',
      title: '失败任务',
      completed: false,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      updatedAt: now,
      createdAt: now,
    );
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: [task],
            onTaskMove: (_, _, _) async {
              attempts++;
              if (attempts == 1) throw StateError('write failed');
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('失败任务')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('空').first));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('移动任务失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('看板只读拒绝显示明确原因且不提供无效重试', (tester) async {
    final task = _viewTask(id: 'task-viewer', title: '只读任务');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: [task],
            onTaskMove: (_, _, _) async {
              throw StateError('当前清单为只读，无法修改任务');
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('只读任务')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('空').first));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('看板显示当前清单失败偏好的恢复入口', (tester) async {
    var recoveries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: const [],
            hasRecoverablePreference: true,
            onRecoverPreference: () async {
              recoveries++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('恢复看板设置'));
    await tester.pumpAndSettle();

    expect(recoveries, 1);
    expect(find.text('已恢复上次看板设置，等待同步'), findsOneWidget);
  });

  testWidgets('时间线顺延一天会请求共享任务时间 mutation', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final startAt = DateTime.utc(2026, 7, 16, 9);
    final endAt = DateTime.utc(2026, 7, 16, 10);
    final task = TodoTask(
      id: 'task-timeline-1',
      listId: 'list-inbox',
      title: '时间线任务',
      completed: false,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: startAt,
      endAt: endAt,
      dueAt: endAt,
      updatedAt: now,
      createdAt: now,
    );
    (String, DateTime, DateTime, DateTime)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (
                  moved, {
                  required startAt,
                  required endAt,
                  required dueAt,
                }) async {
                  request = (moved.id, startAt, endAt, dueAt);
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('顺延一天'));
    await tester.pumpAndSettle();

    expect(request, (
      'task-timeline-1',
      DateTime.utc(2026, 7, 17, 9),
      DateTime.utc(2026, 7, 17, 10),
      DateTime.utc(2026, 7, 17, 10),
    ));
  });

  testWidgets('时间线只读拒绝显示明确原因', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final task = _viewTask(
      id: 'timeline-viewer',
      title: '只读时间线任务',
      startAt: DateTime.utc(2026, 7, 16, 9),
      endAt: DateTime.utc(2026, 7, 16, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (_, {required startAt, required endAt, required dueAt}) async {
                  throw StateError('当前清单为只读，无法修改任务');
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('顺延一天'));
    await tester.pumpAndSettle();

    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
  });
}

TodoTask _viewTask({
  required String id,
  required String title,
  DateTime? startAt,
  DateTime? endAt,
}) {
  final now = DateTime.utc(2026, 7, 15, 9);
  return TodoTask(
    id: id,
    listId: 'list-inbox',
    title: title,
    completed: false,
    cancelled: false,
    allDay: false,
    fixedTimezone: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    startAt: startAt,
    endAt: endAt,
    dueAt: endAt,
    updatedAt: now,
    createdAt: now,
  );
}
