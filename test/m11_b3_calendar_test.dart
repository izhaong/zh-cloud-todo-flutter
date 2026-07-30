import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';

/// M11-B3 c5 日历视图：纯函数 + 5 模式渲染。
void main() {
  group('resolveTaskDate', () {
    final base = DateTime(2026, 6, 15, 18, 30);
    TodoTask build({DateTime? startAt, DateTime? endAt, DateTime? dueAt}) {
      return TodoTask(
        id: '1',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        title: 't',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: startAt,
        endAt: endAt,
        dueAt: dueAt,
        updatedAt: base,
        createdAt: base,
      );
    }

    test('优先 dueAt', () {
      final t = build(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 2, 1),
        dueAt: DateTime(2026, 6, 15, 18, 30),
      );
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 6, 15));
    });

    test('次选 endAt（无 dueAt）', () {
      final t = build(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 5, 1, 12),
      );
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 5, 1));
    });

    test('再次 startAt', () {
      final t = build(startAt: DateTime(2026, 4, 1, 9));
      final d = resolveTaskDate(t);
      expect(d, DateTime(2026, 4, 1));
    });

    test('全空返回 null', () {
      expect(resolveTaskDate(build()), isNull);
    });

    test('固定时区任务按配置时区的墙钟日期落格', () {
      final task = TodoTask(
        id: 'fixed-zone-date',
        listId: '1',
        title: '洛杉矶晚间任务',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        dueAt: DateTime.utc(2026, 7, 12, 2),
        allDay: false,
        timeZone: 'America/Los_Angeles',
        fixedTimezone: true,
        updatedAt: base,
        createdAt: base,
      );

      expect(resolveTaskDate(task), DateTime(2026, 7, 11));
    });
  });

  group('buildMonthGrid', () {
    test('7 列 × 6 行；从周一开始', () {
      final grid = buildMonthGrid(DateTime(2026, 6, 15));
      expect(grid.length, 6);
      for (final row in grid) {
        expect(row.length, 7);
      }
      // 第一格应为 6 月 1 日所在周的周一
      // 2026-06-01 是周一
      expect(grid.first.first, DateTime(2026, 6, 1));
      // 最后一格 = 第一格 + 41 天
      expect(grid.last.last, grid.first.first.add(const Duration(days: 41)));
    });

    test('跨月：6 月 1 日不是周一时，网格包含 5 月末尾 + 7 月开头', () {
      // 2026-11-01 是周日，所以 11 月的网格会跨到 10 月末尾和 12 月开头
      final grid = buildMonthGrid(DateTime(2026, 11, 15));
      final all = grid.expand((r) => r).toList();
      expect(all.any((d) => d.month == 10), isTrue);
      expect(all.any((d) => d.month == 12), isTrue);
    });

    test('6 月：1 日周一、30 日周二 → 6×6 网格跨到 7 月', () {
      // 2026-06-01 = 周一, 2026-06-30 = 周二 → 6 行 × 7 列 = 42 天会跨到 7 月
      final grid = buildMonthGrid(DateTime(2026, 6, 15));
      final all = grid.expand((r) => r).toList();
      expect(all.length, 42);
      expect(all.any((d) => d.month == 7), isTrue);
    });
  });

  group('calendarDueAtForDay', () {
    test('拖到目标日期时保留原截止时间的时分秒', () {
      final now = DateTime(2026, 6, 15, 12);
      final task = TodoTask(
        id: 'move-time',
        listId: '1',
        title: '保留时间',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        dueAt: DateTime(2026, 6, 20, 18, 30, 15),
        allDay: false,
        fixedTimezone: false,
        updatedAt: now,
        createdAt: now,
      );

      expect(
        calendarDueAtForDay(task, DateTime(2026, 6, 23)),
        DateTime(2026, 6, 23, 18, 30, 15),
      );
    });

    test('全天任务拖到目标日期后落在当天零点', () {
      final now = DateTime(2026, 6, 15, 12);
      final task = TodoTask(
        id: 'move-all-day',
        listId: '1',
        title: '全天任务',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        dueAt: DateTime.utc(2026, 6, 20),
        allDay: true,
        timeZone: 'America/Los_Angeles',
        fixedTimezone: true,
        updatedAt: now,
        createdAt: now,
      );

      expect(resolveTaskDate(task), DateTime(2026, 6, 20));
      expect(
        calendarDueAtForDay(task, DateTime(2026, 6, 23)),
        DateTime(2026, 6, 23),
      );
    });

    test('固定时区任务改期保留配置时区墙钟并转换回 UTC', () {
      final now = DateTime(2026, 6, 15, 12);
      final task = TodoTask(
        id: 'move-fixed-zone',
        listId: '1',
        title: '固定时区任务',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        dueAt: DateTime.utc(2026, 7, 11, 16, 30),
        allDay: false,
        timeZone: 'America/Los_Angeles',
        fixedTimezone: true,
        updatedAt: now,
        createdAt: now,
      );

      expect(
        calendarDueAtForDay(task, DateTime(2026, 11, 10)),
        DateTime.utc(2026, 11, 10, 17, 30),
      );
    });
  });

  testWidgets('CalendarView 月模式渲染工具栏 + 网格', (tester) async {
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: '1',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        title: '本月任务',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 20, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(tasks: tasks, now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 工具栏模式切换
    expect(find.text('月'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('列表'), findsOneWidget);
    // 6 月 20 日应被标记"1 项"
    expect(find.text('1 项'), findsOneWidget);
  });

  testWidgets('月视图点击日期进入当日日程视图', (tester) async {
    final now = DateTime(2026, 6, 15, 12);
    final task = TodoTask(
      id: 'agenda-task',
      listId: '1',
      title: '日程会议',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: DateTime(2026, 6, 20, 9),
      endAt: DateTime(2026, 6, 20, 10),
      dueAt: DateTime(2026, 6, 20, 10),
      allDay: false,
      fixedTimezone: false,
      updatedAt: now,
      createdAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(tasks: [task], now: now),
          ),
        ),
      ),
    );

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(_selectedCalendarMode(tester), CalendarMode.agenda);
    expect(find.text('日程会议'), findsOneWidget);
    expect(find.text('09:00–10:00'), findsOneWidget);
  });

  testWidgets('日程视图按任务固定时区显示墙钟时段', (tester) async {
    final now = DateTime(2026, 7, 11, 12);
    final task = TodoTask(
      id: 'fixed-zone-agenda',
      listId: '1',
      title: '洛杉矶日程',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: DateTime.utc(2026, 7, 11, 16, 30),
      endAt: DateTime.utc(2026, 7, 11, 17, 30),
      dueAt: DateTime.utc(2026, 7, 11, 17, 30),
      allDay: false,
      timeZone: 'America/Los_Angeles',
      fixedTimezone: true,
      updatedAt: now,
      createdAt: now,
    );
    final utcTask = TodoTask(
      id: 'utc-agenda',
      listId: '1',
      title: 'UTC 日程',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 1,
      dueAt: DateTime.utc(2026, 7, 11, 10),
      allDay: false,
      timeZone: 'UTC',
      fixedTimezone: true,
      updatedAt: now,
      createdAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(tasks: [utcTask, task], now: now),
          ),
        ),
      ),
    );

    await tester.tap(find.text('日程'));
    await tester.pumpAndSettle();

    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('09:30–10:30'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('洛杉矶日程')).dy,
      lessThan(tester.getTopLeft(find.text('UTC 日程')).dy),
    );
  });

  testWidgets('月视图直接拖动任务卡到日期格会请求改期', (tester) async {
    final now = DateTime(2026, 6, 15, 12);
    final task = TodoTask(
      id: 'drag-task',
      listId: '1',
      title: '拖拽改期',
      completed: false,
      cancelled: false,
      priority: 2,
      isPinned: false,
      sortOrder: 0,
      dueAt: DateTime(2026, 6, 20, 18, 30),
      allDay: false,
      fixedTimezone: false,
      updatedAt: now,
      createdAt: now,
    );
    (String, DateTime)? request;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(
              tasks: [task],
              now: now,
              onTaskDateChanged: (moved, dueAt) async {
                request = (moved.id, dueAt);
              },
            ),
          ),
        ),
      ),
    );

    final source = find.byKey(const ValueKey('calendar-task-drag-drag-task'));
    final target = find.byKey(const ValueKey('calendar-day-2026-6-23'));
    await tester.drag(
      source,
      tester.getCenter(target) - tester.getCenter(source),
    );
    await tester.pumpAndSettle();

    expect(request, ('drag-task', DateTime(2026, 6, 23, 18, 30)));
  });

  testWidgets('月视图拖拽改期失败时显示只读原因', (tester) async {
    final now = DateTime(2026, 6, 15, 12);
    final task = TodoTask(
      id: 'readonly-task',
      listId: 'readonly',
      title: '只读任务',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      dueAt: DateTime(2026, 6, 20, 9),
      allDay: false,
      fixedTimezone: false,
      updatedAt: now,
      createdAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(
              tasks: [task],
              now: now,
              onTaskDateChanged: (_, _) async {
                throw StateError('当前清单为只读，无法修改任务');
              },
            ),
          ),
        ),
      ),
    );

    final source = find.byKey(
      const ValueKey('calendar-task-drag-readonly-task'),
    );
    final target = find.byKey(const ValueKey('calendar-day-2026-6-23'));
    await tester.drag(
      source,
      tester.getCenter(target) - tester.getCenter(source),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
  });

  testWidgets('CalendarView 列表模式按日期排序', (tester) async {
    final now = DateTime(2026, 6, 15, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: '1',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        title: '晚一点',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 20, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: '2',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        title: '早一点',
        completed: false,
        cancelled: false,
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: DateTime(2026, 6, 10, 9, 0),
        updatedAt: now,
        createdAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(tasks: tasks, now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 切到列表模式
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('早一点'), findsOneWidget);
    expect(find.text('晚一点'), findsOneWidget);
    // 早一点应排在晚一点前面
    final earlier = tester.getTopLeft(find.text('早一点'));
    final later = tester.getTopLeft(find.text('晚一点'));
    expect(earlier.dy < later.dy, isTrue);
  });

  testWidgets('外部订阅事件显示来源并保持只读', (tester) async {
    final now = DateTime(2026, 7, 30, 8);
    String? selectedTaskId;
    final externalEvent = TodoTask(
      id: 'external:9:meeting-1',
      listId: 'external:团队日历',
      title: '团队周会',
      description: '只读事件',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: DateTime(2026, 7, 30, 9),
      endAt: DateTime(2026, 7, 30, 10),
      dueAt: DateTime(2026, 7, 30, 9),
      allDay: false,
      fixedTimezone: false,
      updatedAt: now,
      createdAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CalendarView(
              tasks: [externalEvent],
              now: now,
              onTaskSelected: (id) => selectedTaskId = id,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('团队周会'));
    await tester.pumpAndSettle();

    expect(find.text('来源：团队日历'), findsOneWidget);
    expect(find.text('只读订阅事件'), findsOneWidget);
    expect(find.text('只读事件'), findsOneWidget);
    expect(selectedTaskId, isNull);
  });

  testWidgets(
    'CalendarView 360x800 at 1.3x has no toolbar overflow and all modes are reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 6, 15, 12);
      final tasks = <TodoTask>[
        TodoTask(
          id: 'compact-calendar-task',
          listId: '1',
          allDay: false,
          fixedTimezone: false,
          title: '窄屏日历任务',
          completed: false,
          cancelled: false,
          priority: 0,
          isPinned: false,
          sortOrder: 0,
          dueAt: DateTime(2026, 6, 20, 9),
          updatedAt: now,
          createdAt: now,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: CalendarView(tasks: tasks, now: now),
            ),
          ),
        ),
      );
      await tester.pump();

      final layoutErrors = <Object>[..._takeFlutterExceptions(tester)];
      final expectedModes = <String, CalendarMode>{
        '月': CalendarMode.month,
        '周': CalendarMode.week,
        '年': CalendarMode.year,
        '列表': CalendarMode.list,
        '日程': CalendarMode.agenda,
      };
      expect(_selectedCalendarMode(tester), CalendarMode.month);

      for (final entry in expectedModes.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        expect(
          _selectedCalendarMode(tester),
          entry.value,
          reason: '360px 窄屏下仍应可达「${entry.key}」模式',
        );
        layoutErrors.addAll(_takeFlutterExceptions(tester));
      }

      expect(
        layoutErrors,
        isEmpty,
        reason: '360x800、1.3x 文字缩放下默认工具栏不应产生 RenderFlex overflow',
      );
    },
  );
}

CalendarMode _selectedCalendarMode(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<CalendarMode>>(
        find.byType(SegmentedButton<CalendarMode>),
      )
      .selected
      .single;
}

List<Object> _takeFlutterExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception!);
  }
  return exceptions;
}
