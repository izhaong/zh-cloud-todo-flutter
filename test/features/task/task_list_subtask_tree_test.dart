import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_subtask_drop.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》
/// - `:72`「## 展开子任务」（小节标题行）
/// - desktop tab `:78`「在任务列表中，可以点击主任务**右侧**的箭头图标来展开或者收起任务下的所有子任务。」
/// - mobile tab `:86`「在任务列表中，可以点击主任务**左侧**的箭头图标来展开或者收起任务下的所有子任务。」
/// - `:31`/`:65`「每一个层级的子任务在功能上都与普通任务相同……」
///
/// 之前清单页只喂顶层任务，于是 FL #590/#595 把一行拖成子任务之后，那一行直接从列表消失
/// （用户会以为任务被删了），`:31` 那句在清单页也看不见。本面把子任务铺成行，
/// 并按原文给一颗展开/收起的箭头。默认收起：原文那一节标题就叫「展开子任务」、
/// 写的是"点击箭头来展开"，收起态是这一面的默认呈现（裁定与理由见 specs/116 台账）。
void main() {
  const parentId = TodoVisualFixture.metadataTaskId;
  const firstChildId = 'visual-task-metadata-child-1';
  const secondChildId = 'visual-task-metadata-child-2';
  const topLevelId = TodoVisualFixture.pinnedTaskId;

  testWidgets('默认收起：父行有箭头，子任务不进可见序列', (tester) async {
    await _pumpList(tester);

    expect(
      find.byKey(Key('task-row-surface-$parentId')),
      findsOneWidget,
      reason: '前置条件：父任务在列表里',
    );
    expect(
      find.byKey(Key('todo-task-expand-toggle-$parentId')),
      findsOneWidget,
      reason: '有子级就必须给箭头：收起态没有入口，":78" 那句就落不了地',
    );
    expect(
      find.byKey(Key('task-row-surface-$secondChildId')),
      findsNothing,
      reason: '默认收起 ⇒ 子行不在序列里（不是"渲染了但看不见"）',
    );
  });

  testWidgets('点箭头展开：子行紧跟在父之后、下一个顶层行之前；再点收起', (tester) async {
    await _pumpList(tester);
    final caret = find.byKey(Key('todo-task-expand-toggle-$parentId'));

    await tester.tap(caret);
    await tester.pumpAndSettle();

    expect(find.byKey(Key('task-row-surface-$secondChildId')), findsOneWidget);
    expect(find.text('补充风险与依赖'), findsOneWidget, reason: '行就是那一套行组件，不是第二套摘要');
    final parentTop = tester
        .getTopLeft(find.byKey(Key('task-row-surface-$parentId')))
        .dy;
    final childTop = tester
        .getTopLeft(find.byKey(Key('task-row-surface-$secondChildId')))
        .dy;
    expect(
      childTop,
      greaterThan(parentTop),
      reason: '子任务在父任务下面，不是跑到父任务上面（紧贴的顺序由下一条用例断）',
    );

    await tester.tap(caret);
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('task-row-surface-$secondChildId')),
      findsNothing,
      reason: '原文是"展开或者收起"两面，收起必须真把子行撤掉',
    );
  });

  testWidgets('子行紧贴其父：把它插进父与其后的行之间，而不是按 dueAt 落到别的组', (tester) async {
    await _pumpList(tester);
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();

    // metadata 的两个子级 must 都排在 metadata 之后，且彼此相邻（中间不夹别的顶层行）。
    final rows = _renderedRowIds(tester);
    final parentIndex = rows.indexOf(parentId);
    final firstChildIndex = rows.indexOf(firstChildId);
    final secondChildIndex = rows.indexOf(secondChildId);
    expect(parentIndex, greaterThanOrEqualTo(0), reason: '父行在序列里');
    expect(firstChildIndex, greaterThan(parentIndex), reason: '第一个子行在父之后');
    expect(secondChildIndex, greaterThan(parentIndex), reason: '第二个子行也在父之后');
    expect(
      secondChildIndex - firstChildIndex,
      1,
      reason: '子行彼此相邻，中间不夹别的顶层行（按自己的 dueAt 分组的写法会把树拆散）',
    );
  });

  testWidgets('箭头位置按原文分端：桌面在行的右半边、移动在左半边', (tester) async {
    // desktop：原文 :78「主任务右侧的箭头」。
    await _pumpList(tester, viewport: TodoVisualViewports.wide);
    var caret = find.byKey(Key('todo-task-expand-toggle-$parentId'));
    expect(caret, findsOneWidget);
    var rowRect = tester.getRect(find.byKey(Key('task-row-surface-$parentId')));
    expect(
      tester.getCenter(caret).dx,
      greaterThan(rowRect.left + rowRect.width * 0.5),
      reason: 'desktop tab 写的是右侧',
    );

    // mobile：原文 :86「主任务左侧的箭头」——同一颗箭头在另一头。
    await _pumpList(tester, viewport: TodoVisualViewports.mobile);
    caret = find.byKey(Key('todo-task-expand-toggle-$parentId'));
    expect(caret, findsOneWidget);
    rowRect = tester.getRect(find.byKey(Key('task-row-surface-$parentId')));
    expect(
      tester.getCenter(caret).dx,
      lessThan(rowRect.left + rowRect.width * 0.5),
      reason: 'mobile tab 写的是左侧；两端共用一个位置就不算分别落地',
    );
  });

  testWidgets('没有子级的行不给箭头（不挂一个按了没反应的图标）', (tester) async {
    await _pumpList(tester);
    expect(
      find.byKey(Key('todo-task-expand-toggle-$topLevelId')),
      findsNothing,
      reason: 'pinned 那条没有子级',
    );
  });

  testWidgets('子行可用：点开它选中它、勾它的勾选框（「与普通任务相同」那一句）', (tester) async {
    final tapped = <String>[];
    final fixture = await _pumpList(tester, onTaskSelected: tapped.add);
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('task-row-surface-$secondChildId')));
    await tester.pumpAndSettle();
    expect(tapped, contains(secondChildId));

    final before = await _taskRow(fixture.database, secondChildId);
    expect(before.completed, isFalse, reason: '前置条件：种子是未完成');

    // 「与普通任务相同」里最硬的一件：勾它的勾选框，库里真变完成态。
    await tester.tap(
      find.descendant(
        of: find.byKey(Key('task-row-surface-$secondChildId')),
        matching: find.byType(AppCheckbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (await _taskRow(fixture.database, secondChildId)).completed,
      isTrue,
      reason: ':31「每一个层级的子任务在功能上都与普通任务相同」——勾选框是功能之一',
    );
  });

  testWidgets('展开后放置仍只在同一父级的兄弟之间：跨父那一刀根本不是落点', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();

    // 子行拖到另一个顶层行（pinned）的上半格 ⇒ 那一格不该亮、也不该提交。
    final source = find.byKey(Key('task-row-surface-$secondChildId'));
    final target = find.byKey(Key('task-row-surface-$topLevelId'));
    final startPoint = tester.getCenter(source);
    final to = _bandCenter(tester, target, _Band.top);
    final gesture = await tester.startGesture(startPoint);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(to);
    await tester.pump();
    expect(
      find.byKey(TaskSubtaskDropTarget.beforeZoneKey(topLevelId)),
      findsNothing,
      reason:
          '跨父的插入位在那棵树里没有对应位置：收下这一刀只会写出一个"归堆后被弹回原处"的顺序，'
          '也就是"看着能落、落下去没反应"',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.requests, isEmpty);
  });

  testWidgets('同父兄弟之间放置照旧有效（闸门别把该放的也拦了）', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();

    await _dragBand(
      tester,
      sourceId: secondChildId,
      targetId: firstChildId,
      band: _Band.top,
    );

    expect(repository.requests, hasLength(1), reason: '同一父级下的兄弟就该能排序');
    final submitted = repository.requests.single;
    expect(
      submitted.indexOf(secondChildId),
      lessThan(submitted.indexOf(firstChildId)),
      reason: '拖到兄弟的上半格＝排到它之前',
    );
  });

  testWidgets('拖到"已展开的父"的左下：提交紧跟其父，渲染落在整段子树之后', (tester) async {
    // 交叉验证点名的那件差事：扁平下标把 pinned 放在 metadata 与它的孩子中间，
    // 而渲染是按父归堆的 ⇒ 必须看得见"它落在整段子树之后"，不能看着不动。
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();
    expect(
      (await _taskRow(fixture.database, topLevelId)).parentTaskId,
      isNull,
      reason: '前置条件：pinned 与 metadata 同为顶层（同一父级 null）的兄弟，这一刀才该成立',
    );

    await _dragBand(
      tester,
      sourceId: topLevelId,
      targetId: parentId,
      band: _Band.lowerLeft,
    );

    expect(repository.requests, hasLength(1), reason: '同父兄弟的左下格就是落点');
    final submitted = repository.requests.single;
    expect(
      submitted.indexOf(topLevelId),
      submitted.indexOf(parentId) + 1,
      reason: '提交出去的扁平顺序是"紧跟 metadata 之后"：这就是"排到该行之后"的下标语义',
    );

    // 渲染按父归堆，于是那一刀不会把子树从父身边撬开 —— 断的是可见顺序里
    // metadata 与它的两个孩子仍然连续（把 pinned 塞进父子之间就是没做到这一点）。
    final rows = _renderedRowIds(tester);
    expect(
      rows.indexOf(topLevelId) < rows.indexOf(parentId),
      isTrue,
      reason: '前置条件：置顶组在上面，pinned 原本就在 metadata 之前（这一刀是往后放）',
    );
    expect(
      rows.indexOf(firstChildId) - rows.indexOf(parentId),
      1,
      reason: '子行必须紧贴其父：中间不许插进别的顶层行',
    );
    expect(
      rows.indexOf(secondChildId) - rows.indexOf(firstChildId),
      1,
      reason: '整段子树连续',
    );
    expect(
      (await _taskRow(fixture.database, topLevelId)).parentTaskId,
      isNull,
      reason: '放置只改顺序，不许顺手改父子关系',
    );
  });

  testWidgets('三层树：展开父再展开子，孙级出现且缩进更深', (tester) async {
    await _pumpList(
      tester,
      prepare: (db) async {
        await _insertChild(
          db,
          id: 'tree-grandchild',
          title: '第三层',
          parentTaskId: secondChildId,
        );
      },
    );
    // 行的表面铺满整宽，量它量不出缩进 —— 要量行内最前那一块（勾选框）。
    double leadingOf(String taskId) => tester
        .getTopLeft(
          find.descendant(
            of: find.byKey(Key('task-row-surface-$taskId')),
            matching: find.byType(AppCheckbox),
          ),
        )
        .dx;

    final baseIndent = leadingOf(parentId);
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('task-row-surface-$secondChildId')), findsOneWidget);
    expect(
      leadingOf(secondChildId),
      greaterThan(baseIndent),
      reason: '第二层要缩进：不缩就分不出这行是谁家的',
    );

    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$secondChildId')));
    await tester.pumpAndSettle();
    expect(
      leadingOf('tree-grandchild'),
      greaterThan(leadingOf(secondChildId)),
      reason: '第三层再缩一档（:33「最多支持五个不同层级」在清单页也得看得出层级）',
    );
  });

  testWidgets('只读清单里箭头照旧可用：展开只是本地 UI，不写库', (tester) async {
    final fixture = await _pumpList(
      tester,
      initialListId: TodoVisualFixture.inboxListId,
      prepare: (db) async {
        await (db.update(db.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.inboxListId)))
            .write(TodoListsCompanion(writable: Value(false)));
      },
    );
    final caret = find.byKey(Key('todo-task-expand-toggle-$parentId'));
    expect(caret, findsOneWidget, reason: '展开不写库 ⇒ 只读清单没有理由不给入口');

    await tester.tap(caret);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('task-row-surface-$secondChildId')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: '一次展开不该弹"只读"错误');
    expect(
      (await _taskRow(fixture.database, secondChildId)).parentTaskId,
      parentId,
      reason: '前置条件复核：这一刀真没写库',
    );
  });

  testWidgets('展开态下跨父转子任务仍走右下带：子行拖到别的父的右下 ⇒ 写 parentTaskId', (tester) async {
    final fixture = await _pumpList(tester);
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();
    expect(
      (await _taskRow(fixture.database, secondChildId)).parentTaskId,
      parentId,
    );

    // 目标：pinned 那条顶层行没有子级 ⇒ 拿 metadata 当父，这里改用它的兄弟行做落点。
    await _dragBand(
      tester,
      sourceId: secondChildId,
      targetId: TodoVisualFixture.todayTaskId,
      band: _Band.lowerRight,
    );

    expect(
      (await _taskRow(fixture.database, secondChildId)).parentTaskId,
      TodoVisualFixture.todayTaskId,
      reason: '《06-多级任务.md》:20/:49 那一格：换父是右下带的活，与"同父才能放置"不冲突',
    );
  });

  testWidgets('智能清单也有这棵树（数据源不是只有具体清单那一条流）', (tester) async {
    await _pumpList(tester, initialListId: null);
    expect(
      find.byKey(Key('todo-task-expand-toggle-$parentId')),
      findsOneWidget,
      reason: '智能清单的数据源走 watchAll／watchAllSubtasks：树不能只在具体清单里成立',
    );
    await tester.tap(find.byKey(Key('todo-task-expand-toggle-$parentId')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('task-row-surface-$secondChildId')),
      findsOneWidget,
      reason: '嘀嗒 :31 那句没写"仅限普通清单"，只有 :28 那句限制了"拖动转子任务"这一手势',
    );
  });

  testWidgets('子行只挂在渲染出来的父行下面：父不在序列里，子绝不自己冒出来', (tester) async {
    // 父被筛掉、父在别的清单、父已删除……机制上是同一件事：父行不在可见序列里。
    // 这里用最直接的一种造出来——挂一个"父不在这张清单的行序列里"的子级，
    // 于是这一条断的是**结构**（子行由父行带出来），而不是某个筛选面板的 UI。
    await _pumpList(
      tester,
      prepare: (db) async {
        await _insertChild(
          db,
          id: 'tree-orphan-child',
          title: '父不在本视图的子任务',
          parentTaskId: 'tree-missing-parent',
        );
      },
    );
    expect(
      find.byKey(Key('task-row-surface-tree-missing-parent')),
      findsNothing,
      reason: '前置条件：这个父确实不在序列里',
    );
    expect(
      find.byKey(Key('task-row-surface-tree-orphan-child')),
      findsNothing,
      reason: '父不在，子不该自己冒到顶层去',
    );
  });
}

