import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/list_drop_target.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_subtask_drop.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》desktop tab
/// `:60-:61`「按住任务前的图标拖动到另一个任务**右下方**即可快速转化为子任务」，
/// 以及 `:28`「这一功能在「今天」、「最近七天」等智能清单中不可用，
/// 只可以在「收集箱」以及自己创建的普通清单中可用」。
///
/// 这里全部走真实页面 + 真实仓储（`taskRepositoryProvider` 默认没被替换），
/// 所以"写库"量的是 `TaskRepository.reparent` 那条带守卫的通道本身，不是替身；
/// 只有"守卫抛错要看得见"那一条用替身（新入口够不到真成环，理由见 specs 台账）。
void main() {
  const draggedId = TodoVisualFixture.pinnedTaskId;
  const parentId = TodoVisualFixture.todayTaskId;
  const parentTitle = '完成 Todo 工作区视觉评审';

  testWidgets('拖到另一行的右下象限：该任务真的成为它的子任务并入队同步', (tester) async {
    final fixture = await _pumpList(tester);

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      parentId,
      reason: '右下象限命中必须写进 parentTaskId，否则落点只是画了个高亮',
    );
    expect(
      await _queuedChangeCount(fixture.database, localId: draggedId),
      greaterThan(0),
      reason: '离线写的第二条腿：不入队就同步不出去',
    );
  });

  testWidgets('同一次拖、落在左上象限：不建立父子关系（命中区不是整行）', (tester) async {
    final fixture = await _pumpList(tester);

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.upperLeft,
    );

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      isNull,
      reason: '同一对手势只换落点就该换结果；命中区扩成整行这条要红',
    );
    expect(await _queuedChangeCount(fixture.database, localId: draggedId), 0);
  });

  testWidgets('自己拖到自己：连 reparent 都不该被调到（落点自己就拒）', (tester) async {
    late final _RecordingTaskRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskRepository(db);
        return [taskRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: draggedId,
      band: _Band.lowerRight,
    );

    expect(
      repository.reparentCalls,
      isEmpty,
      reason:
          '只断"结果没变"量不到是谁拒的：仓储的自引用守卫也会让结果没变，'
          '这条要钉住落点自己先拒（否则每次自拖都会白打一次库再弹错）',
    );
    expect(await _parentTaskIdOf(fixture.database, draggedId), isNull);
  });

  testWidgets('落点走 reparent 那条带守卫的通道，入参是（拖动项, 目标父）', (tester) async {
    late final _RecordingTaskRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskRepository(db);
        return [taskRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      repository.reparentCalls,
      <List<String?>>[
        <String?>[draggedId, parentId],
      ],
      reason: '#590 施工图第 4 条：不许另开一条只改 parentTaskId 的裸 update 绕过防成环',
    );
  });

  testWidgets('仓储拒绝时必须看得见它的原话（不改写成"操作失败"、不吞）', (tester) async {
    late final _RecordingTaskRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskRepository(
          db,
          failure: StateError('任务父子关系形成循环'),
        );
        return [taskRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      find.textContaining('任务父子关系形成循环'),
      findsOneWidget,
      reason:
          '守卫消息原样上屏；仓储侧真成环的断言见 '
          'test/task_organize_search_repository_test.dart:826',
    );
    expect(repository.reparentCalls, hasLength(1));
  });

  testWidgets('右下象限落点不会顺带触发清单排序写入', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      parentId,
      reason: '前置条件：这一刀确实命中了',
    );
    expect(repository.requests, isEmpty, reason: '右下带不该被排序那条通道同时吃掉');
  });

  testWidgets('排序照旧可用：行首手柄那一刀不受落点新增影响', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragHandleToBelow(
      tester,
      sourceId: TodoVisualFixture.pinnedTaskId,
      targetId: TodoVisualFixture.todayTaskId,
    );

    expect(
      repository.requests,
      hasLength(1),
      reason: '本轮在每个行外面套了一层 Stack，不能把既有排序弄坏',
    );
  });

  testWidgets('长按落在行最前的图标/勾选区也起拖：嘀嗒 desktop「按住任务前的图标」这条要能量到', (tester) async {
    final fixture = await _pumpList(tester);

    // 起点不是行中心，而是行首 14px 那一竖条（勾选框/图标所在的区域）。
    final source = find.byKey(Key('task-row-surface-$draggedId'));
    final target = find.byKey(Key('task-row-surface-$parentId'));
    expect(source, findsOneWidget);
    expect(target, findsOneWidget);
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final sourceRect = tester.getRect(source);
    final grabAt = Offset(sourceRect.left + 14, sourceRect.center.dy);
    final bandPoint = _bandCenter(tester, target, _Band.lowerRight);

    final gesture = await tester.startGesture(grabAt);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(bandPoint);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      parentId,
      reason:
          'desktop :61 写的是「按住任务前的图标拖动到另一个任务右下方」；'
          '整行长按要覆盖得住行首那一条，否则这句就不算落地',
    );
  });

  testWidgets('两个入口并存：长按拖出源在、hover 出的排序手柄也在', (tester) async {
    await _pumpList(tester);
    expect(
      find.byKey(Key('todo-list-task-drag-$draggedId')),
      findsOneWidget,
      reason: '右下带只加落点；源要是被换掉，日历那一面（:49）就断了',
    );
    // 排序手柄只在 hover 那一行时才出现（既有行为），先把光标停到行上。
    final source = find.byKey(Key('task-row-surface-$draggedId'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(source));
    await tester.pump();
    expect(
      find.byTooltip('拖动排序'),
      findsOneWidget,
      reason: '长按拖出与行首排序手柄是两条既有通道，本面一条都不许弄没',
    );
    await mouse.removePointer();
  });

  testWidgets('异清单任务落到右下带：不截走「移入当前清单」那一层落点', (tester) async {
    final reparents = <String>[];
    final listMoves = <String>[];
    await _pumpNestedTargets(
      tester,
      dragged: _bareTask(id: _foreignId, listId: TodoVisualFixture.workListId),
      onReparent: reparents.add,
      onListMove: listMoves.add,
    );

    await _dragSourceOntoQuadrant(tester);

    expect(
      reparents,
      isEmpty,
      reason:
          '嘀嗒《07-任务与日历同时显示.md》:55「拖入清单详情区域＝移入当前清单」'
          '是这一层的外层落点；右下带把异清单任务截走，那一面当场失效',
    );
    expect(listMoves, <String>[
      _foreignId,
    ], reason: '内层拒了外层要接住（这条同时证明手势确实落到过这一行）');
  });

  testWidgets('同清单任务落到右下带：内层先接受，不顺带走移清单', (tester) async {
    final reparents = <String>[];
    final listMoves = <String>[];
    await _pumpNestedTargets(
      tester,
      dragged: _bareTask(
        id: _sameListTaskId,
        listId: TodoVisualFixture.inboxListId,
      ),
      onReparent: reparents.add,
      onListMove: listMoves.add,
    );

    await _dragSourceOntoQuadrant(tester);

    expect(reparents, <String>[
      _sameListTaskId,
    ], reason: '闸门收窄不能顺手把本面弄没：同清单任务仍要能落成子任务');
    expect(listMoves, isEmpty);
  });

  testWidgets('订阅/共享那种只读清单没有落点：嘀嗒 :28 只要收集箱与自己创建的清单', (tester) async {
    final fixture = await _pumpList(
      tester,
      initialListId: TodoVisualFixture.workListId,
      prepare: (db) async {
        await _insertTask(
          db,
          id: 'work-task-second',
          listId: TodoVisualFixture.workListId,
          title: '第二项',
        );
        await (db.update(db.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .write(TodoListsCompanion(writable: Value(false)));
      },
    );

    expect(
      await _parentTaskIdOf(fixture.database, 'visual-task-work-list'),
      isNull,
      reason: '前置条件：这一页真有两行可拖（否则 findsNothing 是空页造成的）',
    );
    expect(
      _rowDropZones(),
      findsNothing,
      reason:
          '只读清单上仓储必抛「当前清单为只读，无法修改任务」，'
          '所以这一行根本不该是落点，而不是拖上去再报错',
    );
  });

  testWidgets('同一张清单改回可写后落点出现：闸门读的是 writable 不是恒假', (tester) async {
    final fixture = await _pumpList(
      tester,
      initialListId: TodoVisualFixture.workListId,
      prepare: (db) async {
        await _insertTask(
          db,
          id: 'work-task-second',
          listId: TodoVisualFixture.workListId,
          title: '第二项',
        );
      },
    );

    expect(
      _rowDropZones(),
      findsWidgets,
      reason: '自建普通清单是 :28 明列的可用面；写死 false 会让这条红',
    );

    await _dragToBand(
      tester,
      sourceId: 'visual-task-work-list',
      targetId: 'work-task-second',
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, 'visual-task-work-list'),
      'work-task-second',
      reason: '自建清单里这一拖要真写进去：只把 findsWidgets 量出来而写不进，等于闸门修坏了',
    );
  });

  testWidgets('320px + 1.3 倍字号：象限按行自身的比例算，拖动照样成立', (tester) async {
    final fixture = await _pumpList(
      tester,
      viewport: const Size(320, 600),
      textScale: 1.3,
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      parentId,
      reason:
          '落点没有固定像素宽度；窄屏大字号把它挤没的话这条要红'
          '（嘀嗒 mobile tab :20 说的就是手机上这一拖）',
    );
  });

  testWidgets('真仓储的五层上限从新入口被触发时：提示看得见且一个字节都不写', (tester) async {
    final fixture = await _pumpList(
      tester,
      prepare: (db) async {
        // `depthOf` 是 0 基（顶层＝0），所以 pinned 下面要挂五层后代：
        // newTaskDepth 1 + subtreeDepth 5 = 6 > 5 才越界。
        // 第一版只挂四层（正好五级，合法不拒），量出来是拖成功了而不是被拒。
        var parent = draggedId;
        for (var level = 1; level <= 5; level++) {
          final id = 'deep-task-$level';
          await _insertTask(
            db,
            id: id,
            listId: TodoVisualFixture.inboxListId,
            title: '深层 $level',
          );
          await (db.update(db.todoTasks)..where((row) => row.id.equals(id)))
              .write(TodoTasksCompanion(parentTaskId: Value(parent)));
          parent = id;
        }
      },
    );

    final before = await _queuedChangeCount(
      fixture.database,
      localId: draggedId,
    );
    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      find.textContaining('任务层级不能超过五级'),
      findsOneWidget,
      reason: '守卫原话经 describeError 上屏（本仓不许直接插异常对象）',
    );
    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      isNull,
      reason: '被拒的一刀不许留下半个写入',
    );
    expect(
      await _queuedChangeCount(fixture.database, localId: draggedId),
      before,
      reason: '也不许入队——同步出去就是一个服务端会拒的越级关系',
    );
  });

  testWidgets('智能清单里右下带落点不存在（嘀嗒 :28 的闸门）', (tester) async {
    // initialListId = null ⇒ 页面身份是 `smart:all`（"全部"智能清单）。
    final fixture = await _pumpList(tester, initialListId: null);

    expect(
      _rowDropZones(),
      findsNothing,
      reason: '闸门关掉时这一行连落点都不该建，不该只是"点了没反应"',
    );

    await _dragToBand(
      tester,
      sourceId: draggedId,
      targetId: parentId,
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, draggedId),
      isNull,
      reason: '嘀嗒 :28「这一功能在「今天」、「最近七天」等智能清单中不可用」',
    );
  });

  testWidgets('收集箱有落点：闸门按页身份开', (tester) async {
    await _pumpList(tester);
    expect(
      _rowDropZones(),
      findsWidgets,
      reason: '收集箱（`list:inbox`）是嘀嗒 :28 明列的可用面',
    );
  });

  testWidgets('右下象限不抢点击：点这一行仍然选中它', (tester) async {
    final taps = <String>[];
    await _pumpList(tester, onTaskSelected: taps.add);
    final row = find.byKey(Key('task-row-surface-$parentId'));
    final point = _bandCenter(tester, row, _Band.lowerRight);

    await tester.tapAt(point);
    await tester.pumpAndSettle();

    expect(
      taps,
      contains(parentId),
      reason:
          '落点层缺省 translucent：只参加拖拽命中，不许吞这一行的点击'
          '（改成 opaque 命中即被抢，本条要红）',
    );
  });

  testWidgets('候选态读屏语义挂在落点节点：静止没有、悬停有、落定收走', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpList(tester);
    final zone = TaskSubtaskDropTarget.zoneKey(parentId);
    final label = TaskSubtaskDropTarget.hoverLabel(parentTitle);

    expect(find.byKey(zone), findsNothing, reason: '静止态给每行都挂「成为子任务」= 读屏噪声');

    final gesture = await _startBandHover(
      tester,
      sourceId: draggedId,
      targetId: parentId,
    );
    expect(find.byKey(zone), findsOneWidget, reason: '指针停在右下带时必须能量到这一格的语义');
    expect(tester.getSemantics(find.byKey(zone)).label, contains(label));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(zone), findsNothing, reason: '落定后候选态要收走');
    handle.dispose();
  });
}

