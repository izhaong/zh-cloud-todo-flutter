import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/102 / FL Issue #339：侧栏清单行把「颜色」渲染在行首图标上。
///
/// 嘀嗒《02-用清单管理任务.md》:73 清单属性有「颜色」；有色的清单行
/// 图标着该色，无色回退默认 mutedForeground。
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

Finder _rowIcon(String listId) => find.descendant(
  of: find.byKey(ValueKey('todo-sidebar-list-$listId')),
  matching: find.byIcon(Icons.list_alt_outlined),
);

void main() {
  testWidgets('有色清单：行首图标着成清单色', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
    final rows =
        await (fixture.database.update(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.personalListId)))
            .write(const TodoListsCompanion(color: Value('#4772FA')));
    expect(rows, 1, reason: '前提：先给清单上色');
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      _rowIcon(TodoVisualFixture.personalListId),
    );
    expect(
      icon.color,
      const Color(0xFF4772FA),
      reason: '行首图标要着清单色，颜色属性不能只在库里看不见',
    );
  });

  testWidgets('无色清单：回退默认 mutedForeground；上色前后肉眼可分', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
    final before = tester
        .widget<Icon>(_rowIcon(TodoVisualFixture.personalListId))
        .color;
    expect(
      before,
      AppColors.light.mutedForeground,
      reason: '无色回退默认 mutedForeground（与选中色/品牌色无关）',
    );

    final rows =
        await (fixture.database.update(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.personalListId)))
            .write(const TodoListsCompanion(color: Value('#4772FA')));
    expect(rows, 1, reason: '前提：先给清单上色');
    await tester.pumpAndSettle();

    final after = tester
        .widget<Icon>(_rowIcon(TodoVisualFixture.personalListId))
        .color;
    expect(after, const Color(0xFF4772FA));
    expect(after, isNot(before), reason: '有色与无色必须肉眼可分');
  });
}
