import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/todo_layout_tokens.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar_task_drop.dart';
import 'package:zh_cloud_todo_flutter/features/shell/smart_list_time_condition.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》`:61`「拖动到智能清单上」
/// `:63`「会为任务自动添加该智能清单关联的时间条件，例如“今天”、“本周”等。」
///
/// 智能清单行与清单行 / 标签行共用 `SidebarDropZone` 和同一个编排控制器，
/// 所以这里只量智能清单独有的三件事：**哪几行是落点**、**落到哪一天**、**条件已满足时不写**。
const _dragSourceLabel = '拖这块';
const _wide = Size(1280, 900);

Finder _smartZone(SmartList smart) =>
    find.byKey(ValueKey('todo-sidebar-drop-smart-${smart.name}'));

Finder _hoverSemantics(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && propertiesLabelOf(widget) == label,
);

String? propertiesLabelOf(Widget widget) =>
    widget is Semantics ? widget.properties.label : null;

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 落点日与本端窗口都按 `DateTime.now()` 现算，所以种子也只能由同一个时钟推出来。
DateTime _dueAt({required int offsetDays, int hour = 9, int minute = 30}) =>
    _startOfToday().add(
      Duration(days: offsetDays, hours: hour, minutes: minute),
    );

TodoTask _payload(DateTime? dueAt) => TodoTask(
  id: TodoVisualFixture.metadataTaskId,
  serverId: null,
  listId: TodoVisualFixture.inboxListId,
  allDay: false,
  fixedTimezone: false,
  timeMode: 0,
  title: '拖拽载荷',
  completed: false,
  cancelled: false,
  priority: 0,
  isPinned: false,
  sortOrder: 0,
  dueAt: dueAt,
  updatedAt: DateTime(2026, 10, 1, 8),
  createdAt: DateTime(2026, 10, 1, 8),
);

Future<TodoTask> _readTask(AppDatabase db) => (db.select(
  db.todoTasks,
)..where((t) => t.id.equals(TodoVisualFixture.metadataTaskId))).getSingle();

Future<int> _outboxCount(AppDatabase db) async =>
    (await db.select(db.todoSyncChanges).get()).length;

/// 把库里的种子写成**载荷同一份** dueAt：`accept` 读载荷、写库读行，
/// 两边必须同字节，否则用例在测「载荷与库不一致」这种界外情况。
/// 直接走 Drift 更新（不经仓储），所以这一步不产生 outbox。
Future<void> _seedRow(AppDatabase db, DateTime? dueAt) =>
    (db.update(
      db.todoTasks,
    )..where((t) => t.id.equals(TodoVisualFixture.metadataTaskId))).write(
      TodoTasksCompanion(
        dueAt: dueAt == null ? const Value(null) : Value(dueAt),
        allDay: const Value(false),
      ),
    );

Future<TodoVisualFixture> _pumpShell(
  WidgetTester tester, {
  required TodoTask task,
  Size viewport = _wide,
  double? sidebarWidth,
  double textScale = 1,
  SidebarTaskDropController? controller,
  bool withScaffold = false,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final rows = Column(
    children: [
      SizedBox(
        height: 48,
        child: Center(
          child: Draggable<TodoTask>(
            data: task,
            feedback: Material(child: Text(task.title)),
            child: const Text(_dragSourceLabel),
          ),
        ),
      ),
      Expanded(
        child: Sidebar(
          width: sidebarWidth ?? TodoLayoutTokens.wideSidebarWidth,
          selectedSection: Section.tasks,
          selectedSmart: SmartList.inbox,
          selectedListId: null,
          onSelectSection: (_) {},
          onSelectSmart: (_) {},
          onSelectList: (_) {},
          onOpenTags: () {},
          onOpenFilters: () {},
          onOpenSettings: () {},
        ),
      ),
    ],
  );
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport,
    fixtureSet: TodoVisualFixtureSet.populated,
    overridesBuilder: controller == null
        ? null
        : (database) => [
            sidebarTaskDropControllerProvider.overrideWithValue(controller),
          ],
    // 失败提示走 ScaffoldMessenger：它要求树上有 Scaffold 可投，
    // 所以只有量提示的那条用例套 Scaffold（其余保持与清单行用例同样的裸 Material）。
    child: withScaffold ? Scaffold(body: rows) : Material(child: rows),
  );
}

