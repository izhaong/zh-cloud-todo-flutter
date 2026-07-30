import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';

void main() {
  test('看板同列重排遵循 Reorderable 索引语义', () {
    expect(reorderKanbanTaskIds(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    expect(reorderKanbanTaskIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
  });

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

  testWidgets('看板截止日期按任务固定时区墙钟显示', (tester) async {
    final task = TodoTask(
      id: 'fixed-zone-board',
      listId: 'list-inbox',
      title: '洛杉矶看板任务',
      completed: false,
      cancelled: false,
      allDay: false,
      timeZone: 'America/Los_Angeles',
      fixedTimezone: true,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      dueAt: DateTime.utc(2026, 7, 12, 2),
      updatedAt: DateTime.utc(2026, 7, 11),
      createdAt: DateTime.utc(2026, 7, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KanbanView(tasks: [task])),
      ),
    );

    expect(find.text('07-11'), findsOneWidget);
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

  testWidgets('看板列折叠与顺序调整只通过偏好回调', (tester) async {
    List<String>? requestedOrder;
    (String, bool)? requestedCollapse;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: const [],
            orderedColumnIds: const ['todo', 'doing', 'urgent', 'archive'],
            collapsedColumnIds: const {},
            onColumnOrderChanged: (order) async => requestedOrder = order,
            onColumnCollapsedChanged: (columnId, collapsed) async {
              requestedCollapse = (columnId, collapsed);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('调整未开始列'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('折叠未开始'));
    await tester.pumpAndSettle();
    expect(requestedCollapse, ('todo', true));

    await tester.tap(find.byTooltip('调整未开始列'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('右移未开始'));
    await tester.pumpAndSettle();
    expect(requestedOrder, ['doing', 'todo', 'urgent', 'archive']);
  });

  testWidgets('时间线顺延一天会请求共享任务时间 mutation', (tester) async {
    final now = DateTime(2026, 7, 15, 9);
    final startAt = DateTime(2026, 7, 16, 9);
    final endAt = DateTime(2026, 7, 16, 10);
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
      DateTime(2026, 7, 17, 9),
      DateTime(2026, 7, 17, 10),
      DateTime(2026, 7, 17, 10),
    ));
  });

  testWidgets('时间线拖动任务本体会按日期移动共享任务时间', (tester) async {
    final now = DateTime(2026, 7, 15, 9);
    final task = _viewTask(
      id: 'timeline-drag',
      title: '拖动时间线任务',
      startAt: DateTime(2026, 7, 16, 9),
      endAt: DateTime(2026, 7, 16, 10),
    );
    (DateTime, DateTime, DateTime)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (_, {required startAt, required endAt, required dueAt}) async {
                  request = (startAt, endAt, dueAt);
                },
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('timeline-task-drag-timeline-drag')),
      const Offset(72, 0),
    );
    await tester.pumpAndSettle();

    expect(request, (
      DateTime(2026, 7, 17, 9),
      DateTime(2026, 7, 17, 10),
      DateTime(2026, 7, 17, 10),
    ));
  });

  testWidgets('时间线拖动任务右边缘会调整时长', (tester) async {
    final now = DateTime(2026, 7, 15, 9);
    final task = _viewTask(
      id: 'timeline-resize',
      title: '调整时间线时长',
      startAt: DateTime(2026, 7, 16, 9),
      endAt: DateTime(2026, 7, 16, 10),
    );
    (DateTime, DateTime, DateTime)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (_, {required startAt, required endAt, required dueAt}) async {
                  request = (startAt, endAt, dueAt);
                },
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('timeline-task-resize-timeline-resize')),
      const Offset(24, 0),
    );
    await tester.pumpAndSettle();

    expect(request, (
      DateTime(2026, 7, 16, 9),
      DateTime(2026, 7, 16, 11),
      DateTime(2026, 7, 16, 11),
    ));
  });

  testWidgets('时间线全天任务使用按天调整时长的无障碍说明', (tester) async {
    final now = DateTime(2026, 7, 15, 9);
    final task = TodoTask(
      id: 'timeline-all-day',
      listId: 'list-inbox',
      title: '全天时间线任务',
      completed: false,
      cancelled: false,
      allDay: true,
      fixedTimezone: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: DateTime(2026, 7, 16),
      endAt: DateTime(2026, 7, 17),
      dueAt: DateTime(2026, 7, 17),
      updatedAt: now,
      createdAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (
                  _, {
                  required startAt,
                  required endAt,
                  required dueAt,
                }) async {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('延长一天'), findsOneWidget);
    expect(find.byTooltip('拖动右边缘按天调整时长'), findsOneWidget);
  });

  testWidgets('时间线固定时区跨夏令时顺延保持墙钟时刻', (tester) async {
    final now = DateTime.utc(2026, 10, 30, 12);
    final task = TodoTask(
      id: 'task-timeline-dst',
      listId: 'list-inbox',
      title: '跨夏令时时间线',
      completed: false,
      cancelled: false,
      allDay: false,
      timeZone: 'America/Los_Angeles',
      fixedTimezone: true,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: DateTime.utc(2026, 10, 31, 16),
      endAt: DateTime.utc(2026, 10, 31, 17),
      dueAt: DateTime.utc(2026, 10, 31, 17),
      updatedAt: now,
      createdAt: now,
    );
    (DateTime, DateTime, DateTime)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            onTaskTimeChange:
                (_, {required startAt, required endAt, required dueAt}) async {
                  request = (startAt, endAt, dueAt);
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('顺延一天'));
    await tester.pumpAndSettle();

    expect(request, (
      DateTime.utc(2026, 11, 1, 17),
      DateTime.utc(2026, 11, 1, 18),
      DateTime.utc(2026, 11, 1, 18),
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

  testWidgets('时间线缩放与折叠通过偏好回调且不会修改任务', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final task = _viewTask(
      id: 'timeline-preference',
      title: '可折叠时间线任务',
      startAt: DateTime.utc(2026, 7, 15, 9),
      endAt: DateTime.utc(2026, 7, 15, 10),
    );
    double? requestedZoom;
    (String, bool)? requestedCollapse;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            zoom: 1,
            collapsedGroupIds: const {},
            onZoomChanged: (value) async => requestedZoom = value,
            onGroupCollapsedChanged: (groupId, collapsed) async {
              requestedCollapse = (groupId, collapsed);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('放大时间线'));
    await tester.pumpAndSettle();
    expect(requestedZoom, 1.25);

    await tester.tap(find.byTooltip('折叠今天'));
    await tester.pumpAndSettle();
    expect(requestedCollapse, ('today', true));
  });

  testWidgets('时间线日周月尺度通过偏好回调切换', (tester) async {
    TimelineScale? requestedScale;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: const [],
            now: DateTime(2026, 7, 15, 9),
            scale: TimelineScale.week,
            onScaleChanged: (scale) async => requestedScale = scale,
          ),
        ),
      ),
    );

    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();

    expect(requestedScale, TimelineScale.day);
  });

  testWidgets('时间线日尺度拖动任务本体会按小时移动', (tester) async {
    final now = DateTime(2026, 7, 15, 9);
    final task = _viewTask(
      id: 'timeline-day-scale',
      title: '日尺度任务',
      startAt: DateTime(2026, 7, 16, 9),
      endAt: DateTime(2026, 7, 16, 10),
    );
    (DateTime, DateTime, DateTime)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: [task],
            now: now,
            scale: TimelineScale.day,
            onTaskTimeChange:
                (_, {required startAt, required endAt, required dueAt}) async {
                  request = (startAt, endAt, dueAt);
                },
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('timeline-task-drag-timeline-day-scale')),
      const Offset(24, 0),
    );
    await tester.pumpAndSettle();

    expect(request, (
      DateTime(2026, 7, 16, 10),
      DateTime(2026, 7, 16, 11),
      DateTime(2026, 7, 16, 11),
    ));
  });

  testWidgets('时间线尺度与缩放工具栏在窄屏不会溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: const [],
            now: DateTime(2026, 7, 15, 9),
            onScaleChanged: (_) async {},
            onZoomChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('时间线日尺度点击空白小时创建一小时时段任务', (tester) async {
    TimelineTaskCreateRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: const [],
            now: DateTime(2026, 7, 15, 9),
            scale: TimelineScale.day,
            onCreateTask: (value) async => request = value,
          ),
        ),
      ),
    );

    final daySlot = find.byKey(const Key('timeline-slot-day-10'));
    await tester.ensureVisible(daySlot);
    await tester.tap(daySlot);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timeline-create-title')),
      '点击创建的任务',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(request?.title, '点击创建的任务');
    expect(request?.startAt, DateTime(2026, 7, 15, 10));
    expect(request?.endAt, DateTime(2026, 7, 15, 11));
    expect(request?.dueAt, DateTime(2026, 7, 15, 11));
    expect(request?.allDay, isFalse);
  });

  testWidgets('时间线月尺度点击空白日期创建全天时段任务', (tester) async {
    TimelineTaskCreateRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineView(
            tasks: const [],
            now: DateTime(2026, 7, 15, 9),
            scale: TimelineScale.month,
            onCreateTask: (value) async => request = value,
          ),
        ),
      ),
    );

    final monthSlot = find.byKey(const Key('timeline-slot-month-15'));
    await tester.ensureVisible(monthSlot);
    await tester.tap(monthSlot);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timeline-create-title')),
      '全天安排',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(request?.startAt, DateTime(2026, 7, 15));
    expect(request?.endAt, DateTime(2026, 7, 16));
    expect(request?.dueAt, DateTime(2026, 7, 16));
    expect(request?.allDay, isTrue);
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
