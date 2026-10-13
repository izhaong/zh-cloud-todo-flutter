import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/folder/folder_page.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/126 / 矩阵 #18 面①：文件夹的建·改·删整页此前**不可达**——
/// `FolderPage` 唯一入口在零挂载的 `ListPage` 里。嘀嗒《01-任务/09-如何管理海量任务/01-用文件夹管理任务.md》
/// 要求「创建文件夹/解散文件夹」这一面用户走得到，代码存在但不达不算「有」。
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

Future<TodoVisualFixture> _pump(WidgetTester tester) async {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Future<void> _openActionsSheet(WidgetTester tester) async {
  final row = find.byKey(
    ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
  );
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.longPress(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('清单动作表里有「文件夹管理」这一档', (tester) async {
    await _pump(tester);
    await _openActionsSheet(tester);

    expect(
      find.byKey(const Key('sidebar-list-action-folders')),
      findsOneWidget,
      reason: '面①要求用户走得到文件夹管理，入口必须挂在已达成的动作表里',
    );
  });

  testWidgets('点「文件夹管理」真的渲染出 FolderPage（不是空转）', (tester) async {
    await _pump(tester);
    await _openActionsSheet(tester);
    expect(find.byType(FolderPage), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar-list-action-folders')));
    await tester.pumpAndSettle();

    expect(find.byType(FolderPage), findsOneWidget);
    expect(
      find.byTooltip('新建文件夹'),
      findsOneWidget,
      reason: '嘀嗒方式里的「创建文件夹」要在这页里可达',
    );
  });

  testWidgets('从这页新建的文件夹落进本地库', (tester) async {
    final fixture = await _pump(tester);
    await _openActionsSheet(tester);
    await tester.tap(find.byKey(const Key('sidebar-list-action-folders')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工作区');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final stored = await fixture.database
        .select(fixture.database.todoFolders)
        .get();
    expect(
      stored.map((row) => row.name),
      contains('工作区'),
      reason: '页面上的「新建」若没落库，矩阵 #18 面① 仍然缺',
    );
    expect(fixture.container.read(folderRepositoryProvider), isNotNull);
  });
}
