import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_subtask_drop.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》mobile tab `:24`
/// 「通过拖动「+」到任务下方偏右一点的位置来在这个任务下快速创建「子任务」。」
/// 外加同一页 `:28` 的清单范围限制（智能清单不可用，只可以在收集箱与自己创建的清单里用）。
///
/// 落点开的是**同一张**快速添加表（`addSubtaskFlow` → `TaskQuickAddSheet`），
/// 所以这里的判据是"拖完表开在谁下面"，不是"有没有新写一条子任务表"。
void main() {
  const rowTaskId = TodoVisualFixture.pinnedTaskId;
  const rowTitle = '确定今天最重要的三件事';

  group('移动端「+」拖到行右下（E2E）', () {
    testWidgets('拖「+」落到某行右下 ⇒ 开的是这张行的子任务表，保存后 parentTaskId 就是它', (
      tester,
    ) async {
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.mobile,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      final source = find.byKey(const Key('todo-mobile-add'));
      final target = find.byKey(Key('task-row-surface-$rowTaskId'));
      expect(source, findsOneWidget);
      expect(target, findsOneWidget);
      await tester.pumpAndSettle();
      final bandPoint = _lowerRight(tester, target);
      final start = tester.getCenter(source);

      await _dragIntent(tester, from: start, to: bandPoint);
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('todo-quick-add-title-field'));
      expect(field, findsOneWidget, reason: ':24 要的是拖完就能输入子任务，表不开等于这一拖没接住');

      await tester.enterText(field, '拖动「+」建出来的子任务');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      final created = await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('拖动「+」建出来的子任务'))).getSingle();
      expect(
        created.parentTaskId,
        rowTaskId,
        reason: '父任务必须是刚拖过去那一行；写成顶层就是没带上 parentTaskId',
      );
      expect(created.listId, TodoVisualFixture.inboxListId);
    });

    testWidgets('320px + 1.3 倍字号：拖「+」到行右下仍开表（落点是比例，不是固定像素）', (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: const Size(320, 600),
        fixtureSet: TodoVisualFixtureSet.populated,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const HomeShell(),
          ),
        ),
      );

      final source = find.byKey(const Key('todo-mobile-add'));
      final target = find.byKey(Key('task-row-surface-$rowTaskId'));
      expect(source, findsOneWidget);
      expect(target, findsOneWidget);
      await tester.pumpAndSettle();
      final bandPoint = _lowerRight(tester, target);
      await _dragIntent(tester, from: tester.getCenter(source), to: bandPoint);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('todo-quick-add-title-field')),
        findsOneWidget,
        reason: '窄屏大字号下象限按比例缩，缩到点不动就是要红的地方',
      );
    });

    testWidgets('「+」套上 Draggable 后按钮语义没丢（读屏仍报它是按钮）', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.mobile,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      // 判据用 getSemanticsData()，不是 getSemantics() 的裸 flagsCollection：
      // 后者只看节点自己的位、不合并子节点（见 timezone_preference_test.dart:189 的实测注）。
      final node = tester
          .getSemantics(find.bySemanticsIdentifier('todo_mobile_quick_add'))
          .getSemanticsData();
      expect(
        node.flagsCollection.isButton,
        isTrue,
        reason: 'Semantics(button: true) 包在 Draggable 外面，不能被拖拽层吃掉',
      );
      handle.dispose();
    });

    testWidgets('点「+」仍是原来的主快速添加：建出来的是顶层任务', (tester) async {
      final fixture = await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.mobile,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      await tester.tap(find.byKey(const Key('todo-mobile-add')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('todo-mobile-add-field'));
      expect(field, findsOneWidget, reason: '「+」套上 Draggable 不能把"点它开表"这条既有路弄断');

      await tester.enterText(field, '点击建出来的顶层任务');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final created = await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('点击建出来的顶层任务'))).getSingle();
      expect(created.parentTaskId, isNull, reason: '点与拖是两件事：点开的表没有父任务');
    });
  });

  group('落点侧闸门与几何（页级替身，同源两种拖各管各的）', () {
    testWidgets('落在左上象限：不开表（命中区仍只是右下象限）', (tester) async {
      await _pumpIntentHarness(tester);
      final target = find.byKey(Key('task-row-surface-$rowTaskId'));
      final band = _upperLeft(tester, target);

      await _dragIntent(tester, from: _intentSourceCenter, to: band);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('todo-quick-add-sheet')),
        findsNothing,
        reason: '「+」的落点必须与任务共用同一块象限，不能整行通吃',
      );
    });

    testWidgets('智能清单里没有这块落点（嘀嗒 :28 的闸门）', (tester) async {
      await _pumpIntentHarness(tester, initialListId: null);

      expect(
        find.byType(DragTarget<QuickAddSubtaskIntent>),
        findsNothing,
        reason: '闸门关掉时不该留一个"看着能落、落下去没反应"的区域',
      );

      await _dragIntent(
        tester,
        from: _intentSourceCenter,
        to: _lowerRight(tester, find.byKey(Key('task-row-surface-$rowTaskId'))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('todo-quick-add-sheet')), findsNothing);
    });

    testWidgets('只读清单没有这块落点（:28 后半句「自己创建的普通清单」）', (tester) async {
      await _pumpIntentHarness(
        tester,
        initialListId: TodoVisualFixture.workListId,
        prepare: (db) async {
          await _insertTask(
            db,
            id: 'plus-drag-second',
            listId: TodoVisualFixture.workListId,
            title: '第二项',
          );
          await (db.update(db.todoLists)
                ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
              .write(TodoListsCompanion(writable: Value(false)));
        },
      );

      expect(
        find.byType(DragTarget<QuickAddSubtaskIntent>),
        findsNothing,
        reason: '可写闸门是任务落点与「+」落点共用的那一半，不是各写一份',
      );
    });

    testWidgets('候选态读屏语义：静止没有、悬停有、落定收走', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpIntentHarness(tester);
      final zone = TaskSubtaskDropTarget.createZoneKey(rowTaskId);
      final label = TaskSubtaskDropTarget.createHoverLabel(rowTitle);

      expect(find.byKey(zone), findsNothing, reason: '静止态挂满标签＝读屏噪声');

      final source = find.byKey(const Key('intent-drag-source'));
      final target = find.byKey(Key('task-row-surface-$rowTaskId'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump();
      await gesture.moveTo(_lowerRight(tester, target));
      await tester.pump();

      expect(find.byKey(zone), findsOneWidget);
      expect(tester.getSemantics(find.byKey(zone)).label, contains(label));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(zone), findsNothing, reason: '落定后候选态要收走');
      handle.dispose();
    });

    testWidgets('建表入口抛错时提示看得见（走 describeError，不吞）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Draggable<QuickAddSubtaskIntent>(
                    key: const Key('component-drag-source'),
                    data: const QuickAddSubtaskIntent(),
                    feedback: const SizedBox(
                      width: 24,
                      height: 24,
                      child: ColoredBox(color: Colors.black26),
                    ),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 200,
                  child: SizedBox(
                    width: 600,
                    height: 60,
                    child: TaskSubtaskDropTarget(
                      task: _bareTask(id: 'row', listId: 'inbox'),
                      enabled: true,
                      onDrop: (_) async {},
                      onCreateParent: (_) async =>
                          throw StateError('已达最大嵌套层数（5），无法继续添加子任务'),
                      child: const ColoredBox(
                        color: Colors.grey,
                        child: SizedBox(width: 600, height: 60),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump();
      await gesture.moveTo(const Offset(450, 245));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(
        find.textContaining('已达最大嵌套层数（5），无法继续添加子任务'),
        findsOneWidget,
        reason: '守卫/入口抛的消息要原样上屏（describeError 之后仍是这句中文）',
      );
    });
  });
}