/// 种好库、挂上同一份载荷、返回夹具（每次 pump 都是新内存库，所以只 pump 一次）。
Future<TodoVisualFixture> _pumpSeeded(
  WidgetTester tester, {
  required DateTime? dueAt,
  Size viewport = _wide,
  double? sidebarWidth,
  double textScale = 1,
  SidebarTaskDropController? controller,
  bool withScaffold = false,
}) async {
  final payload = _payload(dueAt);
  final fixture = await _pumpShell(
    tester,
    task: payload,
    viewport: viewport,
    sidebarWidth: sidebarWidth,
    textScale: textScale,
    controller: controller,
    withScaffold: withScaffold,
  );
  await _seedRow(fixture.database, dueAt);
  final row = await _readTask(fixture.database);
  expect(row.dueAt, dueAt, reason: '种子没写进去 ⇒ 后面的断言全是空比空');
  expect(row.id, payload.id, reason: '载荷与库里必须是同一行');
  return fixture;
}

Future<void> _dragTo(
  WidgetTester tester,
  Finder target, {
  Future<void> Function()? whileHovering,
}) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  final gesture = await tester.startGesture(
    tester.getCenter(find.text(_dragSourceLabel)),
  );
  await tester.pump();
  await gesture.moveBy(const Offset(0, 24));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  if (whileHovering != null) await whileHovering();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 用任务页真实的过滤谓词判断「这条任务现在算不算这一档」——
/// 落点写完必须让任务真的出现在刚拖上去的那个清单里，这句要能量住。
bool _matchesFilter(DateTime? due, String dueRange, DateTime now) =>
    applyTaskFilter(
      <TodoTask>[
        TodoTask(
          id: 'probe',
          serverId: null,
          listId: 'probe-list',
          allDay: false,
          fixedTimezone: false,
          timeMode: 0,
          title: '探针',
          completed: false,
          cancelled: false,
          priority: 0,
          isPinned: false,
          sortOrder: 0,
          dueAt: due,
          updatedAt: now,
          createdAt: now,
        ),
      ],
      TaskFilter(dueRange: dueRange),
      null,
      now,
    ).isNotEmpty;

