import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/026 侧栏清单管理入口：嘀嗒把「编辑 / 删除」放在清单行的手势里，
/// 而不是一个只有新建能到达的独立管理页。
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

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  Size? viewport,
  double textScale = 1,
}) async {
  // 字体档位打在 platformDispatcher 上：动作表是 root Navigator 上的路由，
  // 包在 home 子树里的 MediaQuery 到不了弹层，那样测出来永远是 1.0 倍。
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport ?? TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Future<void> _openActions(WidgetTester tester, String listId) async {
  final row = find.byKey(ValueKey('todo-sidebar-list-$listId'));
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.longPress(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('侧栏清单行长按给出「编辑 / 删除」两个动作', (tester) async {
    await _pump(tester);
    await _openActions(tester, TodoVisualFixture.personalListId);

    expect(
      find.byKey(const Key('sidebar-list-action-edit')),
      findsOneWidget,
      reason: '嘀嗒的清单动作表里「编辑」必须独立可点，而不是只有新建清单能进编辑器',
    );
    expect(find.byKey(const Key('sidebar-list-action-delete')), findsOneWidget);
  });

  testWidgets('侧栏清单长按改名后落库', (tester) async {
    final fixture = await _pump(tester);
    await _openActions(tester, TodoVisualFixture.personalListId);
    await tester.tap(find.byKey(const Key('sidebar-list-action-edit')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '清单名'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '改过的清单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final stored = await fixture.container
        .read(listRepositoryProvider)!
        .getAll();
    expect(
      stored
          .firstWhere((list) => list.id == TodoVisualFixture.personalListId)
          .name,
      '改过的清单名',
    );
  });

  testWidgets('侧栏删除无未完成内容的清单时二次确认，取消不写库', (tester) async {
    final fixture = await _pump(tester);
    // 自建一条空清单：固定「无未完成任务」这一分支，不依赖基线数据里各清单的任务数。
    final created = await fixture.container
        .read(listRepositoryProvider)!
        .create(name: '待删除空清单');
    await tester.pumpAndSettle();

    await _openActions(tester, created.id);
    await tester.tap(find.byKey(const Key('sidebar-list-action-delete')));
    await tester.pumpAndSettle();

    expect(find.text('删除清单'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final stored = await fixture.container
        .read(listRepositoryProvider)!
        .getAll();
    expect(
      stored.map((list) => list.id),
      contains(created.id),
      reason: '取消删除不得产生任何写入',
    );
    final changes = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(
      changes.where(
        (change) =>
            change.entity == 'list' &&
            change.op == 'delete' &&
            change.entityLocalId == created.id,
      ),
      isEmpty,
      reason: '取消删除连 outbox 都不该留下一条 delete',
    );
  });

  testWidgets('侧栏删除确认后移除清单并记 delete 变更', (tester) async {
    final fixture = await _pump(tester);
    await _openActions(tester, TodoVisualFixture.personalListId);
    await tester.tap(find.byKey(const Key('sidebar-list-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    final stored = await fixture.container
        .read(listRepositoryProvider)!
        .getAll();
    expect(
      stored.map((list) => list.id),
      isNot(contains(TodoVisualFixture.personalListId)),
    );
    final changes = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(
      changes.where(
        (change) =>
            change.entity == 'list' &&
            change.op == 'delete' &&
            change.entityLocalId == TodoVisualFixture.personalListId,
      ),
      hasLength(1),
    );
  });

  testWidgets('清单里有未完成任务时删除先拦截并给出条数', (tester) async {
    final fixture = await _pump(tester);
    final rows = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    // 钉在已知那条任务上：rows.first 的顺序不确定，靠它等于把前置条件交给运气。
    final target = rows.firstWhere(
      (row) => row.id == 'visual-task-personal-list',
    );
    await fixture.database
        .update(fixture.database.todoTasks)
        .replace(target.copyWith(listId: TodoVisualFixture.personalListId));

    await _openActions(tester, TodoVisualFixture.personalListId);
    await tester.tap(find.byKey(const Key('sidebar-list-action-delete')));
    await tester.pumpAndSettle();

    final open = await fixture.database.countOpenTasksByList(
      TodoVisualFixture.personalListId,
    );
    expect(open, greaterThan(0));
    expect(find.text('清单有未完成任务'), findsOneWidget);
    expect(find.textContaining('仍有 $open 项未完成'), findsOneWidget);
  });

  testWidgets('收集箱不出现清单动作入口', (tester) async {
    await _pump(tester);
    final inbox = find.byKey(const Key('todo-sidebar-row-inbox'));
    await tester.scrollUntilVisible(
      inbox,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(inbox);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-list-action-edit')), findsNothing);
    expect(find.byKey(const Key('sidebar-list-action-delete')), findsNothing);
  });

  testWidgets('320px 与 1.3 倍字体下动作表两项都在且不溢出', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, viewport: const Size(320, 700), textScale: 1.3);
    await _openActions(tester, TodoVisualFixture.personalListId);

    expect(find.byKey(const Key('sidebar-list-action-edit')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-list-action-delete')), findsOneWidget);
    expect(find.bySemanticsLabel('编辑'), findsWidgets);
    expect(find.bySemanticsLabel('删除'), findsWidgets);
    // 先证明 1.3 倍真的落到了弹层上，否则下面那句「不溢出」测的是 1.0 倍排版。
    final sheetContext = tester.element(
      find.byKey(const Key('sidebar-list-action-edit')),
    );
    expect(
      MediaQuery.textScalerOf(sheetContext).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传递到 root Navigator 上的路由时这里就会失败',
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
