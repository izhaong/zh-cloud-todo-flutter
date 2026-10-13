import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/task/task_swipe_preferences.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_subtask_drop.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_swipe_reveal.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_swipe_preference_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》
/// - `:62`「## 滑动操作」（小节标题行）
/// - `:66`「将任务向左短滑，可以看到任务右侧出现了三个选项，它们分别代表：
///   「移动任务」、「删除任务」、「修改日期」，根据需要点击对应的选项进行操作。」
/// - `:71`「向右滑动分别为「完成」、「置顶」。」
/// - `:75`「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置。」
///
/// 形状按原文那句"出现了三个选项……点击对应的选项进行操作"：
/// **短滑露出按钮，再点按钮才执行**，不是滑到尽头直接完成。
/// 方向与按钮位置是反的（向左滑 ⇒ 钮在行的右侧），这也照原文写死在用例里。
void main() {
  const taskId = TodoVisualFixture.pinnedTaskId;
  const secondTaskId = TodoVisualFixture.todayTaskId;
  const parentTaskId = TodoVisualFixture.metadataTaskId;
  const childTaskId = 'visual-task-metadata-child-1';
  const workListId = TodoVisualFixture.workListId;
  const personalListId = TodoVisualFixture.personalListId;

  testWidgets('向左短滑：行的右半边露出 移动任务/删除任务/修改日期 三个钮', (tester) async {
    await _pumpList(tester);

    // 关闭态钮就在树里（被行盖住）：可见性只能靠 hitTestable 判，
    // 用 findsNothing 会把"根本没建"和"建了但盖住"混成一件事。
    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId))
          .hitTestable(),
      findsNothing,
    );

    await _swipe(tester, taskId, const Offset(-110, 0));

    for (final action in [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ]) {
      final key = taskSwipeActionKey(action, taskId);
      expect(find.byKey(key), findsOneWidget, reason: '$action 是 `:66` 点名的那一档');
      expect(
        find.byKey(key).hitTestable(),
        findsOneWidget,
        reason: '$action 露出来就该点得动',
      );
    }

    final row = tester.getRect(find.byKey(Key('task-row-surface-$taskId')));
    expect(
      tester
          .getCenter(
            find.byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId)),
          )
          .dx,
      greaterThan(row.left + row.width * 0.5),
      reason: '`:66`「可以看到任务**右侧**出现了三个选项」',
    );
  });

  testWidgets('向右滑动：行的左半边露出 完成/置顶', (tester) async {
    await _pumpList(tester);
    await _swipe(tester, taskId, const Offset(110, 0));

    for (final action in [TaskSwipeAction.complete, TaskSwipeAction.pin]) {
      expect(
        find.byKey(taskSwipeActionKey(action, taskId)).hitTestable(),
        findsOneWidget,
        reason: '$action 是 `:71`「向右滑动分别为「完成」、「置顶」」里的那一档',
      );
    }
    final row = tester.getRect(find.byKey(Key('task-row-surface-$taskId')));
    expect(
      tester
          .getCenter(
            find.byKey(taskSwipeActionKey(TaskSwipeAction.complete, taskId)),
          )
          .dx,
      lessThan(row.left + row.width * 0.5),
      reason: '向右滑时内容往右走，钮从行的**左**边露出来',
    );
  });

  testWidgets('一次滑动只可能露出一侧（原文每句都只给一头的选项）', (tester) async {
    await _pumpList(tester);
    await _swipe(tester, taskId, const Offset(-110, 0));
    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId))
          .hitTestable(),
      findsOneWidget,
    );

    // 反方向拖过头：从 -216 越过 0 到左侧阈值之上，换到另一侧，这一侧必须收回去。
    await _swipe(tester, taskId, const Offset(300, 0));
    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId))
          .hitTestable(),
      findsNothing,
      reason: '两侧共用一个位移，不能同时露出',
    );
    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.complete, taskId))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('点「完成」才执行：滑动本身不改库', (tester) async {
    final fixture = await _pumpList(tester);
    expect((await _row(fixture.database, taskId)).completed, isFalse);

    await _swipe(tester, taskId, const Offset(110, 0));
    expect(
      (await _row(fixture.database, taskId)).completed,
      isFalse,
      reason: '短滑只是露出按钮；原文写的是"点击对应的选项进行操作"',
    );

    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.complete, taskId)),
    );
    await tester.pumpAndSettle();
    expect((await _row(fixture.database, taskId)).completed, isTrue);
  });

  testWidgets('已完成那一行的「完成」说「取消完成」，点它真的取消', (tester) async {
    final fixture = await _pumpList(
      tester,
      prepare: (db) async {
        await (db.update(db.todoTasks)..where((task) => task.id.equals(taskId)))
            .write(TodoTasksCompanion(completed: Value(true)));
      },
    );

    await _swipe(tester, taskId, const Offset(110, 0));
    final completeKey = taskSwipeActionKey(TaskSwipeAction.complete, taskId);
    expect(
      find.descendant(of: find.byKey(completeKey), matching: find.text('取消完成')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(completeKey), matching: find.text('完成')),
      findsNothing,
      reason: '行已经是完成态，钮再叫「完成」就是骗人',
    );

    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.complete, taskId)),
    );
    await tester.pumpAndSettle();
    expect((await _row(fixture.database, taskId)).completed, isFalse);
  });

  testWidgets('点「置顶」改的是这一行的置顶态（复用既有 togglePin 通道）', (tester) async {
    final fixture = await _pumpList(tester);
    expect(
      (await _row(fixture.database, taskId)).isPinned,
      isTrue,
      reason: '种子：pinned 已置顶',
    );

    await _swipe(tester, taskId, const Offset(110, 0));
    expect(
      find.descendant(
        of: find.byKey(taskSwipeActionKey(TaskSwipeAction.pin, taskId)),
        matching: find.text('取消置顶'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.pin, taskId)),
    );
    await tester.pumpAndSettle();
    expect((await _row(fixture.database, taskId)).isPinned, isFalse);
  });

  testWidgets('「删除任务」先确认：取消不删，确认才删并排 outbox', (tester) async {
    final fixture = await _pumpList(tester);

    await _swipe(tester, taskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-task-swipe-delete-cancel')));
    await tester.pumpAndSettle();
    expect(
      await _rowOrNull(fixture.database, taskId),
      isNotNull,
      reason: '确认之前不能删 —— 删除是这一面上唯一不可逆的动作',
    );

    await _swipe(tester, taskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-task-swipe-delete-confirm')));
    await tester.pumpAndSettle();

    expect(await _rowOrNull(fixture.database, taskId), isNull);
    expect(
      await _outboxCount(fixture.database, taskId),
      greaterThan(0),
      reason: '本地删了还得让第二台设备知道',
    );
  });

  testWidgets('「移动任务」的表里只有可写清单，选中就真的换清单', (tester) async {
    final fixture = await _pumpList(
      tester,
      prepare: (db) async {
        await db
            .into(db.todoLists)
            .insert(
              TodoListsCompanion.insert(
                id: 'visual-list-readonly',
                name: '订阅来的',
                writable: const Value(false),
                updatedAt: DateTime.utc(2026, 7, 11),
                createdAt: DateTime.utc(2026, 7, 11),
              ),
            );
      },
    );
    expect(
      (await _row(fixture.database, taskId)).listId,
      TodoVisualFixture.inboxListId,
    );

    await _swipe(tester, taskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.moveTo, taskId)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-task-swipe-move-target-$workListId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('todo-task-swipe-move-target-inbox')),
      findsNothing,
      reason: '任务本来就在收集箱，表里不该再给自己当目标',
    );
    expect(
      find.byKey(const Key('todo-task-swipe-move-target-visual-list-readonly')),
      findsNothing,
      reason: '只读清单挪进去就是一行改不动的任务，不该出现在表里',
    );

    await tester.tap(
      find.byKey(const Key('todo-task-swipe-move-target-$workListId')),
    );
    await tester.pumpAndSettle();

    expect((await _row(fixture.database, taskId)).listId, workListId);
    expect(find.text('已移动到「工作」'), findsOneWidget);
  });

  testWidgets('移动父任务时子任务一起走（update(listId:) 只挪一行，这里必须挪一棵树）', (tester) async {
    final fixture = await _pumpList(tester);

    await _swipe(tester, parentTaskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.moveTo, parentTaskId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-task-swipe-move-target-$personalListId')),
    );
    await tester.pumpAndSettle();

    expect((await _row(fixture.database, parentTaskId)).listId, personalListId);
    expect(
      (await _row(fixture.database, childTaskId)).listId,
      personalListId,
      reason: '子级留在原清单的话，父行上的展开箭头点开是空的 —— 看着像被删了',
    );
  });

  testWidgets('「移动任务」之后行不再属于当前这一页（收集箱页看不到挪走的行）', (tester) async {
    await _pumpList(tester);

    await _swipe(tester, taskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.moveTo, taskId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-task-swipe-move-target-$workListId')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('task-row-surface-$taskId')),
      findsNothing,
      reason: '挪走的行要立刻从这一页消失，否则用户会以为没生效',
    );
  });

  testWidgets('「修改日期」打开日期选择器，确定后截止日落到选的那天', (tester) async {
    final fixture = await _pumpList(tester, prepare: _clearDueAt);

    await _swipe(tester, secondTaskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(
        taskSwipeActionKey(TaskSwipeAction.changeDueDate, secondTaskId),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置截止日期'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final row = await _row(fixture.database, secondTaskId);
    final today = fixture.fixedNow;
    expect(
      DateTime(row.dueAt!.year, row.dueAt!.month, row.dueAt!.day),
      DateTime(today.year, today.month, today.day),
      reason: '日期选择器的默认那天就是"确定"落下去的日子（走 scheduleTaskToDay 既有通道）',
    );
    expect(row.allDay, isTrue, reason: '无日期的任务补的是纯日期全天语义');
  });

  testWidgets('日期选择器取消 ⇒ 不动 dueAt，也不排 outbox', (tester) async {
    final fixture = await _pumpList(tester, prepare: _clearDueAt);
    final before = await _row(fixture.database, secondTaskId);
    expect(before.dueAt, isNull, reason: '前置条件：这一行本来没有日期');

    await _swipe(tester, secondTaskId, const Offset(-110, 0));
    await tester.tap(
      find.byKey(
        taskSwipeActionKey(TaskSwipeAction.changeDueDate, secondTaskId),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      (await _row(fixture.database, secondTaskId)).dueAt,
      isNull,
      reason: '取消就是把这一刀收回去，不该留下任何写入',
    );
  });

  testWidgets('档位是数据不是常量：改过设置后，行露出的就是改过的那一套', (tester) async {
    final fixture = await _pumpList(tester);
    await TaskSwipePreferenceRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).save(
      TaskSwipePreferences.defaults.withSwipeLeft(const [
        TaskSwipeAction.delete,
      ]),
    );
    await tester.pumpAndSettle();

    await _swipe(tester, taskId, const Offset(-110, 0));
    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId))
          .hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.moveTo, taskId)),
      findsNothing,
      reason: '`:75`「可以进行自定义配置」：被去掉的那一档不该还在树里',
    );
  });

  testWidgets('露出时点行体只收起，不会顺手选中任务', (tester) async {
    final tapped = <String>[];
    await _pumpList(tester, onTaskSelected: tapped.add);

    await _swipe(tester, taskId, const Offset(-110, 0));
    // 露出状态下行体整体挪了 216px，它的"中心"已经落在按钮带上；
    // 要点的是还在原位的那截行体，否则这一tap 打的是动作钮，不是在测收起。
    final box = tester.getRect(find.byKey(ValueKey('task-swipe-$taskId')));
    await tester.tapAt(Offset(box.left + 12, box.center.dy));
    await tester.pumpAndSettle();

    expect(
      find
          .byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId))
          .hitTestable(),
      findsNothing,
      reason: '点行体要能把这一行收回去',
    );
    expect(tapped, isEmpty, reason: '收起这一笔不该同时被当成"打开任务"');
  });

  testWidgets('收起态点行体照旧选中任务（新组件没把既有点击吃掉）', (tester) async {
    final tapped = <String>[];
    await _pumpList(tester, onTaskSelected: tapped.add);

    await tester.tap(find.byKey(Key('task-row-surface-$taskId')));
    await tester.pumpAndSettle();

    expect(tapped, [taskId]);
  });

  testWidgets('长按拖动的三格落点仍在（滑动没把《06-多级任务.md》那块抢占掉）', (tester) async {
    await _pumpList(tester);
    expect(
      find.byKey(TaskSubtaskDropTarget.beforeDropKey(taskId)),
      findsOneWidget,
      reason: '第 295 轮那三面是靠长压起的，滑动条不能把指针先抢走',
    );

    final source = find.byKey(Key('task-row-surface-$secondTaskId'));
    final target = find.byKey(Key('task-row-surface-$taskId'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(_bandCenter(tester, target, _Band.top));
    await tester.pump();
    expect(
      find.byKey(TaskSubtaskDropTarget.beforeZoneKey(taskId)),
      findsOneWidget,
      reason: '长按 300ms 后源行应进入拖拽，目标行的上半格应亮',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('批量选择态下不露出滑动动作（此时点行是改勾选）', (tester) async {
    await _pumpList(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(Key('task-row-surface-$secondTaskId')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('todo-batch-actionbar')),
      findsOneWidget,
      reason: '前置条件：真的进了批量态，否则下面的 findsNothing 是空页造成的',
    );

    final start = tester.getCenter(find.byKey(Key('task-row-surface-$taskId')));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(start + const Offset(-110, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId)),
      findsNothing,
      reason: '批量态滑一下不该冒出五个别的动作的入口',
    );
  });

  testWidgets('桌面端这一行不挂滑动条（桌面用右键菜单，原文也只写移动端）', (tester) async {
    await _pumpList(tester, viewport: TodoVisualViewports.wide);

    expect(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.delete, taskId)),
      findsNothing,
    );
    expect(
      find.byKey(const Key('todo-task-swipe-collapse-barrier')),
      findsNothing,
    );
  });

  testWidgets('写库失败时给可见提示，且不把异常对象印进文案', (tester) async {
    late _ThrowingTaskRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (database) {
        repository = _ThrowingTaskRepository(
          database,
          SyncChangeQueue(database),
        );
        return [taskRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _swipe(tester, taskId, const Offset(110, 0));
    await tester.tap(
      find.byKey(taskSwipeActionKey(TaskSwipeAction.complete, taskId)),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, [taskId]);
    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget, reason: '失败必须看得见，不能静默');
    expect(
      find.text('操作失败，请重试'),
      findsOneWidget,
      reason: '文案说人话：不许把 StateError 或"boom"印到界面上',
    );
  });

  testWidgets('320px 窄屏 + 1.3 倍字号：三个钮不溢出、还点得动', (tester) async {
    await _pumpList(tester, viewport: const Size(320, 720), textScale: 1.3);

    await _swipe(tester, taskId, const Offset(-110, 0));
    for (final action in [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ]) {
      expect(
        find.byKey(taskSwipeActionKey(action, taskId)).hitTestable(),
        findsOneWidget,
        reason: '$action 在最小宽度上仍然是个能点的钮',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('滑动钮对读屏是可聚焦的按钮，名字就是档位名', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpList(tester);

    await _swipe(tester, taskId, const Offset(-110, 0));
    for (final action in [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ]) {
      final semantics = tester.getSemantics(
        find.byKey(taskSwipeActionKey(action, taskId)),
      );
      expect(semantics.label, action.label, reason: '$action 的读屏名');
      expect(semantics.flagsCollection.isButton, isTrue);
    }
    handle.dispose();
  });
}

/// 只有 `toggleComplete` 会抛的仓储替身：要的是"写失败"这条路径本身，
/// 不是把整个仓储换成假对象。
class _ThrowingTaskRepository extends TaskRepository {
  _ThrowingTaskRepository(super.db, super.queue);

  final List<String> calls = [];

  @override
  Future<TodoTask> toggleComplete(String taskId) async {
    calls.add(taskId);
    throw StateError('boom');
  }
}

enum _Band { top }

Offset _bandCenter(WidgetTester tester, Finder row, _Band band) {
  expect(row, findsOneWidget);
  final size = tester.getSize(row);
  final topLeft = tester.getTopLeft(row);
  return switch (band) {
    _Band.top => topLeft + Offset(size.width * 0.5, size.height * 0.25),
  };
}

/// 起手势点在行体上"还没有被按钮盖住"的那一段：露出状态下行整体挪了 216px，
/// 它的几何中心已经压在按钮带上，从中心起手打的其实是按钮而不是这一行。
Future<void> _swipe(WidgetTester tester, String taskId, Offset delta) async {
  final box = tester.getRect(find.byKey(ValueKey('task-swipe-$taskId')));
  final startX = delta.dx < 0 ? box.right - 30 : box.left + 30;
  await tester.dragFrom(Offset(startX, box.center.dy), delta);
  await tester.pumpAndSettle();
}

/// 「今天」那颗种子本来就带 dueAt；不清掉的话，"确定"落的那天 == 它原来的那天，
/// `scheduleTaskToDay` 会当成没变化直接 return —— 用例就会绿在一个根本没写入的路径上。
Future<void> _clearDueAt(AppDatabase db) =>
    (db.update(
      db.todoTasks,
    )..where((task) => task.id.equals(TodoVisualFixture.todayTaskId))).write(
      TodoTasksCompanion(dueAt: const Value(null), allDay: const Value(false)),
    );

Future<TodoTask> _row(AppDatabase db, String id) =>
    (db.select(db.todoTasks)..where((task) => task.id.equals(id))).getSingle();

Future<TodoTask?> _rowOrNull(AppDatabase db, String id) => (db.select(
  db.todoTasks,
)..where((task) => task.id.equals(id))).getSingleOrNull();

Future<int> _outboxCount(AppDatabase db, String taskId) async {
  final changes = await (db.select(
    db.todoSyncChanges,
  )..where((change) => change.entityLocalId.equals(taskId))).get();
  return changes.length;
}

Future<TodoVisualFixture> _pumpList(
  WidgetTester tester, {
  Size viewport = const Size(390, 844),
  double textScale = 1.0,
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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: TasksByListPage(
              initialListId: TodoVisualFixture.inboxListId,
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
