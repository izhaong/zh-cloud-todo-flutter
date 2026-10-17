import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/drift.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/104：侧栏「指派给我」行与术语对齐（嘀嗒《02-用清单管理任务.md》:16）。
void main() {
  Finder assignRow() => find.byKey(const Key('todo-sidebar-row-assignToMe'));

  Future<TodoVisualFixture> pumpSidebar(
    WidgetTester tester, {
    int? userId = 7,
    TodoVisualFixtureSet set = TodoVisualFixtureSet.populated,
  }) {
    return pumpTodoVisualScenario(
      tester,
      viewport: const Size(320, 900),
      fixtureSet: set,
      overridesBuilder: (database) => [
        if (userId != null)
          sessionProvider.overrideWith(() => _SessionWith(userId)),
      ],
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
  }

  Future<void> assign(AppDatabase db, List<String> taskIds, int? userId) async {
    await (db.update(db.todoTasks)..where((row) => row.id.isIn(taskIds))).write(
      TodoTasksCompanion(assigneeUserId: Value(userId)),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('有会话时侧栏出现「指派给我」行，徽章是本人未完成任务数', (tester) async {
    final fixture = await pumpSidebar(tester);
    await settle(tester);

    expect(assignRow(), findsOneWidget, reason: '嘀嗒 :16 点名的五个智能清单之一');
    // 前提：库里本来没有指派记录 ⇒ 徽章不该出现
    expect(
      find.descendant(of: assignRow(), matching: find.text('2')),
      findsNothing,
      reason: '未指派时不该有徽章',
    );

    // FL #559：徽章与「指派给我」那一页**同一判据**（共享清单 + 指派给我）。
    // 把 fixture 的清单标成共享，并把这两条挪进**真实清单** —— `inbox` 是合成清单、
    // 库里没有它的行，"共享"只能由清单行上的 `memberCount` 表达。
    await fixture.database
        .update(fixture.database.todoLists)
        .write(const TodoListsCompanion(memberCount: Value(2)));
    await (fixture.database.update(fixture.database.todoTasks)..where(
          (t) => t.id.isIn([
            TodoVisualFixture.pinnedTaskId,
            TodoVisualFixture.todayTaskId,
          ]),
        ))
        .write(
          TodoTasksCompanion(listId: Value(TodoVisualFixture.personalListId)),
        );
    await assign(fixture.database, [
      TodoVisualFixture.pinnedTaskId,
      TodoVisualFixture.todayTaskId,
    ], 7);
    await settle(tester);

    expect(
      find.descendant(of: assignRow(), matching: find.text('2')),
      findsOneWidget,
      reason: '两条指派给我的任务 ⇒ 徽章 2',
    );
  });

  testWidgets('别人的指派不给我计数', (tester) async {
    final fixture = await pumpSidebar(tester);
    await assign(fixture.database, [TodoVisualFixture.pinnedTaskId], 8);
    await settle(tester);

    expect(
      find.descendant(of: assignRow(), matching: find.text('1')),
      findsNothing,
      reason: 'assignee 是别人的任务不该挂到我的徽章上',
    );
  });

  testWidgets('没有会话时该行仍在但不计数', (tester) async {
    await pumpSidebar(tester, userId: null);
    await settle(tester);

    expect(assignRow(), findsOneWidget);
    expect(
      find.descendant(of: assignRow(), matching: find.text('1')),
      findsNothing,
    );
  });

  testWidgets('三态跟着走：存「隐藏」就没有这一行（specs/103 同一通道）', (tester) async {
    final fixture = await pumpSidebar(tester);
    expect(assignRow(), findsOneWidget);

    await SidebarVisibilityRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).saveSmartListState(SmartList.assignToMe.name, SmartListVisibility.hide);
    await settle(tester);

    expect(assignRow(), findsNothing, reason: '新行必须一并接进三态渲染');
  });

  testWidgets('术语照抄嘀嗒：「最近七天」在、「未来7天」不再出现', (tester) async {
    await pumpSidebar(tester);
    await settle(tester);

    expect(find.text('最近七天'), findsOneWidget, reason: '嘀嗒 :16 用「最近七天」');
    expect(find.text('未来7天'), findsNothing, reason: '旧文案还挂在界面上就是没改干净');
  });
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

class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Sidebar(
        selectedSection: Section.tasks,
        selectedSmart: SmartList.inbox,
        selectedListId: null,
        onSelectSection: _noopSection,
        onSelectSmart: _noopSmart,
        onSelectList: _noopList,
        onOpenTags: _noopVoid,
        onOpenFilters: _noopVoid,
        onOpenSettings: _noopVoid,
        onOpenPomodoro: _noopVoid,
        onOpenHabit: _noopVoid,
        onOpenCountdown: _noopVoid,
      ),
    );
  }
}

void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
void _noopVoid() {}
