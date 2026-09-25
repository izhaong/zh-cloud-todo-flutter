import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/time/week_start.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_section_repository.dart';

const _glyphs = ['一', '二', '三', '四', '五', '六', '日'];

/// 今天 = 2026-09-25（周五）。2026-06-01 是周一，用来钉月视图的填充方向。
final _now = DateTime(2026, 9, 25, 12);

TodoTask _task({required String id, required DateTime dueAt}) {
  return TodoTask(
    id: id,
    listId: '1',
    allDay: true,
    fixedTimezone: false,
    title: '任务 $id',
    completed: false,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    startAt: null,
    endAt: null,
    dueAt: dueAt,
    updatedAt: _now,
    createdAt: _now,
  );
}

/// 月视图最上面那一排的表头字形，按屏幕从左到右排。
///
/// 用 `find.byWidget` 精确定位每个 Text，不去按字搜 —— 日期格里也可能
/// 出现同字，按字搜会撞上不唯一的 finder。
String _headerGlyphOrder(WidgetTester tester) {
  final cells = <(String, double, double)>[];
  for (final widget in tester.widgetList<Text>(
    find.byWidgetPredicate(
      (widget) => widget is Text && _glyphs.contains(widget.data),
    ),
  )) {
    final rect = tester.getRect(find.byWidget(widget));
    cells.add((widget.data!, rect.left, rect.top));
  }
  if (cells.isEmpty) return '';
  final topRow = cells.map((e) => e.$3).reduce((a, b) => a < b ? a : b);
  return (cells.where((e) => (e.$3 - topRow).abs() < 0.5).toList()
        ..sort((a, b) => a.$2.compareTo(b.$2)))
      .map((e) => e.$1)
      .join();
}

