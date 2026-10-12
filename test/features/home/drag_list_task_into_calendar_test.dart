import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/workspace_companion.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》第 49/51 行（术语照抄）：
/// 「将清单中的任务拖入日历：」「为任务快速添加日期或具体时间，不需要打开编辑界面，直接拖动即可。」
/// Issue #397，矩阵 #32 的「拖动排期」面 ①。
///
/// fixture 的固定时钟是 `2026-07-11 09:00`，被拖的主任务 `dueAt = 2026-07-11 11:00`。
/// 目标日 `2026-07-18` 与源日不同周 ⇒ 落点必须"改日期"，不能"看着没动"。
const _taskId = TodoVisualFixture.todayTaskId;
const _otherTaskId = TodoVisualFixture.metadataTaskId;
const _taskTitle = '完成 Todo 工作区视觉评审';
final _fromDay = DateTime(2026, 7, 11);
final _toDay = DateTime(2026, 7, 18);

class _CompanionStorage implements WorkspaceCompanionStorage {
  _CompanionStorage(this.raw);

  final String? raw;

  @override
  Future<String?> readString(String key) async => raw;

  @override
  Future<bool> writeString(String key, String value) async => true;
}

/// `_DayCell` 的 `DragTarget` key 形状，见 `calendar_view.dart` 的
/// `ValueKey('calendar-day-…')`。
Finder _dayCell(DateTime day) =>
    find.byKey(ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'));

Finder get _companionPane => find.byKey(const Key('todo-companion'));
Finder get _row => find.byKey(const ValueKey(_taskId));
Finder get _otherRow => find.byKey(const ValueKey(_otherTaskId));

/// 把 `moveCalendarTask` 打成失败，用来验「写不下去要有可见反馈」。
/// 构造方式沿用同仓先例 `task_list_reorder_widget_test.dart:117-131`。
class _FailingTaskViewActionRepository extends TaskViewActionRepository {
  _FailingTaskViewActionRepository(AppDatabase db, this.failure)
    : super(db, SyncChangeQueue(db));

  final Object failure;

  @override
  Future<void> moveCalendarTask(
    String taskId, {
    required DateTime dueAt,
  }) async {
    throw failure;
  }
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  required String? companionRaw,
  Object? moveFailure,
}) => pumpTodoVisualScenario(
  tester,
  viewport: TodoVisualViewports.wide,
  fixtureSet: TodoVisualFixtureSet.populated,
  overridesBuilder: (database) => [
    workspaceCompanionStorageProvider.overrideWithValue(
      _CompanionStorage(companionRaw),
    ),
    if (moveFailure != null)
      taskViewActionRepositoryProvider.overrideWithValue(
        _FailingTaskViewActionRepository(database, moveFailure),
      ),
  ],
  child: const HomeShell(),
);

