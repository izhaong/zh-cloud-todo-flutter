import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
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

  testWidgets('智能清单里右下带落点不存在（嘀嗒 :28 的闸门）', (tester) async {
    // initialListId = null ⇒ 页面身份是 `smart:all`（"全部"智能清单）。
    final fixture = await _pumpList(tester, initialListId: null);

    expect(
      find.byType(DragTarget<TodoTask>),
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
      find.byType(DragTarget<TodoTask>),
      findsWidgets,
      reason: '收集箱（`list:inbox`）是嘀嗒 :28 明列的可用面',
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
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);
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
        home: Scaffold(
          body: TasksByListPage(
            initialListId: initialListId,
            lockedListId: true,
            hideAppBar: true,
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
