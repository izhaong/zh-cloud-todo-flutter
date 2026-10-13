import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

/// 判据源《02-功能指南/02-日历/03-年视图：查看年度任务完成情况.md》`:64`
/// 「点击日期 → 跳转至周视图，并高亮显示所选日期」。本仓年视图里唯一按「日」
/// 呈现的的表面是热力图日格（`:74`「年视图支持以热力图方式展示任务完成频率」），
/// 所以这一面的落点就是热力图日格：点它必须跳到周视图并把那天标成选中。
const _selectedDayKey = Key('calendar-week-selected-day');

/// 日格 key 形态沿用既有约定（见 calendar_year_heatmap_test.dart:22）：
/// `calendar-year-day-<yyyy-MM-dd>`。
Key _dayKey(DateTime d) => Key(
  'calendar-year-day-'
  '${d.year.toString().padLeft(4, '0')}-'
  '${d.month.toString().padLeft(2, '0')}-'
  '${d.day.toString().padLeft(2, '0')}',
);

TodoTask _completedOn(DateTime day, int n) {
  return TodoTask(
    id: 'yday-$n-${day.millisecondsSinceEpoch}',
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    title: '任务 yday-$n',
    completed: true,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: day,
    completedAt: day,
    updatedAt: day,
    createdAt: day,
  );
}

TodoTask _openOn(DateTime day) {
  return TodoTask(
    id: 'yday-open-\${day.millisecondsSinceEpoch}',
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    title: '任务 yday-open',
    completed: false,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: day,
    updatedAt: day,
    createdAt: day,
  );
}

/// 写偏好失败时必须保留已经生效的视图（四件套「失败保留已加载数据」）。
class _ThrowingRepository extends TaskViewActionRepository {
  _ThrowingRepository(super.db, super.queue);

  @override
  Future<void> saveCalendarDisplay({
    required String viewMode,
    required bool showCompletedTasks,
    required bool showHeatmap,
    String colorBy = 'priority',
  }) async {
    throw Exception('离线写入失败');
  }
}

/// 年视图 + 已开启的热力图。热力图默认是关的（`:76`），所以必须先在显示
/// 设置里打开，日格才会出现；这一步也顺便证明日格真的在渲染。
Future<void> _pumpYear(
  WidgetTester tester, {
  required TaskViewActionRepository? repository,
  required List<TodoTask> tasks,
  Size? surface,
  double textScale = 1.0,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskViewActionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: CalendarView(tasks: tasks, now: DateTime(2026, 6, 15, 12)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('年'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calendar-display-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calendar-show-heatmap')));
  await tester.pumpAndSettle();
}

/// 点开热力图开关后再点日格（日格只有 14px，滚动到可见再打，避免假 off-screen）。
Future<void> _tapYearDay(WidgetTester tester, DateTime day) async {
  final cell = find.byKey(_dayKey(day));
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

void main() {
  final selected = DateTime(2026, 3, 5);
  final tasks = [
    for (var i = 0; i < 3; i++) _completedOn(selected, i),
    _openOn(selected),
  ];

  testWidgets('点年视图日格 → 跳周视图并把锚点落到那一天（:64 前半句）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpYear(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    // 正向对照：日格确实在渲染，否则下面的断言是假阴性。
    expect(find.byKey(_dayKey(selected)), findsOneWidget);
    // 「3/5」属于三月，锚点在六月时周视图里不该出现。
    expect(find.text('3/5'), findsNothing);

    await _tapYearDay(tester, selected);

    // 已经离开年视图（日格消失）并落在以 3/5 为锚的周视图。
    expect(find.byKey(_dayKey(selected)), findsNothing);
    expect(find.text('3/5'), findsWidgets);
  });

  testWidgets('所选日期带「已选中」语义，未点之前没有（:64 后半句）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpYear(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    expect(find.byKey(_selectedDayKey), findsNothing);

    await _tapYearDay(tester, selected);

    expect(find.byKey(_selectedDayKey), findsOneWidget);
    final data = tester.getSemantics(find.byKey(_selectedDayKey));
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.label, contains('3/5'));
    // 一周只高亮所选那一天。
    expect(find.byKey(_selectedDayKey), findsOneWidget);
  });

  testWidgets('320px + 1.3 倍字号下日格仍可点，高亮落在视口内（四件套）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpYear(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
      surface: const Size(320, 700),
      textScale: 1.3,
    );
    await _tapYearDay(tester, selected);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_selectedDayKey), findsOneWidget);
    final rect = tester.getRect(find.byKey(_selectedDayKey));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(700));
    // 点完之后任务不能少（失败/切换都不许丢已加载数据）。
    expect(find.text('任务 yday-open'), findsWidgets);
  });

  testWidgets('写偏好失败时视图与高亮都不回退（失败保留已加载数据）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpYear(
      tester,
      repository: _ThrowingRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    await _tapYearDay(tester, selected);

    expect(find.byKey(_selectedDayKey), findsOneWidget);
    expect(find.text('3/5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
