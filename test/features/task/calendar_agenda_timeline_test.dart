import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';

/// 矩阵 #30「日程视图」（Issue #401）。
///
/// 判据源逐字（zh-cloud-docs `origin/develop`，
/// `todo/99_参考资料/dida365-help-center/02-功能指南/02-日历/05-日程视图：以时间串联任务.md`）：
/// - `:5`「滴答清单桌面端提供日程视图，你所有安排好时间的任务会显示在一个时间轴中以线性的方式展示，滚动鼠标滚轮即可轻松查看。」
/// - `:7`「在浏览日程视图中，你可以同时看到过去已完成的任务、当前的进度和未来的计划」
/// - `:14`「点击日历右上角切换视图的选项，选择“日程视图”。」
void main() {
  final now = DateTime(2026, 6, 15, 12);

  TodoTask taskAt({
    required String id,
    required String title,
    required DateTime dueAt,
    bool completed = false,
  }) {
    return TodoTask(
      id: id,
      listId: '1',
      title: title,
      completed: completed,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      startAt: dueAt,
      endAt: dueAt.add(const Duration(hours: 1)),
      dueAt: dueAt,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      updatedAt: now,
      createdAt: now,
    );
  }

  final past = taskAt(
    id: 'past',
    title: '已交付的旧方案评审',
    dueAt: DateTime(2026, 6, 10, 9),
    completed: true,
  );
  final today = taskAt(
    id: 'today',
    title: '当前进行中的联调',
    dueAt: DateTime(2026, 6, 15, 14),
  );
  final future = taskAt(
    id: 'future',
    title: '下下周的排期评审',
    dueAt: DateTime(2026, 6, 26, 9),
  );

  Future<void> pumpAgenda(
    WidgetTester tester,
    List<TodoTask> tasks, {
    double? textScale,
    Size? surface,
  }) async {
    if (surface != null) {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale ?? 1)),
                child: CalendarView(
                  tasks: tasks,
                  now: now,
                  filterCompleted: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // `:14` 说的就是工具栏上的档位切换；本端这一档 label 为「日程」。
    await tester.tap(find.text('日程'));
    await tester.pumpAndSettle();
  }

  /// 时间轴是懒加载的：不在视口里的条目根本不在树上 ⇒ 只能"滚到看见"再断言。
  Future<bool> scrollUntil(
    WidgetTester tester,
    Finder target,
    double delta,
  ) async {
    for (var i = 0; i < 12; i++) {
      if (target.evaluate().isNotEmpty) return true;
      await tester.drag(find.byType(ListView), Offset(0, delta));
      await tester.pumpAndSettle();
    }
    return target.evaluate().isNotEmpty;
  }

  testWidgets('日程视图是一条跨日时间轴：过去与未来在同一条轴上（:5 :7）', (tester) async {
    await pumpAgenda(tester, [past, today, future]);

    expect(_selectedMode(tester), CalendarMode.agenda);
    // 进入时锚点=今天 ⇒ 当天条目必须在视口内
    expect(find.text('当前进行中的联调'), findsOneWidget);

    expect(
      await scrollUntil(tester, find.text('下下周的排期评审'), -200),
      isTrue,
      reason: '轴上没有未来的任务 ⇒ 还是单日列表（:7「未来的计划」）',
    );
    expect(
      await scrollUntil(tester, find.text('已交付的旧方案评审'), 200),
      isTrue,
      reason: '轴上没有过去的已完成任务（:7）',
    );
  });

  testWidgets('按日期线性分组，顺序升序，当天标「今天」（:5）', (tester) async {
    // 传入顺序刻意打乱
    await pumpAgenda(tester, [future, today, past]);

    expect(find.text('6月15日'), findsOneWidget);
    expect(
      await scrollUntil(tester, find.text('6月26日'), -200),
      isTrue,
      reason: '没有按日期分组的线性轴',
    );
    final futureDy = tester.getTopLeft(find.text('6月26日')).dy;
    expect(
      await scrollUntil(tester, find.text('6月10日'), 200),
      isTrue,
      reason: '轴上没有过去的日头',
    );
    expect(
      futureDy,
      greaterThan(tester.getTopLeft(find.text('6月10日')).dy),
      reason: '分组顺序不是时间升序',
    );
    expect(
      await scrollUntil(tester, find.text('今天'), -200),
      isTrue,
      reason: '当天没有标记，读屏与视觉都分不出「当前的进度」在哪一段',
    );
  });

  testWidgets('月视图点日期格仍把那一天滚进视口（锚点语义不丢）', (tester) async {
    await pumpAgenda(tester, [past, today, future]);
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('26'));
    await tester.pumpAndSettle();

    expect(_selectedMode(tester), CalendarMode.agenda);
    expect(find.text('6月26日'), findsOneWidget);
    expect(find.text('下下周的排期评审'), findsOneWidget);
  });

  testWidgets('日头带分组读屏语义（四件套：独立读屏语义）', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAgenda(tester, [past, today, future]);

    final isHeader = find
        .ancestor(of: find.text('6月15日'), matching: find.byType(Semantics))
        .evaluate()
        .map((e) => e.widget)
        .whereType<Semantics>()
        .any((widget) => widget.properties.header == true);
    expect(isHeader, isTrue, reason: '日头只是普通文本，读屏听不出分组边界');
    handle.dispose();
  });

  testWidgets('320px + 1.3 倍字号下时间轴不溢出（四件套）', (tester) async {
    await pumpAgenda(
      tester,
      [past, today, future],
      textScale: 1.3,
      surface: const Size(320, 600),
    );
    expect(tester.takeException(), isNull, reason: '320px/1.3× 下日头或任务行溢出');
    expect(await scrollUntil(tester, find.text('下下周的排期评审'), -200), isTrue);
    expect(tester.takeException(), isNull);
  });
}

CalendarMode _selectedMode(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<CalendarMode>>(
        find.byType(SegmentedButton<CalendarMode>),
      )
      .selected
      .single;
}
