import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/103：侧栏智能清单行按「显示 / 隐藏 / 有内容时显示」三态渲染。
///
/// 嘀嗒《02-用清单管理任务.md》:45 三态、:29 侧栏「添加清单」右边的「设置」入口。
void main() {
  const rowNames = [
    'inbox',
    'today',
    'tomorrow',
    'upcoming',
    'all',
    'completed',
    'trash',
  ];

  Finder row(String name) => find.byKey(Key('todo-sidebar-row-$name'));

  Future<TodoVisualFixture> pumpSidebar(
    WidgetTester tester, {
    TodoVisualFixtureSet set = TodoVisualFixtureSet.populated,
  }) {
    return pumpTodoVisualScenario(
      tester,
      viewport: const Size(320, 900),
      fixtureSet: set,
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
  }

  Future<void> saveState(
    WidgetTester tester,
    TodoVisualFixture fixture,
    String name,
    SmartListVisibility state,
  ) async {
    await SidebarVisibilityRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).saveSmartListState(name, state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('默认七行全在：没设置过时侧栏与现状一致（黄金基线不动）', (tester) async {
    await pumpSidebar(tester);

    for (final name in rowNames) {
      expect(row(name), findsOneWidget, reason: '默认应显示 $name');
    }
  });

  testWidgets('存「隐藏」的行消失、其余仍在', (tester) async {
    final fixture = await pumpSidebar(tester);

    await saveState(tester, fixture, 'today', SmartListVisibility.hide);

    expect(row('today'), findsNothing, reason: '隐藏的智能清单行不该再渲染');
    expect(row('inbox'), findsOneWidget, reason: '只藏今天，别的行不许被连坐');
    expect(row('tomorrow'), findsOneWidget);
  });

  testWidgets('「有内容时显示」：空库没有内容 ⇒ 行不出', (tester) async {
    final fixture = await pumpSidebar(tester, set: TodoVisualFixtureSet.empty);

    await saveState(tester, fixture, 'tomorrow', SmartListVisibility.auto);

    expect(row('tomorrow'), findsNothing, reason: '没内容时「有内容时显示」= 藏');
    expect(row('inbox'), findsOneWidget, reason: '收集箱守卫：管理页写不进 hide/auto，行恒在');
  });

  testWidgets('「有内容时显示」：有明天任务 ⇒ 行在（内容判定与徽章同一份计数）', (tester) async {
    final fixture = await pumpSidebar(tester);

    await saveState(tester, fixture, 'tomorrow', SmartListVisibility.auto);

    expect(
      row('tomorrow'),
      findsOneWidget,
      reason: 'populated fixture 有明天到期的任务',
    );
  });

  testWidgets('设置入口点开「智能清单管理」弹层', (tester) async {
    await pumpSidebar(tester);

    await tester.tap(find.byKey(const Key('todo-sidebar-smart-list-manager')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-smart-list-manager-sheet')),
      findsOneWidget,
      reason: '嘀嗒 :29「添加清单」右边的「设置」要能打开管理页',
    );
    expect(find.text('智能清单管理'), findsOneWidget);
  });
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
