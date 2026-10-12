import 'package:drift/drift.dart' hide isNull;
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
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》「拖动排序」：
/// 「你还可以自已手动拖动任务的顺序，让任务排序更灵活。」
/// 「按住任务，自由选择放置任务的位置。多种操作，一“指”搞定。」
/// 同页「拖动生成子任务」把两件事并成"同一个手势、由放置位置决定结果"：
/// 「滴答清单不仅支持拖动调整任务排序，你还可以用拖动来实现「任务」➡️「子任务」的转换。」
///
/// ⇒ 一行划三块：上半＝排到该行之前、下半左＝排到该行之后、下半右＝转子任务（FL #590/#591）。
/// 这里走真实页面 + 记账仓储，断的是"提交出去的顺序是哪一条"，不是"有没有画高亮"。
void main() {
  // 收集箱顶层四行（sortOrder 0..3）：pinned、today-primary、today-secondary、metadata。
  const firstId = TodoVisualFixture.pinnedTaskId;
  const secondId = TodoVisualFixture.todayTaskId;
  const thirdId = TodoVisualFixture.secondaryTodayTaskId;
  const secondTitle = '完成 Todo 工作区视觉评审';

  testWidgets('拖到某行上半格＝排到该行之前：提交的顺序是可核对的那一条', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );

    // 前置条件：基线确实是 [first, second, third]（不先量住，"变成 [third, first, second]"
    // 可能只是页面本来就是这个序，断言就成了恒过）。
    await _expectRowOrder(tester, <String>[firstId, secondId, thirdId]);

    await _dragBand(
      tester,
      sourceId: thirdId,
      targetId: firstId,
      band: _Band.top,
    );

    expect(repository.requests, hasLength(1), reason: '这一刀只提交一次排序');
    final submitted = repository.requests.single;
    expect(submitted.take(3).toList(), <String>[
      thirdId,
      firstId,
      secondId,
    ], reason: '上半＝插到该行之前；写成"之后"或原地不动，这一条就要红');
  });

  testWidgets('拖到某行左下格＝排到该行之后：与上半格是同一次拖的另一种落点', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );
    await _expectRowOrder(tester, <String>[firstId, secondId, thirdId]);

    await _dragBand(
      tester,
      sourceId: firstId,
      targetId: thirdId,
      band: _Band.lowerLeft,
    );

    final submitted = repository.requests.single;
    expect(
      submitted.indexOf(firstId),
      submitted.indexOf(thirdId) + 1,
      reason: '下半左＝紧贴目标行之后，而不是掉到列表末尾',
    );
    expect(
      submitted.indexOf(firstId),
      greaterThan(0),
      reason: '它原本就是第一行：没往下走就说明这一刀没被当成"之后"',
    );
  });

  testWidgets('上半与左下是两块：同一次拖换落点就换结果', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );
    await _expectRowOrder(tester, <String>[firstId, secondId, thirdId]);

    // 同一对源/目标（third 拖到 first 那一行），只把落点从上半换到左下。
    await _dragBand(
      tester,
      sourceId: thirdId,
      targetId: firstId,
      band: _Band.lowerLeft,
    );
    expect(
      repository.requests.single,
      containsAllInOrder(<String>[firstId, thirdId, secondId]),
      reason:
          '落点在 first 的下面＝排在 first 之后。若两块合成一块（或左下没建），'
          '这一条会读成 [third, first, second]，正是上面那半句的形状',
    );
  });

  testWidgets('下半右那块仍写父子、不提交排序（三块各管各的）', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );

    await _dragBand(
      tester,
      sourceId: firstId,
      targetId: secondId,
      band: _Band.lowerRight,
    );

    expect(
      await _parentTaskIdOf(fixture.database, firstId),
      secondId,
      reason: 'FL #590 那块右下带必须原样有效：三块里只有它写父子',
    );
    expect(repository.requests, isEmpty, reason: '转子任务那一刀不该顺带提交一次排序');
  });

  testWidgets('放置只写顺序、不写父子：上半格那一刀 parentTaskId 一个字都不动', (tester) async {
    final fixture = await _pumpList(tester);

    await _dragBand(
      tester,
      sourceId: thirdId,
      targetId: firstId,
      band: _Band.top,
    );

    expect(await _parentTaskIdOf(fixture.database, thirdId), isNull);
    expect(await _parentTaskIdOf(fixture.database, firstId), isNull);
  });

  testWidgets('拖到自己那一行：既不排到自己前/后，也不写父子', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: _recording((r) => repository = r),
    );

    await _dragBand(
      tester,
      sourceId: firstId,
      targetId: firstId,
      band: _Band.top,
    );

    expect(
      repository.requests,
      isEmpty,
      reason: '落点自己就该拒（与右下带同一口径），不该提交一次"原地不动"的排序',
    );
    expect(await _parentTaskIdOf(fixture.database, firstId), isNull);
  });

  testWidgets('排序保存失败要回滚视觉顺序并只给一条可见提示', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(
          db,
          failure: StateError('放置排序故意失败'),
        );
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );
    await _expectRowOrder(tester, <String>[firstId, secondId, thirdId]);

    await _dragBand(
      tester,
      sourceId: thirdId,
      targetId: firstId,
      band: _Band.top,
    );

    expect(repository.requests, hasLength(1), reason: '确实提交过了，才谈得上回滚');
    expect(
      find.text('排序保存失败，请重试'),
      findsOneWidget,
      reason:
          '落地走页面那条统一失败文案（只读那句另有用例，见 '
          'test/features/task/task_list_reorder_widget_test.dart）',
    );
    // 落点层自己也包了 try/catch：两处都提示就会排队成两条 SnackBar
    // （同一类缺陷在本仓记过账），所以"只有一条"要钉住。
    expect(find.byType(SnackBar), findsOneWidget, reason: '一条通道失败只能看见一条提示');
    await _expectRowOrder(tester, <String>[firstId, secondId, thirdId]);
  });

  testWidgets('智能清单里这两块落点不存在（手动排序本来就不适用）', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      initialListId: null,
      overridesBuilder: _recording((r) => repository = r),
    );

    expect(
      find.byKey(Key('task-row-surface-$firstId')),
      findsOneWidget,
      reason: '前置条件：这一页真渲染了行，findsNothing 不是空页造成的',
    );
    expect(
      find.byKey(TaskSubtaskDropTarget.beforeDropKey(firstId)),
      findsNothing,
      reason: '智能清单上"第几行"没有意义：这一行不该是放置目标',
    );
    expect(
      find.byKey(TaskSubtaskDropTarget.afterDropKey(firstId)),
      findsNothing,
    );

    await _dragBand(
      tester,
      sourceId: firstId,
      targetId: secondId,
      band: _Band.top,
    );

    expect(repository.requests, isEmpty, reason: '拖上去什么都不该发生，而不是"看着能落、落下去报错"');
  });

  testWidgets('有分组的清单没有这两块落点，但转子任务那块照旧', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      withSection: true,
      overridesBuilder: _recording((r) => repository = r),
    );

    expect(
      find.byKey(TaskSubtaskDropTarget.beforeDropKey(firstId)),
      findsNothing,
      reason: '跨分组插到哪条是未定义的事：页面级排序不可用时这两块就不该建',
    );
    expect(
      find.byKey(TaskSubtaskDropTarget.afterDropKey(firstId)),
      findsNothing,
    );
    // 反向对照：同一行仍然是"转子任务"的落点 ⇒ 上面两个 findsNothing 不是
    // 整行落点都没建（那才是本轮真正要区分的两种"没有"）。
    expect(
      find.descendant(
        of: find.byType(TaskSubtaskDropTarget),
        matching: find.byType(DragTarget<TodoTask>),
      ),
      findsWidgets,
      reason: '分组只关掉放置，不该顺手把《06-多级任务.md》那块右下带也关掉',
    );

    await _dragBand(
      tester,
      sourceId: firstId,
      targetId: secondId,
      band: _Band.top,
    );
    expect(repository.requests, isEmpty);
  });

  testWidgets('收集箱这两块落点都在（闸门按页面级可用性开）', (tester) async {
    await _pumpList(tester);
    expect(
      find.byKey(TaskSubtaskDropTarget.beforeDropKey(firstId)),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskSubtaskDropTarget.afterDropKey(firstId)),
      findsOneWidget,
    );
  });

  testWidgets('异清单任务不被放置落点截走（三块共用同一条接受条件）', (tester) async {
    final places = <String>[];
    final listMoves = <String>[];
    await _pumpNestedTargets(
      tester,
      dragged: _bareTask(id: _foreignId, listId: TodoVisualFixture.workListId),
      onPlace: (draggedTask, _) => places.add(draggedTask.id),
      onListMove: (task) => listMoves.add(task.id),
    );

    // 上半条覆盖整行宽度，(300,215) 落在其中。
    await _dragFrom(
      tester,
      from: const Offset(20, 20),
      to: const Offset(300, 215),
    );

    expect(
      places,
      isEmpty,
      reason:
          '上半格也是内层落点：来者不拒会把《07-任务与日历同时显示.md」那句'
          '「将日历中的任务拖入清单详情区域」的移清单截走',
    );
    expect(listMoves, <String>[_foreignId]);
  });

  testWidgets('候选态读屏语义：上半「排到之前」、左下「排到之后」各挂各的节点', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpList(tester);
    final beforeKey = TaskSubtaskDropTarget.beforeZoneKey(secondId);
    final afterKey = TaskSubtaskDropTarget.afterZoneKey(secondId);

    expect(find.byKey(beforeKey), findsNothing, reason: '静止态给每行都挂两个排序标签＝读屏噪声');

    // 两块的中心都要在起手势之前量：拖起来后 feedback 会再渲染一份同一行。
    final source = find.byKey(Key('task-row-surface-$firstId'));
    final target = find.byKey(Key('task-row-surface-$secondId'));
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final startPoint = tester.getCenter(source);
    final beforePoint = _bandCenter(tester, target, _Band.top);
    final afterPoint = _bandCenter(tester, target, _Band.lowerLeft);

    final gesture = await tester.startGesture(startPoint);
    await tester.pump(const Duration(milliseconds: 400));

    await gesture.moveTo(beforePoint);
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(beforeKey)).label,
      contains('排到「$secondTitle」之前'),
    );
    expect(find.byKey(afterKey), findsNothing, reason: '两块不能同时亮：同时亮就是没分格');

    await gesture.moveTo(afterPoint);
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(afterKey)).label,
      contains('排到「$secondTitle」之后'),
    );
    expect(find.byKey(beforeKey), findsNothing, reason: '换格之后上一块的候选态要收走');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(afterKey), findsNothing);
    handle.dispose();
  });

  testWidgets('320px + 1.3 倍字号：上半格放置仍成立（三块都是行自身比例）', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      viewport: const Size(320, 600),
      textScale: 1.3,
      overridesBuilder: _recording((r) => repository = r),
    );

    await _dragBand(
      tester,
      sourceId: secondId,
      targetId: firstId,
      band: _Band.top,
    );

    expect(repository.requests, hasLength(1), reason: '窄屏大字号把落点挤没了这条要红');
    expect(repository.requests.single.first, secondId);
  });
}

