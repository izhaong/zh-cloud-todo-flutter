import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/105 / FL #339：侧栏清单行行首渲染「Emoji 图标」。
///
/// 嘀嗒《02-用清单管理任务.md》:86 图标会出现在清单名前面；没设 Emoji 的
/// 清单仍回退默认 mutedForeground 图标（语义不变）。
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

Finder _rowEmoji(String listId) => find.descendant(
  of: find.byKey(ValueKey('todo-sidebar-list-$listId')),
  matching: find.text('📌'),
);

Finder _rowIcon(String listId) => find.descendant(
  of: find.byKey(ValueKey('todo-sidebar-list-$listId')),
  matching: find.byIcon(Icons.list_alt_outlined),
);

/// 侧栏是懒渲染 ListView：清单行不在构建窗口里就找不到（红在判据自己）。
Future<void> revealRow(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 120, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('有 Emoji 的清单：行首显示 Emoji 而不是默认图标', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
    final updated =
        await (fixture.database.update(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.personalListId)))
            .write(const TodoListsCompanion(icon: Value('📌')));
    expect(updated, 1, reason: '前提：先给清单设图标');
    await tester.pumpAndSettle();
    await revealRow(tester, _rowEmoji(TodoVisualFixture.personalListId));

    expect(_rowEmoji(TodoVisualFixture.personalListId), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
        ),
        matching: find.byIcon(Icons.list_alt_outlined),
      ),
      findsNothing,
      reason: '设了 Emoji 就不再渲染默认清单图标',
    );
  });

  testWidgets('无 Emoji 的清单：仍是默认图标，不凭空多出 Emoji 文本', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
    );
    await tester.pumpAndSettle();
    // personalList 行的默认图标路径与 sidebar_list_color_test 同一配方（可滚到位）。
    await revealRow(tester, _rowIcon(TodoVisualFixture.personalListId));

    expect(_rowIcon(TodoVisualFixture.personalListId), findsOneWidget);
    expect(find.text('📌'), findsNothing);
  });
}
