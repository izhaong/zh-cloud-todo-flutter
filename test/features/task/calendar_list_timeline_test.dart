import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_section_repository.dart';

/// specs/052 日历「列表视图 - 显示时间轴」（矩阵 #29 的一格）。
///
/// 术语照抄嘀嗒《02-功能指南/02-日历/04-列表视图：按天查看任务.md》：
/// `:16` 小节标题「显示时间轴」、`:18`「以时间为线，串起一天的日程」、
/// `:23`「打开方式：「日历列表视图」 - 「显示时间轴」图标」、
/// 《08-常见问题.md》`:32`「将全天任务栏里的任务拖拽至时间轴上的对应时间点即可」——
/// 这句的拖拽两端是**两个区域** ⇒ 「全天任务栏」在轴**之外**（本面把它画成轴上方的独立栏，全天行不画轴线）。
void main() {
  final anchor = DateTime(2026, 10, 1, 12);

  TodoTask task({
    required String id,
    required String title,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    bool allDay = false,
  }) {
    return TodoTask(
      id: id,
      listId: 'list-1',
      title: title,
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: startAt,
      endAt: endAt,
      dueAt: dueAt,
      allDay: allDay,
      fixedTimezone: false,
      updatedAt: anchor,
      createdAt: anchor,
    );
  }

  /// 输入顺序**故意与期望输出相反**（记忆里「顺序类断言要让数据反着种」）：
  /// 若实现只是照抄入参顺序，这几条必须红。
  List<TodoTask> fixtureTasks() => [
    task(
      id: 't-late',
      title: '晚课',
      startAt: DateTime(2026, 10, 1, 15, 30),
      dueAt: DateTime(2026, 10, 1, 15, 30),
    ),
    task(id: 't-other', title: '次日事项', dueAt: DateTime(2026, 10, 2, 9)),
    task(
      id: 't-allday',
      title: '全天事项',
      dueAt: DateTime(2026, 10, 1),
      allDay: true,
    ),
    task(id: 't-none', title: '无日期事项'),
    task(id: 't-due-only', title: '仅截止', dueAt: DateTime(2026, 10, 1, 6)),
    task(
      id: 't-early',
      title: '早课',
      startAt: DateTime(2026, 10, 1, 7),
      dueAt: DateTime(2026, 10, 1, 7),
    ),
  ];

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<TodoTask> tasks,
    DateTime? now,
    Size viewport = const Size(1000, 800),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: CalendarView(tasks: tasks, now: now ?? anchor),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// 字号档位的**自检**：断的是弹层/页面自己 context 上的继承值，
  /// 档位一旦不再传递就当场红（比外部反向探针更省事，specs/033 的教训）。
  void expectTextScale(WidgetTester tester, double expected) {
    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(CalendarView)),
    );
    expect(
      scaler.scale(10),
      closeTo(expected * 10, 0.001),
      reason: '用例前提：$expected 倍字号必须真的传到 CalendarView 自己的 context',
    );
  }

  Future<void> toListMode(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: find.byType(CalendarView), matching: find.text('列表')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> toggleTimeline(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('calendar-list-timeline')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('tasksOnDayByTime（时间轴取数）', () {
    test('只收选中日的任务：跨日与无日期的一律不进轴', () {
      final dayTasks = tasksOnDayByTime(fixtureTasks(), DateTime(2026, 10, 1));
      expect(
        dayTasks.map((t) => t.id),
        orderedEquals(['t-allday', 't-due-only', 't-early', 't-late']),
        reason: '10/2 与无日期的两条都不该出现',
      );
    });

    test('全天在前；时点按 startAt>dueAt>endAt 的墙钟时刻升序', () {
      final dayTasks = tasksOnDayByTime(fixtureTasks(), DateTime(2026, 10, 1));
      final timed = dayTasks.where((t) => !t.allDay).map((t) => t.id).toList();
      expect(timed, ['t-due-only', 't-early', 't-late']);
      expect(dayTasks.first.allDay, isTrue);
    });

    test('换一天就换一批任务（选中日是参数，不是内部写死）', () {
      final nextDay = tasksOnDayByTime(fixtureTasks(), DateTime(2026, 10, 2));
      expect(nextDay.map((t) => t.id), ['t-other']);
    });
  });

  group('「显示时间轴」图标（FR-1 入口 / FR-4 默认值）', () {
    testWidgets('列表档才有这个图标，月档与日程档都没有', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      expect(
        find.byKey(const Key('calendar-list-timeline')),
        findsNothing,
        reason: '默认停在月档：入口不该出现在别的档',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarView),
          matching: find.text('日程'),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('calendar-list-timeline')), findsNothing);

      await toListMode(tester);
      expect(find.byKey(const Key('calendar-list-timeline')), findsOneWidget);
    });

    testWidgets('默认关：列表档仍是「全部任务」跨日清单，没被按天过滤', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);

      expect(find.text('全部任务'), findsOneWidget);
      expect(find.text('次日事项'), findsOneWidget, reason: '关闭态=跨日清单');
      expect(find.text('无日期事项'), findsOneWidget);
      expect(find.byKey(const Key('calendar-timeline-allday')), findsNothing);
    });

    testWidgets('图标可被读屏念出，选中态随开关翻转', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);

      final handle = tester.ensureSemantics();
      try {
        final button = find.byKey(const Key('calendar-list-timeline'));
        final node = tester.getSemantics(button);
        expect(node.label, '显示时间轴');
        expect(node.flagsCollection.isButton, isTrue);
        // 本机 SDK（3.44.8）的 SemanticsFlags.isSelected 是 **Tristate**，不是 bool：
        // 写 isFalse 会拿 Tristate.isFalse 去比 false 而恒红。
        expect(
          node.flagsCollection.isSelected,
          Tristate.isFalse,
          reason: '默认关',
        );

        await toggleTimeline(tester);
        expect(
          tester.getSemantics(button).flagsCollection.isSelected,
          Tristate.isTrue,
          reason: '开启后必须能念出"已选中"，否则读屏用户不知道当前是时间轴',
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('开启后的时间轴（FR-2）', () {
    testWidgets('串起选中日一天：非选中日的任务从轴上消失', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await toggleTimeline(tester);

      expect(find.text('早课'), findsOneWidget);
      expect(find.text('晚课'), findsOneWidget);
      expect(find.text('次日事项'), findsNothing);
      expect(find.text('无日期事项'), findsNothing);
      expect(find.text('全部任务'), findsNothing, reason: 'FR-8：不再写全部任务');
      expect(find.text('2026 年 10 月 1 日'), findsOneWidget);
    });

    testWidgets('「全天」区在最上方，时点行在其下按时刻排', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await toggleTimeline(tester);

      final band = find.byKey(const Key('calendar-timeline-allday'));
      expect(band, findsOneWidget);
      expect(find.text('全天'), findsOneWidget, reason: '带标题只有一处，行内不再重复');
      expect(
        find.descendant(
          of: band,
          matching: find.byKey(
            const ValueKey('calendar-timeline-row-t-allday'),
          ),
        ),
        findsOneWidget,
      );
      final timed = find.byKey(const Key('calendar-timeline-timed'));
      expect(
        find.descendant(of: timed, matching: band),
        findsNothing,
        reason: '全天行不得同时出现在时点段里（正反各一条）',
      );
      expect(
        tester.getRect(band).top < tester.getRect(timed).top,
        isTrue,
        reason: '嘀嗒的轴是"全天任务栏"在上、日程在下',
      );
      expect(
        tester
                .getRect(
                  find.byKey(
                    const ValueKey('calendar-timeline-row-t-due-only'),
                  ),
                )
                .top <
            tester
                .getRect(
                  find.byKey(const ValueKey('calendar-timeline-row-t-late')),
                )
                .top,
        isTrue,
        reason: '06:00 在 15:30 之前',
      );
    });

    testWidgets('每行念得出"时刻 + 标题"，时点行标出 HH:mm', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await toggleTimeline(tester);

      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('15:30'), findsOneWidget);

      final handle = tester.ensureSemantics();
      try {
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('calendar-timeline-row-t-early')),
              )
              .label,
          '07:00 早课',
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('calendar-timeline-row-t-allday')),
              )
              .label,
          '全天 全天事项',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('切到真的没有任务的日子，「该日无任务」第一次为真', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await toggleTimeline(tester);

      expect(find.text('该日无任务'), findsNothing, reason: '反对照：10/1 有任务');
      await tester.tap(find.byTooltip('下一个'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2026 年 10 月 2 日'), findsOneWidget);
      expect(find.text('该日无任务'), findsNothing, reason: '10/2 有次日事项');
      await tester.tap(find.byTooltip('下一个'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('该日无任务'), findsOneWidget);
      expect(find.text('早课'), findsNothing);
    });
  });

  group('关闭后与开关往返（FR-3 / 四件套 3）', () {
    testWidgets('开→关 回到跨日清单；开→关→开 行集合与第一次一致', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);

      // 按固定的标题清单取"当前看得见哪些"，不依赖两种档各自用什么行 widget
      // （时间轴的行不是 ListTile，照抄 byType(ListTile) 会静默量到空集）。
      List<String> visibleTitles() => [
        for (final title in const ['全天事项', '仅截止', '早课', '晚课', '次日事项', '无日期事项'])
          if (find.text(title).evaluate().isNotEmpty) title,
      ];

      await toggleTimeline(tester);
      final firstOpen = visibleTitles();
      expect(firstOpen, containsAll(['早课', '晚课', '全天事项']));

      await toggleTimeline(tester);
      expect(visibleTitles(), isNot(equals(firstOpen)));
      expect(find.text('次日事项'), findsOneWidget);
      expect(find.text('无日期事项'), findsOneWidget);
      expect(find.text('全部任务'), findsOneWidget);

      await toggleTimeline(tester);
      expect(visibleTitles(), orderedEquals(firstOpen), reason: '不出现空列表假象');
    });

    testWidgets('现有列表档用例不受影响：关闭态标题仍是「全部任务」且按日期排', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      expect(find.text('2026-10-01'), findsWidgets);
      expect(find.text('2026-10-02'), findsOneWidget);
      expect(
        tester.getRect(find.text('早课')).top <
            tester.getRect(find.text('次日事项')).top,
        isTrue,
      );
    });
  });

  group('选中日移动（FR-7）', () {
    testWidgets('开启后「下一个/上一个」按天移动选中日', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await toggleTimeline(tester);

      await tester.tap(find.byTooltip('下一个'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2026 年 10 月 2 日'), findsOneWidget);
      expect(find.text('次日事项'), findsOneWidget);
      expect(find.text('早课'), findsNothing);

      await tester.tap(find.byTooltip('上一个'));
      await tester.tap(find.byTooltip('上一个'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2026 年 9 月 30 日'), findsOneWidget);
      expect(find.text('早课'), findsNothing, reason: '9/30 没有任务');
    });

    testWidgets('关闭态拨「下一个」不动锚点：随后开启仍从原选中日开始', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await toListMode(tester);
      await tester.tap(find.byTooltip('下一个'));
      await tester.pump();
      await toggleTimeline(tester);
      expect(
        find.text('2026 年 10 月 1 日'),
        findsOneWidget,
        reason: '关闭时列表档不切锚点（现状），开启后看到的还是 10/1',
      );
    });
  });

  group('议程档共用了同一个取数（防副本）', () {
    testWidgets('议程档顺序 = tasksOnDayByTime 的顺序', (tester) async {
      await pumpCalendar(tester, tasks: fixtureTasks());
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarView),
          matching: find.text('日程'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data!)
          .toList();
      expect(
        titles,
        tasksOnDayByTime(
          fixtureTasks(),
          DateTime(2026, 10, 1),
        ).map((t) => t.title).toList(),
        reason: '议程档若自己抄一份排序，这条会红（同一口径不得有两个事实源）',
      );
    });
  });

  group('四件套 1：320px + 1.3 倍字号', () {
    /// 最坏内容：选中日 9 条时点任务（含 2 条 20 字以上长标题，压横向换行与行高）
    /// + 1 条全天，另加次日 1 条做「按天过滤」的反例。
    List<TodoTask> heavyDayTasks() => [
      for (var i = 0; i < 9; i++)
        task(
          id: 'h-$i',
          title: switch (i) {
            0 => '长标题甲：这一条故意写到二十个汉字以上用来压横向',
            1 => '长标题乙：同样超过二十个汉字，用来压最坏行高与换行',
            _ => '时点事项 $i',
          },
          startAt: DateTime(2026, 10, 1, 9, i * 5),
          dueAt: DateTime(2026, 10, 1, 9, i * 5),
        ),
      task(
        id: 'h-allday',
        title: '全天事项：这一条也故意写得很长，用来压全天栏的横向',
        dueAt: DateTime(2026, 10, 1),
        allDay: true,
      ),
      task(id: 'h-other', title: '次日事项', dueAt: DateTime(2026, 10, 2, 9)),
    ];

    testWidgets('320x568、1.3 倍字号下时间轴与工具条零溢出', (tester) async {
      final tasks = heavyDayTasks();
      await pumpCalendar(
        tester,
        tasks: tasks,
        viewport: const Size(320, 568),
        textScale: 1.3,
      );
      expectTextScale(tester, 1.3);
      await toListMode(tester);
      await toggleTimeline(tester);

      // 复核 F3：原来只断「全天」栏这一个键（它是 ListView 的第一个子节点，恒在），
      // 等于没有断过「最坏内容真在树里」。现在逐行断：选中日**每一条**任务的行键都要在场，
      // 少一条就说明懒建窗口没覆盖到它，那次几何测量就不带信息。
      final dayTasks = tasksOnDayByTime(tasks, DateTime(2026, 10, 1));
      expect(dayTasks, hasLength(10), reason: '本用例前提：选中日 10 条（9 时点 + 1 全天）');
      final missing = [
        for (final t in dayTasks)
          if (find
              .byKey(ValueKey('calendar-timeline-row-${t.id}'))
              .evaluate()
              .isEmpty)
            t.id,
      ];
      expect(missing, isEmpty, reason: '这些行没被建出来，几何测量覆盖不到它们：$missing');
      final overflows = _flexOverflows(tester, find.byType(CalendarView));
      expect(overflows, isEmpty, reason: '横向/纵向越界明细：\n$overflows');
      expect(tester.takeException(), isNull);
    });

    // 尺子自己的对照：这条判据此前在九条探针里从没开过火（复核 F3）。
    // 不报「量不到」的尺子和不报溢出的尺子长一样，所以阳性对照必须常驻本套件。
    testWidgets('反向自检：量溢出的尺子对已知溢出必须开火、对不溢出必须沉默', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget wrap({required List<Widget> children}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const Key('ruler-scope'),
              width: 320,
              height: 200,
              child: Row(children: children),
            ),
          ),
        ),
      );

      // 阳性：两个 200px 固定宽子节点放进 320px 的 Row ⇒ 越界 80px。
      await tester.pumpWidget(
        wrap(
          children: const [
            SizedBox(width: 200, height: 20),
            SizedBox(width: 200, height: 20),
          ],
        ),
      );
      await tester.pump();
      final hits = _flexOverflows(tester, find.byKey(const Key('ruler-scope')));
      expect(hits, hasLength(1), reason: '已知溢出 80px 却没报 ⇒ 这把尺子是死的：$hits');
      expect(hits.single, contains('横向溢出'));
      expect(
        hits.single,
        contains('80.0'),
        reason: '报出来的像素数要跟手算一致（400−320）：$hits',
      );
      // RenderFlex 溢出本身会抛绘制异常，这里只负责取走，不让它漏到下一条用例。
      expect(tester.takeException(), isNotNull);

      // 阴性：同样两个子节点各让一半宽度 ⇒ 不越界，尺子必须沉默。
      await tester.pumpWidget(
        wrap(
          children: const [
            SizedBox(width: 160, height: 20),
            SizedBox(width: 160, height: 20),
          ],
        ),
      );
      await tester.pump();
      expect(
        _flexOverflows(tester, find.byKey(const Key('ruler-scope'))),
        isEmpty,
        reason: '不溢出也报 ⇒ 这把尺子只会恒红',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('生产入口（FR-6）', () {
    testWidgets('工作区日历列表档开时间轴：锚定注入的今天，不是设备时钟', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 注入的"今天"**必须落在真实时钟之外**，否则这条绿了不带信息（specs/051 F-1）。
      final wallToday = DateTime.now();
      final pageToday = DateTime(
        wallToday.year,
        wallToday.month,
        wallToday.day,
        12,
      ).add(const Duration(days: 45));
      final label = DateFormat('yyyy 年 M 月 d 日').format(pageToday);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stamp = DateTime.now();
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-1',
              name: '工作',
              updatedAt: stamp,
              createdAt: stamp,
            ),
          );
      final queue = SyncChangeQueue(db);
      final taskRepository = TaskRepository(db, queue);
      await taskRepository.create(
        listId: 'list-1',
        title: '注入日的日程',
        dueAt: DateTime(pageToday.year, pageToday.month, pageToday.day, 9),
      );
      await taskRepository.create(
        listId: 'list-1',
        title: '注入日的全天事项',
        dueAt: pageToday,
        allDay: true,
      );
      await taskRepository.create(
        listId: 'list-1',
        title: '真实今天的事项',
        dueAt: DateTime(wallToday.year, wallToday.month, wallToday.day, 10),
      );

      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepository),
          taskSectionRepositoryProvider.overrideWithValue(
            TaskSectionRepository(db, queue),
          ),
          currentDateTimeProvider.overrideWithValue(() => pageToday),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TasksByListPage(
                initialListId: 'list-1',
                lockedListId: true,
                hideAppBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaskViewMode.calendar.label).last);
      await tester.pumpAndSettle();

      await toListMode(tester);
      await toggleTimeline(tester);

      expect(find.text(label), findsOneWidget, reason: '标题=注入的今天');
      expect(find.text('注入日的日程'), findsOneWidget);
      expect(find.text('注入日的全天事项'), findsOneWidget);
      expect(
        find.text('真实今天的事项'),
        findsNothing,
        reason: '若 widget 里自己 DateTime.now()，锚点会跑到设备那天',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}

/// 手动量每个 RenderFlex 的子节点是否越出自身边界。
///
/// 不用 `takeException()` 当唯一判据：它取走并清空异常，循环量多处时只有第一次有断言力
/// （specs/044 复核的教训）。返回值带像素数与父/子描述，便于归因。
List<String> _flexOverflows(WidgetTester tester, Finder scope) {
  final hits = <String>[];
  void walk(RenderObject node) {
    if (node is RenderFlex) {
      final horizontal = node.direction == Axis.horizontal;
      final bound = horizontal ? node.size.width : node.size.height;
      node.visitChildren((child) {
        if (child is! RenderBox || child.debugNeedsLayout) return;
        final data = child.parentData;
        if (data is! BoxParentData) return;
        final extent = horizontal
            ? data.offset.dx + child.size.width
            : data.offset.dy + child.size.height;
        if (extent > bound + 0.01) {
          hits.add(
            '${horizontal ? '横向' : '纵向'}溢出 ${(extent - bound).toStringAsFixed(1)}px @ ${_describe(node)}',
          );
        }
      });
    }
    node.visitChildren(walk);
  }

  walk(tester.renderObject(scope));
  return hits;
}

String _describe(RenderObject node) {
  return node.toStringShort();
}