enum _Band { top, lowerLeft, lowerRight }

const String _foreignId = 'placement-foreign-task';

class _RecordingTaskViewActionRepository extends TaskViewActionRepository {
  _RecordingTaskViewActionRepository(AppDatabase db, {this.failure})
    : super(db, SyncChangeQueue(db));

  final Object? failure;
  final List<List<String>> requests = [];

  @override
  Future<void> reorderListTasks(List<String> taskIds) async {
    requests.add(List<String>.of(taskIds));
    final error = failure;
    if (error != null) throw error;
    await super.reorderListTasks(taskIds);
  }
}

/// 把记账仓储交回给用例里的 `repository` 变量（每条用例都要先拿到它才好断言"提交过几次"）。
List<Override> Function(AppDatabase) _recording(
  void Function(_RecordingTaskViewActionRepository) capture,
) {
  return (db) {
    final repository = _RecordingTaskViewActionRepository(db);
    capture(repository);
    return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
  };
}

Future<TodoVisualFixture> _pumpList(
  WidgetTester tester, {
  String? initialListId = TodoVisualFixture.inboxListId,
  List<Override> Function(AppDatabase database)? overridesBuilder,
  bool withSection = false,
  Size viewport = TodoVisualViewports.wide,
  double textScale = 1,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);

  if (withSection) {
    final stamp = DateTime.utc(2026, 7, 11, 9);
    await fixture.database
        .into(fixture.database.todoTaskSections)
        .insert(
          TodoTaskSectionsCompanion.insert(
            id: 'placement-section',
            listId: TodoVisualFixture.inboxListId,
            name: '一个分组',
            updatedAt: stamp,
            createdAt: stamp,
          ),
        );
    // 只把一行挂进分组：`taskSectionsByListProvider` 一发值，页面级排序就不可用了。
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((row) => row.id.equals(TodoVisualFixture.pinnedTaskId)))
        .write(TodoTasksCompanion(sectionId: Value('placement-section')));
  }

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
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: TasksByListPage(
              initialListId: initialListId,
              lockedListId: true,
              hideAppBar: true,
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

/// 界面上这几行的上下顺序（按行表面的顶边量）。
/// 放置的两条判据断的是"提交的顺序"，而提交的顺序对不对，取决于基线是不是这个序 ——
/// 所以基线本身要先量住，否则"变成 [third, first, second]"可能是恒过的。
Future<void> _expectRowOrder(WidgetTester tester, List<String> ids) async {
  for (var index = 0; index < ids.length - 1; index++) {
    final upper = tester
        .getTopLeft(find.byKey(Key('task-row-surface-${ids[index]}')))
        .dy;
    final lower = tester
        .getTopLeft(find.byKey(Key('task-row-surface-${ids[index + 1]}')))
        .dy;
    expect(
      upper,
      lessThan(lower),
      reason: '${ids[index]} 应当排在 ${ids[index + 1]} 上面',
    );
  }
}

/// 这一行必须已经建出来且整条在视口内：一次拖要同时够到源行与目标行，
/// 而 ListView 只建视口内的行（拿视口外的行当源/目标，量到的是上一帧或干脆没有）。
void _expectRowVisible(WidgetTester tester, Finder row, String taskId) {
  expect(row, findsOneWidget, reason: '$taskId 那一行没进树：这一对应选同一屏里的行');
  final rect = tester.getRect(row);
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(
    rect.top >= 0 && rect.bottom <= viewportHeight,
    isTrue,
    reason:
        '$taskId 那一行没有整条落在视口里'
        '（top=${rect.top} bottom=${rect.bottom} 视口高=$viewportHeight）',
  );
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

/// 长按源行（`LongPressDraggable` 那 300ms 的 delay 要真过）再落到目标行的某一格。
Future<void> _dragBand(
  WidgetTester tester, {
  required String sourceId,
  required String targetId,
  required _Band band,
}) async {
  final source = find.byKey(Key('task-row-surface-$sourceId'));
  final target = find.byKey(Key('task-row-surface-$targetId'));
  // 一次拖要同时够到两行 ⇒ 两行都必须已经在视口里建好。
  // `ensureVisible` 只滚一边会把另一边回收（ListView 懒建，本轮实测
  // `Bad state: No element`），所以这里不滚，只要求用例挑同一屏里的行。
  await tester.pumpAndSettle();
  _expectRowVisible(tester, source, sourceId);
  _expectRowVisible(tester, target, targetId);
  final startPoint = tester.getCenter(source);
  final to = _bandCenter(tester, target, band);

  final gesture = await tester.startGesture(startPoint);
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<String?> _parentTaskIdOf(AppDatabase db, String taskId) async {
  final row = await (db.select(
    db.todoTasks,
  )..where((r) => r.id.equals(taskId))).getSingle();
  return row.parentTaskId;
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

/// 放置落点与「移入当前清单」落点套在同一棵树里（清单页的真实嵌套）：
/// 量的是"内层别把异清单任务截走"这条对三块一视同仁。
Future<void> _pumpNestedTargets(
  WidgetTester tester, {
  required TodoTask dragged,
  required void Function(TodoTask dragged, bool after) onPlace,
  required void Function(TodoTask task) onListMove,
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
                key: const ValueKey('placement-source'),
                data: dragged,
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
            // 行占 x∈[0,600]、y∈[200,260] ⇒ 上半条＝y∈[200,230]、下半左＝x∈[0,300]。
            Positioned(
              left: 0,
              top: 200,
              child: SizedBox(
                width: 600,
                height: 60,
                child: TaskListDropTarget(
                  currentListId: TodoVisualFixture.inboxListId,
                  onAccept: onListMove,
                  child: TaskSubtaskDropTarget(
                    task: _bareTask(
                      id: 'placement-row',
                      listId: TodoVisualFixture.inboxListId,
                    ),
                    enabled: true,
                    onDrop: (_) async {},
                    onPlace: (draggedTask, after) async =>
                        onPlace(draggedTask, after),
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

Future<void> _dragFrom(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  expect(find.byKey(const ValueKey('placement-source')), findsOneWidget);
  final gesture = await tester.startGesture(from);
  await tester.pump();
  await gesture.moveTo(from + const Offset(4, 40));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}
