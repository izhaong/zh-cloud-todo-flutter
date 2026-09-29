import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/list_drop_target.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》拖动排期的 ② 面：
/// `:53`「将日历中的任务拖入清单详情区域」、`:55`「任务会从原所属清单迁移到当前查看的清单中，
/// 并保留其原有的时间安排。」⇒ 判据是「换清单」+「时间安排一个字都不动」+「分组不能跟着跨清单」。
final _due = DateTime(2026, 7, 11, 15, 30);

const _sourceCenter = Offset(20, 20);
const _targetCenter = Offset(150, 240);

Widget _harness({
  required TodoTask task,
  required String? viewListId,
  required void Function(TodoTask) onAccept,
  double width = 320,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 600),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SizedBox(
          width: width,
          height: 600,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Draggable<TodoTask>(
                  key: const ValueKey('drag-source'),
                  data: task,
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
              Positioned(
                left: 0,
                top: 80,
                child: SizedBox(
                  width: width,
                  height: 320,
                  child: TaskListDropTarget(
                    currentListId: viewListId,
                    onAccept: onAccept,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(width: width, height: 320),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 跑完一次「从日历拖到清单详情区域」的手势。
Future<void> _dragOntoTarget(WidgetTester tester) async {
  final gesture = await tester.startGesture(_sourceCenter);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(_targetCenter);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

final _stamp = DateTime.utc(2026, 7, 11, 9);

/// `TaskRepository` 读写都要清单行存在（`_requireWritableList`），所以三个目标清单都得先落库。
Future<void> _seedLists(AppDatabase db, List<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: id,
            name: '清单 $id',
            updatedAt: _stamp,
            createdAt: _stamp,
          ),
        );
  }
}

Future<void> _seedSection(AppDatabase db, String id, String listId) async {
  await db
      .into(db.todoTaskSections)
      .insert(
        TodoTaskSectionsCompanion.insert(
          id: id,
          listId: listId,
          name: '分组 $id',
          updatedAt: _stamp,
          createdAt: _stamp,
        ),
      );
}

Future<TodoTask> _seedTask(AppDatabase db, SyncChangeQueue queue) async {
  await _seedLists(db, const ['1', '2', '3', '9']);
  await _seedSection(db, 'sec-1', '1');
  final repository = TaskRepository(db, queue);
  final created = await repository.create(listId: '1', title: '拖进清单的任务');
  await repository.update(created.id, dueAt: _due, sectionId: 'sec-1');
  return _reload(db, created.id);
}

Future<TodoTask> _reload(AppDatabase db, String id) async {
  return await (db.select(
    db.todoTasks,
  )..where((row) => row.id.equals(id))).getSingle();
}

/// 看得见的写库顺序 + 可控的 gate/失败，用来验串行与过期抑制。
class _ScriptedRepository extends TaskRepository {
  _ScriptedRepository(super.db, super.queue);

  final List<String> writtenTargets = [];
  Completer<void>? gate;
  bool failNext = false;

  @override
  Future<TodoTask> update(
    String taskId, {
    String? title,
    String? description,
    int? priority,
    DateTime? startAt,
    DateTime? endAt,
    bool clearStartAt = false,
    bool clearEndAt = false,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? allDay,
    String? timeZone,
    bool? fixedTimezone,
    String? listId,
    String? sectionId,
    bool clearSectionId = false,
    bool? isPinned,
  }) async {
    if (listId != null) writtenTargets.add(listId);
    final pending = gate;
    if (pending != null) {
      gate = null;
      await pending.future;
    }
    if (failNext) {
      failNext = false;
      throw Exception('落库失败');
    }
    return super.update(
      taskId,
      title: title,
      description: description,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      clearStartAt: clearStartAt,
      clearEndAt: clearEndAt,
      dueAt: dueAt,
      clearDueAt: clearDueAt,
      allDay: allDay,
      timeZone: timeZone,
      fixedTimezone: fixedTimezone,
      listId: listId,
      sectionId: sectionId,
      clearSectionId: clearSectionId,
      isPinned: isPinned,
    );
  }
}

void main() {
  testWidgets('拖入清单详情区域：换所属清单、时间安排不变、分组清空、登记 outbox', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await _seedTask(db, queue);
    final repository = TaskRepository(db, queue);
    final controller = TaskListMoveController(
      repositoryOf: () => repository,
      currentListIdOf: () => '2',
      onFailure: (_) {},
    );
    Future<bool>? pending;

    await tester.pumpWidget(
      _harness(
        task: task,
        viewListId: '2',
        onAccept: (dropped) => pending = controller.handleDrop(dropped),
      ),
    );
    expect(pending, isNull, reason: '没拖之前不该有写入');

    await _dragOntoTarget(tester);

    expect(pending, isNotNull, reason: '落点没被命中 ⇒ 这一面等于没接线');
    await pending;

    final row = await _reload(db, task.id);
    expect(row.listId, '2');
    expect(row.dueAt, _due, reason: '`:55` 要保留原有的时间安排');
    expect(row.sectionId, isNull, reason: '分组属于原清单，跨清单后不能留');
    expect((await db.select(db.todoSyncChanges).get()), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('任务本来就在当前清单里：落点不接受，也不写库', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await _seedTask(db, queue);
    final repository = TaskRepository(db, queue);
    final controller = TaskListMoveController(
      repositoryOf: () => repository,
      currentListIdOf: () => '1',
      onFailure: (_) {},
    );
    var accepted = 0;

    await tester.pumpWidget(
      _harness(
        task: task,
        viewListId: '1',
        onAccept: (dropped) {
          accepted++;
          controller.handleDrop(dropped);
        },
      ),
    );
    await _dragOntoTarget(tester);
    await tester.pumpAndSettle();

    expect(accepted, 0, reason: '同清单不构成一次迁移');
    expect((await _reload(db, task.id)).listId, '1');
  });

  testWidgets('320px + 1.3 倍字号下落点仍自带读屏语义，且不溢出', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final task = await _seedTask(db, SyncChangeQueue(db));

    await tester.pumpWidget(
      _harness(
        task: task,
        viewListId: '2',
        onAccept: (_) {},
        width: 320,
        textScale: 1.3,
      ),
    );

    // 钉的是带 key 那个节点自己的 label，不是全树随便一个同名 Text。
    final node = tester.getSemantics(find.byKey(TaskListDropTarget.zoneKey));
    expect(node.label, contains(TaskListDropTarget.zoneLabel));

    await _dragOntoTarget(tester);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '高亮态也不该在窄屏撑爆');
    final box = tester.renderObject<RenderBox>(
      find.byKey(TaskListDropTarget.zoneKey),
    );
    expect(box.size.width, lessThanOrEqualTo(320));
  });

  test('仓储不可用：给可见反馈，并且不动本地数据（任务还在原清单）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await _seedTask(db, queue);
    final failures = <String>[];
    final controller = TaskListMoveController(
      repositoryOf: () => null,
      currentListIdOf: () => '2',
      onFailure: failures.add,
    );

    expect(await controller.handleDrop(task), isFalse);
    expect(failures, [TaskListMoveController.failureMessage]);
    expect((await _reload(db, task.id)).listId, '1', reason: '失败要保留已加载的数据');
  });

  test('落库期间清单被切走：旧目标的失败提示不盖新界面', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await _seedTask(db, queue);
    final gate = Completer<void>();
    final repository = _ScriptedRepository(db, queue)
      ..gate = gate
      ..failNext = true;
    var viewListId = '2';
    final failures = <String>[];
    final controller = TaskListMoveController(
      repositoryOf: () => repository,
      currentListIdOf: () => viewListId,
      onFailure: failures.add,
    );

    final started = controller.handleDrop(task);
    await Future<void>.delayed(Duration.zero);
    // 写入还堵在 gate 上，此时用户切到别的清单 ⇒ 放开后落库失败，提示要被抑制。
    viewListId = '3';
    gate.complete();
    expect(await started, isTrue);
    expect(failures, isEmpty, reason: '过期的失败反馈不该弹给用户');
    expect((await _reload(db, task.id)).listId, '1', reason: '失败的写入不落库');
  });

  test('同一任务连着两次落点按先后串行，后一次不插队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await _seedTask(db, queue);
    final repository = _ScriptedRepository(db, queue);
    var viewListId = '2';
    final controller = TaskListMoveController(
      repositoryOf: () => repository,
      currentListIdOf: () => viewListId,
      onFailure: (_) {},
    );

    // 第一刀堵在 gate 上：'2' 已进入写库。
    final firstGate = Completer<void>();
    repository.gate = firstGate;
    final first = controller.handleDrop(task);
    await Future<void>.delayed(Duration.zero);
    expect(repository.writtenTargets, ['2'], reason: '第一刀该已进入写库');

    // 清单切到 '3' 再落一次：串行必须把它挡在第一刀之后，而不是插队。
    viewListId = '3';
    final second = controller.handleDrop(task);
    await Future<void>.delayed(Duration.zero);
    expect(repository.writtenTargets, [
      '2',
    ], reason: '没有串行的话第二刀会立刻插进写库，这里必须还是只有 1 条');

    firstGate.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(repository.writtenTargets, ['2', '3'], reason: '落库顺序要等于落点顺序');
    expect((await _reload(db, task.id)).listId, '3');
  });
}