const Offset _intentSourceCenter = Offset(20, 20);

Offset _lowerRight(WidgetTester tester, Finder row) {
  expect(row, findsOneWidget);
  final size = tester.getSize(row);
  return tester.getTopLeft(row) + Offset(size.width * 0.75, size.height * 0.75);
}

Offset _upperLeft(WidgetTester tester, Finder row) {
  expect(row, findsOneWidget);
  final size = tester.getSize(row);
  return tester.getTopLeft(row) + Offset(size.width * 0.25, size.height * 0.25);
}

/// `Draggable`（非长按）要先有一次位移才进拖拽，之后再报落点。
Future<void> _dragIntent(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final gesture = await tester.startGesture(from);
  await tester.pump();
  await gesture.moveTo(from + const Offset(6, 30));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

TodoTask _bareTask({required String id, required String listId}) {
  final stamp = DateTime.utc(2026, 7, 11, 9);
  return TodoTask(
    id: id,
    serverId: null,
    listId: listId,
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    title: id,
    completed: false,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: null,
    updatedAt: stamp,
    createdAt: stamp,
  );
}

Future<void> _insertTask(
  AppDatabase db, {
  required String id,
  required String listId,
  required String title,
}) async {
  final stamp = DateTime.utc(2026, 7, 11, 9);
  await db
      .into(db.todoTasks)
      .insert(
        TodoTasksCompanion.insert(
          id: id,
          listId: listId,
          title: title,
          updatedAt: stamp,
          createdAt: stamp,
        ),
      );
}

/// 把清单页与一个「+」拖出源叠在同一棵树里：源在左上角，落点是清单行自身的右下象限。
/// 真实源是 `MobileQuickAddButton`（E2E 那组用它在 HomeShell 上量），这里量的是落点侧的
/// 闸门、象限与语义，不重复跑一遍整只 App。
Future<TodoVisualFixture> _pumpIntentHarness(
  WidgetTester tester, {
  String? initialListId = TodoVisualFixture.inboxListId,
  Future<void> Function(AppDatabase database)? prepare,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
  );
  addTearDown(fixture.dispose);
  if (prepare != null) await prepare(fixture.database);
  tester.view.physicalSize = TodoVisualViewports.wide;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Stack(
          children: [
            Positioned.fill(
              child: Scaffold(
                body: TasksByListPage(
                  initialListId: initialListId,
                  lockedListId: true,
                  hideAppBar: true,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Draggable<QuickAddSubtaskIntent>(
                key: const Key('intent-drag-source'),
                data: const QuickAddSubtaskIntent(),
                feedback: const SizedBox(
                  width: 24,
                  height: 24,
                  child: ColoredBox(color: Colors.black26),
                ),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return fixture;
}