/// 长按清单行拖起、落到目标格。节奏与 `eisenhower_quadrant_drag_test.dart:204-218`
/// 一致（按住过长按阈值 → 移动 → 抬起），差别只在起点是清单行。
Future<void> _dragFromTo(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<DateTime?> _dueAtOf(TodoVisualFixture fixture, String taskId) async {
  final row = await (fixture.database.select(
    fixture.database.todoTasks,
  )..where((t) => t.id.equals(taskId))).getSingle();
  return row.dueAt;
}

Future<DateTime?> _dueAt(TodoVisualFixture fixture) =>
    _dueAtOf(fixture, _taskId);

Future<Map<String, int>> _sortOrderById(TodoVisualFixture fixture) async {
  final rows = await fixture.database.select(fixture.database.todoTasks).get();
  return {for (final r in rows) r.id: r.sortOrder};
}

const _calendar = 'calendarBesideTasks';

void main() {
  testWidgets('并列副栏的日历显示 app 时钟那个月（现在它读的是真实时钟）', (tester) async {
    await _pump(tester, companionRaw: jsonEncode({'companion': _calendar}));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _companionPane, matching: _dayCell(_fromDay)),
      findsOneWidget,
      reason:
          'fixture 把时钟定在 2026-07-11（currentDateTimeProvider），副栏日历就该画 7 月。'
          'home_shell 构造 CalendarView 时没传 now:，月视图落到 DateTime.now() 那个月 ⇒ '
          '清单里 7 月的任务在格子上看不见，"拖入日历"在测试里根本无处可放',
    );
  });

  testWidgets('并列视图下把清单任务拖进日历格，日期真的写进本地库（Issue #397 主路径）', (tester) async {
    final fixture = await _pump(
      tester,
      companionRaw: jsonEncode({'companion': _calendar}),
    );
    await tester.pumpAndSettle();

    expect(
      _row,
      findsOneWidget,
      reason: '清单行按 ValueKey(task.id) 挂在 KeyedSubtree 上',
    );
    expect(
      await _dueAt(fixture),
      _fromDay.copyWith(hour: 11, minute: 0),
      reason: '起点：主任务今天 11:00 到期',
    );

    await _dragFromTo(tester, _row, _dayCell(_toDay));

    final after = await _dueAt(fixture);
    expect(
      after,
      _toDay.copyWith(hour: 11, minute: 0),
      reason: '原钟点 11:00 要跟着挪到目标日，不能变 00:00、也不能不写',
    );
    expect(
      find.descendant(of: _dayCell(_toDay), matching: find.text(_taskTitle)),
      findsOneWidget,
      reason: '落完之后日历格上就该看到这个任务',
    );
  });

  testWidgets('拖到任务原本那一天不改日期、也不报错（反向对照：拒绝条件是落点判定）', (tester) async {
    final fixture = await _pump(
      tester,
      companionRaw: jsonEncode({'companion': _calendar}),
    );
    await tester.pumpAndSettle();

    await _dragFromTo(tester, _row, _dayCell(_fromDay));

    expect(
      await _dueAt(fixture),
      _fromDay.copyWith(hour: 11, minute: 0),
      reason: '同一天不该产生一次写入（也不该登记同步变更）',
    );
    expect(
      find.text('日历改期失败，请重试'),
      findsNothing,
      reason: '被拒绝不该伪装成失败；真的写不下去才该给这句话',
    );
  });

  testWidgets('长按拖出走的是排期，不动清单顺序（与「拖动排序」把手各走各路）', (tester) async {
    final fixture = await _pump(
      tester,
      companionRaw: jsonEncode({'companion': _calendar}),
    );
    await tester.pumpAndSettle();

    final before = await _sortOrderById(fixture);
    final otherBefore = await _dueAtOf(fixture, _otherTaskId);
    expect(
      tester.getRect(_row).top < tester.getRect(_otherRow).top,
      isTrue,
      reason: '起点：主任务排在另一行之上，否则这条对照没意义',
    );

    await _dragFromTo(tester, _row, _dayCell(_toDay));

    expect(
      await _sortOrderById(fixture),
      before,
      reason:
          '拖进日历只写 dueAt；若拖出源把整行交给了 ReorderableListView 的 onReorder，'
          '全表 sortOrder 会被重排（逐条比 id→sortOrder，比只比顺序更能抓到"整体重编号"）',
    );
    expect(
      await _dueAtOf(fixture, _otherTaskId),
      otherBefore,
      reason: '只改被拖的那一行，不该把邻居任务的日期一起洗掉',
    );
  });

  testWidgets('并列关闭时清单行拖出去无处可放（四面确实限定在并列视图里）', (tester) async {
    final fixture = await _pump(tester, companionRaw: null);
    await tester.pumpAndSettle();

    expect(_companionPane, findsNothing, reason: '源页 :47「在任务与日历并列显示的视图中，你可以：」');
    expect(await _dueAt(fixture), _fromDay.copyWith(hour: 11, minute: 0));
  });

  testWidgets('包一层拖出源不吞掉清单行的读屏语义', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, companionRaw: jsonEncode({'companion': _calendar}));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _row, matching: find.text(_taskTitle)),
      findsOneWidget,
      reason: '标题文案仍在这行之内（先钉住"可读的东西还在"）',
    );
    expect(
      find.bySemanticsLabel(RegExp(_taskTitle.substring(0, 6))),
      findsWidgets,
      reason:
          '语义树里标题仍可被读屏点到：拖出源只是手势容器，'
          '若被包成 Semantics(container: true)/ExcludeSemantics 这一条就会红',
    );
    handle.dispose();
  });

  testWidgets('写不下去时给可见反馈，本地日期保持原值', (tester) async {
    final fixture = await _pump(
      tester,
      companionRaw: jsonEncode({'companion': _calendar}),
      moveFailure: StateError('本地写入失败'),
    );
    await tester.pumpAndSettle();

    await _dragFromTo(tester, _row, _dayCell(_toDay));

    expect(
      find.text('日历改期失败，请重试'),
      findsOneWidget,
      reason:
          '正向对照：CalendarView._moveTask（calendar_view.dart:694-707）会把回调抛出的错误转成可见反馈。'
          '没有这条，上一条用例里那句 findsNothing 永远为真、量不到任何东西',
    );
    expect(
      await _dueAt(fixture),
      _fromDay.copyWith(hour: 11, minute: 0),
      reason: '失败不该把本地已加载的数据改成没写成的样子',
    );
  });
}
