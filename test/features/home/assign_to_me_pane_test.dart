import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/drift.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/104：选中「指派给我」时任务面板只列分配给我的任务。
void main() {
  Finder emptyState() => find.descendant(
    of: find.byType(TasksByListPage),
    matching: find.text('暂无任务'),
  );

  Future<TodoVisualFixture> pumpShell(WidgetTester tester) async {
    return pumpTodoVisualScenario(
      tester,
      viewport: const Size(1400, 1000),
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (database) => [
        sessionProvider.overrideWith(() => _SessionWith(7)),
      ],
      child: const Material(child: HomeShell()),
    );
  }

  Future<void> assignAll(AppDatabase db, int userId) => (db.update(
    db.todoTasks,
  )).write(TodoTasksCompanion(assigneeUserId: Value(userId)));

  Future<void> assignOne(AppDatabase db, String taskId, int userId) =>
      (db.update(db.todoTasks)..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(assigneeUserId: Value(userId)),
      );

  Future<void> selectAssign(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-sidebar-row-assignToMe')));
    await tester.pumpAndSettle();
  }

  testWidgets('全是别人的任务 ⇒ 面板空；把一条改派给我 ⇒ 立刻不空', (tester) async {
    final fixture = await pumpShell(tester);
    // FL #559：这一档现在还要「所在清单是**共享的**」（嘀嗒 :21）。
    // 把 fixture 的清单标成共享，否则这里测的就变成"个人清单里的自指派" ——
    // 那是**另一条**判据（本文件下面那条专门测它），会把这条用例的意思换掉。
    await fixture.database
        .update(fixture.database.todoLists)
        .write(const TodoListsCompanion(memberCount: Value(2)));
    await assignAll(fixture.database, 8);
    await tester.pumpAndSettle();

    await selectAssign(tester);
    expect(
      emptyState(),
      findsOneWidget,
      reason: 'assignee 全是 8 ⇒ 「指派给我」不该列出任何任务',
    );

    // 把这条任务挪进一个**真实清单**：`inbox` 是合成清单、库里没有它的行，
    // 而"共享"只能由清单行上的 `memberCount` 表达 ⇒ 收集箱里的任务永远不满足这一档
    // （也符合原意：收集箱是个人空间，不是"来自不同共享清单"）。
    await (fixture.database.update(
      fixture.database.todoTasks,
    )..where((t) => t.id.equals(TodoVisualFixture.pinnedTaskId))).write(
      TodoTasksCompanion(listId: Value(TodoVisualFixture.personalListId)),
    );
    await assignOne(fixture.database, TodoVisualFixture.pinnedTaskId, 7);
    await tester.pumpAndSettle();

    expect(
      emptyState(),
      findsNothing,
      reason: '改成"有一条是我的"后还空 ⇒ 上面的空态是别的原因造成的，判据不成立',
    );
  });

  testWidgets('反向对照：同一次数据状态下「全部」不空、「指派给我」空', (tester) async {
    final fixture = await pumpShell(tester);
    await assignAll(fixture.database, 8);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-sidebar-row-all')));
    await tester.pumpAndSettle();
    expect(emptyState(), findsNothing, reason: '前提：任务面板本身是活的，空态只可能来自指派过滤');

    await selectAssign(tester);
    expect(emptyState(), findsOneWidget);
  });

  testWidgets('面板标题用嘀嗒术语「指派给我」', (tester) async {
    await pumpShell(tester);
    await selectAssign(tester);

    expect(find.text('指派给我'), findsWidgets);
  });
  // 交叉验证推翻掉的初版设计（"把身份塞进 initialFilter"）留下的判据：
  // 过滤器「全部」档换成空 TaskFilter，页面身份必须照样生效。
  test('lockedAssigneeUserId 是硬闸门：空滤镜也清不掉它', () {
    final tasks = [_task('mine', 7), _task('other', 8), _task('free', null)];

    final filtered = applyTaskFilter(
      tasks,
      TaskFilter(),
      null,
      DateTime(2026, 7, 30),
      lockedAssigneeUserId: 7,
    );

    expect(filtered.map((row) => row.id).toList(), ['mine']);
  });

  // FL #559：嘀嗒《02-用清单管理任务》:21「收集**来自不同共享清单**中分配给你的任务」。
  // 只按负责人取数，会把"我在**自己个人清单**里把自己选成执行人"也收进来 ——
  // 那不是别人分给我的活。
  test('「指派给我」还要叠一层「清单是共享的」：个人清单里的自指派不出现', () {
    final tasks = [_task('mine', 7)];

    expect(
      applyTaskFilter(
        tasks,
        TaskFilter(),
        null,
        DateTime(2026, 7, 30),
        lockedAssigneeUserId: 7,
        sharedListIds: const <String>{}, // 没有共享清单
      ),
      isEmpty,
      reason: '判据不能只看 assigneeUserId —— 那是"指派给我"这几个字的一半',
    );
  });

  test('共享清单里的指派出现；共享索引没就位（null）时放行', () {
    final tasks = [_task('mine', 7)];

    expect(
      applyTaskFilter(
        tasks,
        TaskFilter(),
        null,
        DateTime(2026, 7, 30),
        lockedAssigneeUserId: 7,
        sharedListIds: const <String>{'inbox'},
      ).map((row) => row.id).toList(),
      ['mine'],
    );

    // null = 共享清单索引还没就位 ⇒ **不加这道闸门**。
    // 取舍：多显示几条是"看得见的错"，少显示是"看不见的错"（用户不知道任务被吞了）。
    expect(
      applyTaskFilter(
        tasks,
        TaskFilter(),
        null,
        DateTime(2026, 7, 30),
        lockedAssigneeUserId: 7,
      ).map((row) => row.id).toList(),
      ['mine'],
    );
  });

  test('不传这一档时求值行为不变（其它智能清单不受影响）', () {
    final tasks = [_task('mine', 7), _task('other', 8)];

    expect(
      applyTaskFilter(tasks, TaskFilter(), null, DateTime(2026, 7, 30)).length,
      2,
    );
  });
}

TodoTask _task(String id, int? assigneeUserId) {
  final stamp = DateTime(2026, 7, 1);
  return TodoTask(
    id: id,
    listId: 'inbox',
    title: id,
    completed: false,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: null,
    allDay: false,
    timeZone: null,
    fixedTimezone: false,
    timeMode: TaskTimeMode.floating.wire,
    assigneeUserId: assigneeUserId,
    updatedAt: stamp,
    createdAt: stamp,
  );
}

class _SessionWith extends SessionController {
  _SessionWith(this.userId);

  final int userId;

  @override
  TodoAuthSession? build() => TodoAuthSession(
    userId: userId,
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    tenantId: '1',
    mobile: '13800000000',
  );
}