enum _Band { top, lowerLeft, lowerRight }

class _RecordingTaskViewActionRepository extends TaskViewActionRepository {
  _RecordingTaskViewActionRepository(AppDatabase db)
    : super(db, SyncChangeQueue(db));

  final List<List<String>> requests = [];

  @override
  Future<void> reorderListTasks(List<String> taskIds) async {
    requests.add(List<String>.of(taskIds));
    await super.reorderListTasks(taskIds);
  }
}

List<Override> Function(AppDatabase) _recording(
  void Function(_RecordingTaskViewActionRepository) capture,
) {
  return (db) {
    final repository = _RecordingTaskViewActionRepository(db);
    capture(repository);
    return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
  };
}

/// 可见序列里的行 id（按渲染顺序）。用行的表面 key 顺序量，不看内部数据结构：
/// 断"子行紧贴其父"要断的就是界面实际给了什么顺序。
List<String> _renderedRowIds(WidgetTester tester) {
  // 行的表面 key 就是这个顺序本身；`widgetList` 按树的先序给，正合"渲染出来的顺序"。
  final prefix = 'task-row-surface-';
  return tester
      .widgetList<AnimatedContainer>(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(prefix),
        ),
      )
      .map(
        (widget) =>
            (widget.key! as ValueKey<String>).value.substring(prefix.length),
      )
      .toList(growable: false);
}