enum _Band { lowerRight, upperLeft }

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

/// 真仓储 + 记账：其余方法（含列表流）都用实现，只记录 `reparent` 的入参与可选失败。
class _RecordingTaskRepository extends TaskRepository {
  _RecordingTaskRepository(AppDatabase db, {this.failure})
    : super(db, SyncChangeQueue(db));

  final Object? failure;
  final List<List<String?>> reparentCalls = [];

  @override
  Future<void> reparent(String taskId, String? newParentId) async {
    reparentCalls.add(<String?>[taskId, newParentId]);
    final error = failure;
    if (error != null) throw error;
    await super.reparent(taskId, newParentId);
  }
}

Future<TodoVisualFixture> _pumpList(
  WidgetTester tester, {
  String? initialListId = TodoVisualFixture.inboxListId,
  List<Override> Function(AppDatabase database)? overridesBuilder,
  void Function(String taskId)? onTaskSelected,
  Size viewport = TodoVisualViewports.wide,
  double textScale = 1,
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
          // 窄屏 + 1.3 倍字号那一面要真量：落点是行自身的 0.5×0.5 象限，
          // 不是固定像素，所以缩到 320px 也还在（这条用例是那句主张的读数）。
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
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
  return fixture;
}

/// 行内某个象限的全局坐标（右下＝(0.75w, 0.75h)，左上＝(0.25w, 0.25h)）。
///
/// 必须在**起手势之前**量：拖起来之后 feedback 会再渲染一份同一行
/// （`childWhenDragging` + feedback），那时 `task-row-surface-<id>` 有两个，
/// `getSize` 直接抛 `Too many elements`（本机实测踩过）。
/// **行级**落点。全树 `find.byType(DragTarget<TodoTask>)` 会把页级的
/// `TaskListDropTarget` 一起数进来（在清单页它恒在），那把尺量不出"这一行是不是落点"；
/// 所以作用域要切到 TaskSubtaskDropTarget 里面。
Finder _rowDropZones() => find.descendant(
  of: find.byType(TaskSubtaskDropTarget),
  matching: find.byType(DragTarget<TodoTask>),
);

Offset _bandCenter(WidgetTester tester, Finder row, _Band band) {
  expect(row, findsOneWidget);
  final size = tester.getSize(row);
  final dx = band == _Band.lowerRight ? size.width * 0.75 : size.width * 0.25;
  final dy = band == _Band.lowerRight ? size.height * 0.75 : size.height * 0.25;
  return tester.getTopLeft(row) + Offset(dx, dy);
}

/// 长按清单行（`LongPressDraggable` 的 300ms delay 要真过），停在目标行的某个象限。
Future<TestGesture> _startBandHover(
  WidgetTester tester, {
  required String sourceId,
  required String targetId,
  _Band band = _Band.lowerRight,
}) async {
  final source = find.byKey(Key('task-row-surface-$sourceId'));
  final target = find.byKey(Key('task-row-surface-$targetId'));
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  await tester.ensureVisible(source);
  // 字号放大那一档在起手势之前还会再排一次版；不等完就量，量到的是上一帧的行矩形，
  // 落点会掉到别的行上（窄屏那条用例第一版就是这么错的）。
  await tester.pumpAndSettle();
  final bandPoint = _bandCenter(tester, target, band);
  final startPoint = tester.getCenter(source);

  final gesture = await tester.startGesture(startPoint);
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.moveTo(bandPoint);
  await tester.pump();
  return gesture;
}

Future<void> _dragToBand(
  WidgetTester tester, {
  required String sourceId,
  required String targetId,
  required _Band band,
}) async {
  final gesture = await _startBandHover(
    tester,
    sourceId: sourceId,
    targetId: targetId,
    band: band,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 既有排序那一刀：悬停源行让行首手柄出现，再拖到目标行下方。
/// 形状逐字照抄 `task_list_reorder_widget_test.dart` 的 `_dragTaskAfter`——
/// 包括"目标行中心要等拖起来之后再量"这一点（清单会插占位、行会移位，
/// 提前算好的坐标会落到别处，本轮实测这样量不出排序）。
Future<void> _dragHandleToBelow(
  WidgetTester tester, {
  required String sourceId,
  required String targetId,
}) async {
  final source = find.byKey(Key('task-row-surface-$sourceId'));
  final target = find.byKey(Key('task-row-surface-$targetId'));
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  await tester.ensureVisible(source);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(source));
  await tester.pump();

  final handle = find.byTooltip('拖动排序');
  expect(handle, findsOneWidget);
  await mouse.moveTo(tester.getCenter(handle));
  await mouse.down(tester.getCenter(handle));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target) + const Offset(0, 24));
  await tester.pump(const Duration(milliseconds: 500));
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

const String _foreignId = 'fallthrough-foreign-task';
const String _sameListTaskId = 'fallthrough-same-list-task';
const String _rowTaskId = 'fallthrough-row-task';

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

/// 右下带套在「清单详情落点」里面一层——这就是清单页里的真实嵌套：
/// `tasks_by_list_page.dart` 用 `TaskListDropTarget` 包着整块列表体，行是它的后代。
/// 两个落点吃同一种数据（`TodoTask`），所以内外不互相截走这件事要能量出来。
Future<void> _pumpNestedTargets(
  WidgetTester tester, {
  required TodoTask dragged,
  required void Function(String taskId) onReparent,
  required void Function(String taskId) onListMove,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Draggable<TodoTask>(
                key: const ValueKey('fallthrough-source'),
                data: dragged,
                feedback: const SizedBox(
                  width: 120,
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
            // 行占 x∈[0,600]、y∈[200,260] ⇒ 右下象限＝x∈[300,600]、y∈[230,260]。
            Positioned(
              left: 0,
              top: 200,
              child: SizedBox(
                width: 600,
                height: 60,
                child: TaskListDropTarget(
                  currentListId: TodoVisualFixture.inboxListId,
                  onAccept: (task) => onListMove(task.id),
                  child: TaskSubtaskDropTarget(
                    task: _bareTask(
                      id: _rowTaskId,
                      listId: TodoVisualFixture.inboxListId,
                    ),
                    enabled: true,
                    onDrop: (task) async => onReparent(task.id),
                    child: const ColoredBox(
                      color: Colors.grey,
                      child: SizedBox(width: 600, height: 60),
                    ),
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
}

Future<void> _dragSourceOntoQuadrant(WidgetTester tester) async {
  final source = tester.getRect(
    find.byKey(const ValueKey('fallthrough-source')),
  );
  final gesture = await tester.startGesture(source.center);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(const Offset(450, 245));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

/// 直接落一行任务（绕开仓储守卫，只为把页面喂出可拖的两行/一条深链）。
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

Future<String?> _parentTaskIdOf(AppDatabase db, String taskId) async {
  final row = await (db.select(
    db.todoTasks,
  )..where((r) => r.id.equals(taskId))).getSingle();
  return row.parentTaskId;
}

Future<int> _queuedChangeCount(
  AppDatabase db, {
  required String localId,
}) async {
  final rows =
      await (db.select(db.todoSyncChanges)..where(
            (r) => r.entity.equals('task') & r.entityLocalId.equals(localId),
          ))
          .get();
  return rows.length;
}
