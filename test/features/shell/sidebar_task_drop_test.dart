import 'dart:async';

// 只借 Value：整包导入会让 isNull / isNotNull 与 matcher 撞名。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/todo_layout_tokens.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar_task_drop.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》:57「拖动到清单或标签上」
/// `:59`「任务会被移动到目标清单，或自动打上相应标签。」
///
/// 落点是侧栏清单行 / 标签行。拖出源用普通 `Draggable<TodoTask>` 作替身：
/// 落点侧只认载荷类型，不认拖出实现（真拖出源见看板、时间线与并列视图的清单行）。
const _dragSourceLabel = '拖这块';
const _wide = Size(1280, 900);

/// 夹具里 `metadataTaskId` 自带的标签（`sidebar_test` 同源），A1/A2 的追加语义以此为前提。
const _personalListName = '生活';

Finder _listZone(String listId) =>
    find.byKey(ValueKey('todo-sidebar-drop-list-$listId'));

/// 只认「这个落点自己带的那条读屏文案」，不靠全树文案匹配 ——
/// 侧栏行本身有 button/文本语义，`bySemanticsLabel` 会被那层合并吃掉（实测 0 命中）。
Finder _hoverSemantics(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Finder _tagZone(String tagId) =>
    find.byKey(ValueKey('todo-sidebar-drop-tag-$tagId'));

Future<TodoTask> _readTask(AppDatabase db, String taskId) =>
    (db.select(db.todoTasks)..where((t) => t.id.equals(taskId))).getSingle();

Future<int> _outboxCount(AppDatabase db) async =>
    (await db.select(db.todoSyncChanges).get()).length;

Future<List<String>> _readTagIds(AppDatabase db, String taskId) async {
  final rows = await (db.select(
    db.todoTaskTags,
  )..where((t) => t.taskId.equals(taskId))).get();
  return rows.map((r) => r.tagId).toList()..sort();
}

/// 落点只用到载荷的 `id` 与 `listId`（前者写库、后者判「换没换清单」），
/// 所以替身载荷按夹具的真实值构造即可，不必把整行抄一遍。
TodoTask _payload({required String id, required String listId}) => TodoTask(
  id: id,
  serverId: null,
  listId: listId,
  allDay: false,
  fixedTimezone: false,
  title: '拖拽载荷',
  completed: false,
  cancelled: false,
  priority: 0,
  isPinned: false,
  sortOrder: 0,
  dueAt: DateTime(2026, 6, 20, 9),
  updatedAt: DateTime(2026, 6, 20, 8),
  createdAt: DateTime(2026, 6, 20, 8),
);

Future<TodoVisualFixture> _pumpShell(
  WidgetTester tester, {
  required TodoTask task,
  Size viewport = _wide,
  double? sidebarWidth,
  double textScale = 1,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: Material(
      child: Column(
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
      ),
    ),
  );
}

/// 起拖 → 悬停 → 落下；悬停与落定之间的读屏断言由调用方插在 `hoverStep` 里。
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

class _PlainSidebar extends StatelessWidget {
  const _PlainSidebar();

  @override
  Widget build(BuildContext context) => Sidebar(
    selectedSection: Section.tasks,
    selectedSmart: SmartList.inbox,
    selectedListId: null,
    onSelectSection: (_) {},
    onSelectSmart: (_) {},
    onSelectList: (_) {},
    onOpenTags: () {},
    onOpenFilters: () {},
    onOpenSettings: () {},
  );
}

void main() {
  group('侧栏落点：真库、真侧栏、真手势', () {
    testWidgets('拖到别的清单行 ⇒ 换清单、清掉属于原清单的分组、时间安排一毫秒不动', (tester) async {
      final fixture = await _pumpShell(
        tester,
        task: _payload(
          id: TodoVisualFixture.metadataTaskId,
          listId: TodoVisualFixture.inboxListId,
        ),
      );
      final db = fixture.database;
      // 先把「原清单的分组」造出来：不写 sectionId，「清掉分组」这条就无从证伪。
      await (db.update(db.todoTasks)
            ..where((t) => t.id.equals(TodoVisualFixture.metadataTaskId)))
          .write(const TodoTasksCompanion(sectionId: Value('sec-of-inbox')));
      final before = await _readTask(db, TodoVisualFixture.metadataTaskId);
      expect(before.sectionId, 'sec-of-inbox', reason: '种子没写进去，后面全是空断言');
      expect(before.listId, TodoVisualFixture.inboxListId);

      await _dragTo(tester, _listZone(TodoVisualFixture.personalListId));

      final after = await _readTask(db, before.id);
      expect(
        after.listId,
        TodoVisualFixture.personalListId,
        reason: ':59 要的是移动到目标清单',
      );
      expect(after.sectionId, isNull, reason: '分组属于原清单，换清单后不该留着');
      expect(after.dueAt, before.dueAt, reason: '原文只提清单，截止时间不该动');
      expect(after.startAt, before.startAt, reason: '原文只提清单，开始时间不该动');
      expect(after.endAt, before.endAt, reason: '原文只提清单，结束时间不该动');
    });

    testWidgets('拖到标签行 ⇒ 自动打上该标签，且原有标签一个不丢', (tester) async {
      final fixture = await _pumpShell(
        tester,
        task: _payload(
          id: TodoVisualFixture.metadataTaskId,
          listId: TodoVisualFixture.inboxListId,
        ),
      );
      final db = fixture.database;
      expect(
        await _readTagIds(db, TodoVisualFixture.metadataTaskId),
        contains(TodoVisualFixture.focusTagId),
        reason: '夹具里这条任务自带「专注」，追加语义以此为前提',
      );

      await tester.scrollUntilVisible(
        _tagZone(TodoVisualFixture.reviewTagId),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _dragTo(tester, _tagZone(TodoVisualFixture.reviewTagId));

      expect(
        await _readTagIds(db, TodoVisualFixture.metadataTaskId),
        containsAll([
          TodoVisualFixture.focusTagId,
          TodoVisualFixture.reviewTagId,
        ]),
        reason: ':59「自动打上相应标签」= 追加，不是覆盖',
      );
    });

    testWidgets('拖到它已有的那个标签上 ⇒ 标签集合不变，也不多登记一次同步变更', (tester) async {
      final fixture = await _pumpShell(
        tester,
        task: _payload(
          id: TodoVisualFixture.metadataTaskId,
          listId: TodoVisualFixture.inboxListId,
        ),
      );
      final db = fixture.database;
      final tagsBefore = await _readTagIds(
        db,
        TodoVisualFixture.metadataTaskId,
      );
      final outboxBefore = await _outboxCount(db);

      await tester.scrollUntilVisible(
        _tagZone(TodoVisualFixture.focusTagId),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _dragTo(tester, _tagZone(TodoVisualFixture.focusTagId));

      expect(
        await _readTagIds(db, TodoVisualFixture.metadataTaskId),
        tagsBefore,
      );
      expect(
        await _outboxCount(db),
        outboxBefore,
        reason: '已有该标签还去写一遍 = 白发一次同步变更（去重必须挡在写之前）',
      );
      expect(find.text('打上「专注」失败'), findsNothing, reason: '去重不是失败，不该弹提示');
    });

    testWidgets('候选态才有「移入清单」读屏文案：静止没有、悬停有、落定收走', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(
        tester,
        task: _payload(
          id: TodoVisualFixture.metadataTaskId,
          listId: TodoVisualFixture.inboxListId,
        ),
      );
      final hoverLabel = '移入清单「$_personalListName」';
      final target = _listZone(TodoVisualFixture.personalListId);

      expect(
        _hoverSemantics(hoverLabel),
        findsNothing,
        reason: '静止态给每行都挂「移入」= 读屏噪声',
      );
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_personalListName), findsOneWidget, reason: '行名本身还得读得到');

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

    testWidgets('320px 窄侧栏 + 1.3 倍字号：悬停边框不把行挤出可视区', (tester) async {
      await _pumpShell(
        tester,
        task: _payload(
          id: TodoVisualFixture.metadataTaskId,
          listId: TodoVisualFixture.inboxListId,
        ),
        viewport: const Size(320, 720),
        sidebarWidth: 320,
        textScale: 1.3,
      );
      final target = _listZone(TodoVisualFixture.personalListId);
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

  testWidgets('写失败必须在侧栏所在脚手架上看得见（提示不被吞）', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: _wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (database) => [
        sidebarTaskDropControllerProvider.overrideWithValue(
          SidebarTaskDropController(
            moveTask: (taskId, listId) async => throw StateError('故意写失败'),
            attachTag: (taskId, tagId) async {},
          ),
        ),
      ],
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 48,
              child: Center(
                child: Draggable<TodoTask>(
                  data: _payload(
                    id: TodoVisualFixture.metadataTaskId,
                    listId: TodoVisualFixture.inboxListId,
                  ),
                  feedback: const Material(child: Text('拖拽载荷')),
                  child: const Text(_dragSourceLabel),
                ),
              ),
            ),
            const Expanded(child: _PlainSidebar()),
          ],
        ),
      ),
    );
    await _dragTo(tester, _listZone(TodoVisualFixture.personalListId));

    expect(
      find.text('移到「$_personalListName」失败'),
      findsOneWidget,
      reason: '落点失败只写日志 = 用户以为已经移过去了，任务却还在原清单',
    );
  });

  group('编排接缝：不发写请求 / 串行 / 失败后链条不断', () {
    test('落回自己所在的清单 ⇒ skipped，一次写都不发', () async {
      final calls = <String>[];
      final controller = SidebarTaskDropController(
        moveTask: (taskId, listId) async => calls.add('$taskId->$listId'),
        attachTag: (taskId, tagId) async {},
      );

      final outcome = await controller.moveToList(
        _payload(id: 't1', listId: 'L1'),
        'L1',
      );

      expect(outcome, SidebarDropOutcome.skipped);
      expect(calls, isEmpty, reason: ':59 的「移动到目标清单」不含原地不动这种写');
    });

    test('同一任务连落两刀 ⇒ 第二刀必须等第一刀写完，不能插队', () async {
      final order = <String>[];
      final gate = Completer<void>();
      final controller = SidebarTaskDropController(
        moveTask: (taskId, listId) async {
          order.add('start:$listId');
          await gate.future;
          order.add('end:$listId');
        },
        attachTag: (taskId, tagId) async {},
      );

      final first = controller.moveToList(
        _payload(id: 't2', listId: 'L1'),
        'L2',
      );
      // 让第一刀真的进到 moveTask 里（微任务排空），再落第二刀。
      await Future<void>.delayed(Duration.zero);
      expect(order, ['start:L2'], reason: '第一刀没进去，串行就是假的');
      final second = controller.moveToList(
        _payload(id: 't2', listId: 'L1'),
        'L3',
      );
      expect(order, ['start:L2'], reason: '第二刀插到第一刀前面了');

      gate.complete();
      await first;
      await second;

      expect(order, ['start:L2', 'end:L2', 'start:L3', 'end:L3']);
    });

    test('第一刀写失败 ⇒ 报 failed，第二刀照样执行（链条没被旧错误吃掉）', () async {
      final order = <String>[];
      final controller = SidebarTaskDropController(
        moveTask: (taskId, listId) async {
          order.add(listId);
          if (listId == 'BAD') throw StateError('仓储未就绪');
        },
        attachTag: (taskId, tagId) async {},
      );

      final first = await controller.moveToList(
        _payload(id: 't3', listId: 'L1'),
        'BAD',
      );
      final second = await controller.moveToList(
        _payload(id: 't3', listId: 'L1'),
        'L2',
      );

      expect(first, SidebarDropOutcome.failed);
      expect(second, SidebarDropOutcome.applied);
      expect(order, ['BAD', 'L2'], reason: '失败后链条必须续上，不是把后续写静默吞掉');
    });
  });
}