Future<TodoTask> _taskRow(AppDatabase db, String taskId) =>
    (db.select(db.todoTasks)..where((r) => r.id.equals(taskId))).getSingle();

Future<void> _insertChild(
  AppDatabase db, {
  required String id,
  required String title,
  required String parentTaskId,
}) async {
  final stamp = DateTime.utc(2026, 7, 11, 9);
  await db
      .into(db.todoTasks)
      .insert(
        TodoTasksCompanion.insert(
          id: id,
          listId: TodoVisualFixture.inboxListId,
          title: title,
          parentTaskId: Value(parentTaskId),
          updatedAt: stamp,
          createdAt: stamp,
        ),
      );
}

Future<TodoVisualFixture> _pumpList(
  WidgetTester tester, {
  String? initialListId = TodoVisualFixture.inboxListId,
  Size viewport = TodoVisualViewports.wide,
  List<Override> Function(AppDatabase database)? overridesBuilder,
  void Function(String taskId)? onTaskSelected,
  Future<void> Function(AppDatabase database)? prepare,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);
  if (prepare != null) await prepare(fixture.database);

  tester.view.physicalSize = viewport;
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
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: Scaffold(
            body: TasksByListPage(
              initialListId: initialListId,
              lockedListId: true,
              hideAppBar: true,
              onTaskSelected: onTaskSelected,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
  return fixture;
}

Offset _bandCenter(WidgetTester tester, Finder row, _Band band) {
  expect(row, findsOneWidget);
  final size = tester.getSize(row);
  final topLeft = tester.getTopLeft(row);
  return switch (band) {
    _Band.top => topLeft + Offset(size.width * 0.5, size.height * 0.25),
    _Band.lowerLeft => topLeft + Offset(size.width * 0.25, size.height * 0.75),
    _Band.lowerRight => topLeft + Offset(size.width * 0.75, size.height * 0.75),
  };
}

/// 长按源行并落到目标行的某一格（`LongPressDraggable` 那 300ms 的 delay 要真过）。
/// 两行都必须在起手势之前就已经在视口里：只滚一边会把另一边回收（本轮实测过）。
Future<void> _dragBand(
  WidgetTester tester, {
  required String sourceId,
  required String targetId,
  required _Band band,
}) async {
  final source = find.byKey(Key('task-row-surface-$sourceId'));
  final target = find.byKey(Key('task-row-surface-$targetId'));
  await tester.pumpAndSettle();
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  final startPoint = tester.getCenter(source);
  final to = _bandCenter(tester, target, band);

  final gesture = await tester.startGesture(startPoint);
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}