/// 先回一帧「周日」，随后抛错 —— 让 provider 自己产生"带旧值的 AsyncError"。
/// 不自己拼 AsyncValue：riverpod 2.6.1 没有"带着旧值构造 error"的公开入口。
Stream<int> _sundayThenError() async* {
  yield DateTime.sunday;
  throw StateError('刷新偏好失败');
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  int? firstDay,
  bool pendingForever = false,
  Stream<int>? stream,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (stream != null) weekStartProvider.overrideWith((ref) => stream),
        // pendingForever = 首值未到（FR-7 的 loading 态）：给一条不回包也不报错的流
        if (pendingForever)
          weekStartProvider.overrideWith((ref) => const Stream<int>.empty()),
        if (firstDay != null)
          weekStartProvider.overrideWith((ref) => Stream<int>.value(firstDay)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CalendarView(tasks: const [], now: DateTime(2026, 6, 15, 12)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTimeline(WidgetTester tester, {int firstDay = 1}) async {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 时间线不自己 watch provider（生产由 tasks_by_list_page.dart 注入），
  // 所以这里按同样的方式喂参数：裸 pump、不套 ProviderScope。
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TimelineView(
          tasks: [_task(id: 'sun', dueAt: DateTime(2026, 9, 27, 9))],
          now: _now,
          firstDay: firstDay,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 收尾必须**在用例体内**卸载，再推进两帧：TaskRepository 用的是 drift 的 `watch()`，
/// 退订时排了一个零时长定时器，留给 binding 就报「A Timer is still pending」。
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('buildMonthGrid（FR-5 网格）', () {
    final anchor = DateTime(2026, 6, 15);

    test('默认档与 develop 一致：6 月 1 日就是左上角第一格', () {
      final grid = buildMonthGrid(anchor);
      expect(grid[0][0], DateTime(2026, 6, 1));
    });

    test('周日档：左上角变成 5 月 31 日（周日）', () {
      final grid = buildMonthGrid(anchor, firstDay: DateTime.sunday);
      expect(grid[0][0], DateTime(2026, 5, 31));
      expect(grid[0][0].weekday, DateTime.sunday);
    });

    test('周六档：左上角变成 5 月 30 日（周六）', () {
      final grid = buildMonthGrid(anchor, firstDay: DateTime.saturday);
      expect(grid[0][0], DateTime(2026, 5, 30));
      expect(grid[0][0].weekday, DateTime.saturday);
    });

    test('每行的星期序列都必须等于同一档位的列序（表头与网格同源）', () {
      for (final firstDay in WeekStart.allowedFirstDays) {
        final grid = buildMonthGrid(anchor, firstDay: firstDay);
        expect(grid.length, 6);
        final expected = WeekStart.columnOrder(firstDay: firstDay);
        for (final row in grid) {
          expect(row.length, 7);
          expect(
            row.map((d) => d.weekday).toList(),
            expected,
            reason: 'firstDay=$firstDay 的行内列序与 columnOrder 不一致',
          );
        }
        // 42 格必须逐日连续，不能因为换档位漏一天
        final flat = [for (final row in grid) ...row];
        for (var i = 1; i < flat.length; i++) {
          expect(
            flat[i].difference(flat[i - 1]).inDays,
            1,
            reason: 'firstDay=$firstDay 第 $i 格与前一格不连续',
          );
        }
      }
    });
  });

  group('weekdayGlyph（FR-5 表头字形）', () {
    test('字形集合不新增不丢失，仍是嘀嗒那七个单字', () {
      final seen = [for (var w = 1; w <= 7; w++) weekdayGlyph(w)];
      expect(seen.toSet(), _glyphs.toSet());
      expect(seen.length, 7);
    });

    test('三档下第一列的字形就是该档的日子', () {
      expect(weekdayGlyph(WeekStart.columnOrder().first), '一');
      expect(
        weekdayGlyph(WeekStart.columnOrder(firstDay: DateTime.sunday).first),
        '日',
      );
      expect(
        weekdayGlyph(WeekStart.columnOrder(firstDay: DateTime.saturday).first),
        '六',
      );
    });
  });

  group('timelineWindowLabel（FR-6 周档窗口）', () {
    final friday = DateTime(2026, 9, 25);

    test('周档标签随档位移动', () {
      expect(timelineWindowLabel(friday, TimelineScale.week), '9/21–9/27');
      expect(
        timelineWindowLabel(
          friday,
          TimelineScale.week,
          firstDay: DateTime.sunday,
        ),
        '9/20–9/26',
      );
      expect(
        timelineWindowLabel(
          friday,
          TimelineScale.week,
          firstDay: DateTime.saturday,
        ),
        '9/19–9/25',
      );
    });

    test('日档与月档不受档位影响（没顺手改别的能力）', () {
      for (final firstDay in WeekStart.allowedFirstDays) {
        expect(
          timelineWindowLabel(friday, TimelineScale.day, firstDay: firstDay),
          '9月25日',
        );
        expect(
          timelineWindowLabel(friday, TimelineScale.month, firstDay: firstDay),
          '2026年9月',
        );
      }
    });
  });

  group('resolveWeekStartFirstDay（FR-7 三态）', () {
    test('有值用值', () {
      expect(resolveWeekStartFirstDay(const AsyncValue<int>.data(7)), 7);
    });

    test('首值未到退回默认周一（不抛、不留空）', () {
      expect(
        resolveWeekStartFirstDay(const AsyncValue<int>.loading()),
        WeekStart.defaultFirstDay,
      );
    });

    test('报错且没有旧值时退回默认周一', () {
      final v = AsyncValue<int>.error(StateError('故意读失败'), StackTrace.empty);
      expect(resolveWeekStartFirstDay(v), WeekStart.defaultFirstDay);
    });
  });

  group('日历接线（FR-5 端到端）', () {
    testWidgets('默认档表头从左到右是 一…日', (tester) async {
      await _pumpCalendar(tester);
      expect(_headerGlyphOrder(tester), '一二三四五六日');
    });

    testWidgets('档位改成周日，表头整行左移到「日」开头', (tester) async {
      await _pumpCalendar(tester, firstDay: DateTime.sunday);
      expect(_headerGlyphOrder(tester), '日一二三四五六');
    });

    testWidgets('先给周日、随后流报错：旧档位保留，不被兜底盖回周一', (tester) async {
      // 第 74 轮教训：这种"带旧值的 AsyncError"若走 when(error:) 就会被丢回默认档。
      // 这里不自己造 AsyncValue（riverpod 2.6.1 没有那种公开构造），
      // 用真实流先回包再报错，让 provider 自己产生该状态。
      await _pumpCalendar(tester, stream: _sundayThenError());
      expect(
        _headerGlyphOrder(tester),
        '日一二三四五六',
        reason: '报错后应继续用已到达的旧档位（周日），而不是退回周一',
      );
    });

    testWidgets('首值未到（loading）时日历按默认周一画，不留空表头', (tester) async {
      await _pumpCalendar(tester, pendingForever: true);
      expect(_headerGlyphOrder(tester), '一二三四五六日');
      expect(tester.takeException(), isNull);
    });

    testWidgets('不传档位时按默认周一分桶（= develop 行为）', (tester) async {
      await _pumpTimeline(tester);
      expect(find.text('本周'), findsOneWidget);
      expect(find.text('下周'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('时间线接线（FR-6 端到端）', () {
    // 空段不落标题（`timeline_view.dart` 里 `if (group.items.isEmpty)
    // return const SizedBox.shrink()`），所以"落在哪一段"直接等于
    // "哪一段标题出现"，比按 dy 猜段界可靠。
    testWidgets('默认周一档：9/27（周日）算本周', (tester) async {
      await _pumpTimeline(tester);
      expect(find.text('任务 sun'), findsOneWidget);
      expect(find.text('本周'), findsOneWidget);
      expect(find.text('下周'), findsNothing);
    });

    testWidgets('改成周日档：同一条 9/27 的任务挪到下周段', (tester) async {
      await _pumpTimeline(tester, firstDay: DateTime.sunday);
      expect(find.text('任务 sun'), findsOneWidget);
      expect(find.text('下周'), findsOneWidget);
      expect(find.text('本周'), findsNothing, reason: '周首=周日时 9/27 已是下一周的第一天');
    });
  });

  group('生产接线（tasks_by_list_page.dart 的注入线）', () {
    // 上面那组直接 pump `TimelineView(firstDay: …)`，钉的是"给了档位就会分对桶"；
    // 本组从生产入口进，钉的是 `tasks_by_list_page.dart` 那句
    // `firstDay: resolveWeekStartFirstDay(ref.watch(weekStartProvider))` 真在喂档位。
    // 因为 TimelineView 的默认值就是周一，"忘了注入"会静默退回周一 —— 只有走真实
    // 入口才钉得住这条线，所以这一组不能由上面那组代替。
    Future<void> pumpWorkspace(
      WidgetTester tester, {
      required int firstDay,
    }) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final taskRepository = TaskRepository(db, queue);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-a',
              name: '工作',
              updatedAt: _now,
              createdAt: _now,
            ),
          );
      await taskRepository.create(
        listId: 'list-a',
        title: '任务 sun',
        dueAt: DateTime(2026, 9, 27, 9),
        allDay: true,
      );
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepository),
          taskSectionRepositoryProvider.overrideWithValue(
            TaskSectionRepository(db, queue),
          ),
          currentDateTimeProvider.overrideWithValue(() => _now),
          weekStartProvider.overrideWith((ref) => Stream<int>.value(firstDay)),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TasksByListPage(
                initialListId: 'list-a',
                lockedListId: true,
                hideAppBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaskViewMode.timeline.label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('周一档：生产入口的周窗口标题是 9/21–9/27', (tester) async {
      await pumpWorkspace(tester, firstDay: DateTime.monday);
      expect(find.text('任务 sun'), findsOneWidget);
      // 判据取"时间线自己算出来的周窗口标题"（围绕**今天**，不是围绕任务）：
      // 周一档 = 9/21–9/27、周日档 = 9/20–9/26，差整整一天，只能由喂进来的 firstDay 决定，
      // 所以这一行等价于"注入线通了"。上面那组直接 pump TimelineView 断的是段标题（本周/
      // 下周）—— 页面里那套带日期列的布局不渲染段标题，照抄过来会恒 0 命中（实测撞过）。
      expect(find.text('9/21–9/27'), findsOneWidget);
      expect(find.text('9/20–9/26'), findsNothing);

      await _unmountAndSettle(tester);
    });

    testWidgets('周日档：同一入口把周窗口挪成 9/20–9/26', (tester) async {
      await pumpWorkspace(tester, firstDay: DateTime.sunday);
      expect(find.text('任务 sun'), findsOneWidget);
      expect(find.text('9/20–9/26'), findsOneWidget);
      expect(
        find.text('9/21–9/27'),
        findsNothing,
        reason: '注入线断掉时静默退回默认周一，标题就还是 9/21–9/27',
      );

      await _unmountAndSettle(tester);
    });
  });
}