void main() {
  group('编排：只在条件未满足时才写', () {
    final now = DateTime(2026, 10, 12, 14, 5);

    SidebarTaskDropController controllerOf(
      List<DateTime> writes, {
      bool fail = false,
    }) {
      return SidebarTaskDropController(
        moveTask: (taskId, listId) async {},
        attachTag: (taskId, tagId) async {},
        scheduleToDay: (taskId, targetDay) async {
          if (fail) throw StateError('故意写失败');
          writes.add(targetDay);
        },
      );
    }

    test('截止已在今天 ⇒ skipped，一次写都不发', () async {
      final writes = <DateTime>[];
      final controller = controllerOf(writes);
      final condition = smartListTimeConditionOf(SmartList.today, now)!;
      final task = _payload(DateTime(2026, 10, 12, 9, 0));

      expect(
        controller.acceptsSmartList(task, condition),
        isFalse,
        reason: '已经在这一档里还写一遍 = 白发一次同步变更',
      );
      expect(
        await controller.applySmartListTimeCondition(task, condition),
        SidebarDropOutcome.skipped,
      );
      expect(writes, isEmpty);
    });

    test('三档各写自己的落点日（+30 天谁都不满足）', () async {
      for (final smart in [
        SmartList.today,
        SmartList.tomorrow,
        SmartList.upcoming,
      ]) {
        final writes = <DateTime>[];
        final condition = smartListTimeConditionOf(smart, now)!;
        final outcome = await controllerOf(writes).applySmartListTimeCondition(
          _payload(DateTime(2026, 11, 11, 8)),
          condition,
        );
        expect(outcome, SidebarDropOutcome.applied, reason: smart.name);
        expect(writes, [condition.targetDay], reason: '${smart.name} 的落点日');
      }
    });

    test('无日期任务一定是有效落点，并写到窗口首日', () async {
      final writes = <DateTime>[];
      final condition = smartListTimeConditionOf(SmartList.upcoming, now)!;
      final task = _payload(null);

      expect(controllerOf(writes).acceptsSmartList(task, condition), isTrue);
      expect(
        await controllerOf(writes).applySmartListTimeCondition(task, condition),
        SidebarDropOutcome.applied,
      );
      expect(writes, [DateTime(2026, 10, 13)]);
    });

    test('今天 09:00 的任务拖到「最近七天」要挪到明天（今天不在这一档窗口里）', () async {
      final writes = <DateTime>[];
      final condition = smartListTimeConditionOf(SmartList.upcoming, now)!;
      final task = _payload(DateTime(2026, 10, 12, 9));

      expect(condition.satisfiedBy(DateTime(2026, 10, 12, 9)), isFalse);
      expect(
        await controllerOf(writes).applySmartListTimeCondition(task, condition),
        SidebarDropOutcome.applied,
      );
      expect(writes, [DateTime(2026, 10, 13)]);
    });

    test('写失败上抛为 failed（侧栏据此弹提示）', () async {
      final condition = smartListTimeConditionOf(SmartList.today, now)!;
      expect(
        await controllerOf(
          <DateTime>[],
          fail: true,
        ).applySmartListTimeCondition(
          _payload(DateTime(2026, 10, 20, 9)),
          condition,
        ),
        SidebarDropOutcome.failed,
      );
    });
  });

  group('真侧栏 + 真库 + 真手势', () {
    testWidgets('拖到「今天」行 ⇒ 截止日挪到今天、墙上时刻保留，清单与分组都不动', (tester) async {
      final due = _dueAt(offsetDays: 3);
      final fixture = await _pumpSeeded(tester, dueAt: due);
      final db = fixture.database;
      final before = await _readTask(db);
      final outboxBefore = await _outboxCount(db);
      // 正向对照：落点行确实挂在侧栏上，否则下面的断言全在测「没接线」。
      expect(_smartZone(SmartList.today), findsOneWidget);

      await _dragTo(tester, _smartZone(SmartList.today));

      final after = await _readTask(db);
      expect(
        DateTime(after.dueAt!.year, after.dueAt!.month, after.dueAt!.day),
        _startOfToday(),
        reason: ':63 要的就是「添加该智能清单关联的时间条件」',
      );
      expect(after.dueAt!.hour, due.hour, reason: '只换日，不该把 09:30 抹成 00:00');
      expect(after.dueAt!.minute, due.minute);
      expect(after.listId, before.listId, reason: '这一句说的是时间，不是换清单');
      expect(after.sectionId, before.sectionId);
      expect(await _outboxCount(db), outboxBefore + 1, reason: '真写了一次就要真入队一次');
    });

    testWidgets('拖到「最近七天」行 ⇒ 落到窗口首日，且谓词侧真的能看见它', (tester) async {
      final due = _dueAt(offsetDays: 30, hour: 14);
      final fixture = await _pumpSeeded(tester, dueAt: due);
      final now = DateTime.now();
      expect(
        _matchesFilter(due, 'next7days', now),
        isFalse,
        reason: '落点前它必须不在「最近七天」里，否则这条用例恒真',
      );

      await _dragTo(tester, _smartZone(SmartList.upcoming));

      final after = await _readTask(fixture.database);
      expect(
        DateTime(after.dueAt!.year, after.dueAt!.month, after.dueAt!.day),
        _startOfToday().add(const Duration(days: 1)),
        reason: '本端「最近七天」= 明天起 7 天 ⇒ 首日就是明天',
      );
      expect(
        _matchesFilter(after.dueAt, 'next7days', now),
        isTrue,
        reason: '拖完必须真的出现在刚拖上去的那个清单里',
      );
    });

    testWidgets('截止已在今天 ⇒ 拖到「今天」行不写、不入队、不报失败', (tester) async {
      final due = _dueAt(offsetDays: 0, hour: 8);
      final fixture = await _pumpSeeded(tester, dueAt: due);
      final db = fixture.database;
      final outboxBefore = await _outboxCount(db);

      await _dragTo(tester, _smartZone(SmartList.today));

      final after = await _readTask(db);
      expect(after.dueAt, due, reason: '同一天还写一遍 = 把 08:00 挪成同一个瞬间的空写');
      expect(await _outboxCount(db), outboxBefore, reason: '没变化不该发同步变更');
      expect(find.text('安排到「今天」失败'), findsNothing);
    });

    testWidgets('收集箱行不是落点：没有那一格的 key，拖上去一毫秒不动', (tester) async {
      final due = _dueAt(offsetDays: 3);
      final fixture = await _pumpSeeded(tester, dueAt: due);
      expect(_smartZone(SmartList.today), findsOneWidget, reason: '落点机制整体是接上的');
      expect(
        _smartZone(SmartList.inbox),
        findsNothing,
        reason: '收集箱是清单归属，不是「关联的时间条件」',
      );

      await _dragTo(tester, find.byKey(const Key('todo-sidebar-row-inbox')));

      final after = await _readTask(fixture.database);
      expect(after.dueAt, due);
      expect(after.listId, TodoVisualFixture.inboxListId, reason: '不该顺带换清单');
    });

    testWidgets('悬停才有「安排到」读屏文案：静止没有、悬停有、落定收走', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpSeeded(tester, dueAt: _dueAt(offsetDays: 5));
      const hoverLabel = '安排到「今天」';
      final target = _smartZone(SmartList.today);

      expect(
        _hoverSemantics(hoverLabel),
        findsNothing,
        reason: '静止态给每行都挂「安排到」= 读屏噪声',
      );
      await _dragTo(
        tester,
        target,
        whileHovering: () async {
          expect(
            _hoverSemantics(hoverLabel),
            findsOneWidget,
            reason: '指针停在落点上时必须读得出这一格是干什么的',
          );
        },
      );
      expect(_hoverSemantics(hoverLabel), findsNothing, reason: '落定后候选态要收走');
      handle.dispose();
    });

    testWidgets('写失败必须在侧栏脚手架上看得见', (tester) async {
      await _pumpSeeded(
        tester,
        dueAt: _dueAt(offsetDays: 3),
        withScaffold: true,
        controller: SidebarTaskDropController(
          moveTask: (taskId, listId) async {},
          attachTag: (taskId, tagId) async {},
          scheduleToDay: (taskId, targetDay) async => throw StateError('故意写失败'),
        ),
      );

      await _dragTo(tester, _smartZone(SmartList.today));

      expect(
        find.text('安排到「今天」失败'),
        findsOneWidget,
        reason: '落点失败只写日志 = 用户以为已经安排上了，任务却还在原日',
      );
    });

    testWidgets('320px 窄侧栏 + 1.3 倍字号：拖到「最近七天」不溢出、行还在', (tester) async {
      await _pumpSeeded(
        tester,
        dueAt: _dueAt(offsetDays: 30),
        viewport: const Size(320, 720),
        sidebarWidth: 320,
        textScale: 1.3,
      );
      final target = _smartZone(SmartList.upcoming);
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await _dragTo(
        tester,
        target,
        whileHovering: () async {
          expect(tester.takeException(), isNull, reason: '溢出就是缺陷，不能被吞');
          expect(target, findsOneWidget);
        },
      );
    });
  });
}
