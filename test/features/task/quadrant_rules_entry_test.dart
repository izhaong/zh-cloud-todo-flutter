import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/quadrant/quadrant_rules_page.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《03-四象限/02-如何编辑四象限规则》：四象限页面右上角「...」里选「编辑」进规则页。
/// `QuadrantRulesPage` 早就实现完整，但全库没有任何导航指向它 ⇒ 本轮补入口。
void main() {
  Future<void> openSortMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('入口只在四象限视图出现，列表视图的「...」里没有它', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    await openSortMenu(tester);
    expect(
      find.text('编辑象限规则'),
      findsNothing,
      reason: '列表视图没有象限规则可编辑，动作不能常驻在共用菜单里',
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _switchMode(tester, TaskViewMode.eisenhower);
    await openSortMenu(tester);
    expect(find.text('编辑象限规则'), findsOneWidget, reason: '嘀嗒的象限规则入口在四象限页面右上角');
  });

  testWidgets('点入口进入规则页，返回仍停在四象限视图', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );
    await _switchMode(tester, TaskViewMode.eisenhower);

    await openSortMenu(tester);
    await tester.tap(find.text('编辑象限规则'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrantRulesPage), findsOneWidget);
    expect(find.text('四象限规则'), findsOneWidget);
    // 夹具的 apiClient 是 `_NoNetworkApiClient` ⇒ 取数必然失败。
    // 这里要的是「说清楚失败了」，不是伪装成空列表或一片空白。
    expect(find.textContaining('规则加载失败'), findsOneWidget);
    expect(find.text('还没有四象限规则'), findsNothing, reason: '读失败不能伪装成「一条规则都没有」的空态');
    expect(find.text('重试'), findsOneWidget);

    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(QuadrantRulesPage), findsNothing);
    expect(
      find.byType(EisenhowerView),
      findsOneWidget,
      reason: '入口挂在四象限视图上，看完规则要回到原视图而不是丢状态',
    );
  });

  testWidgets('320px + 1.3 倍字体：档位进到被 push 出来的规则页自己身上且不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTodoVisualScenario(
      tester,
      viewport: const Size(320, 720),
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );
    await _switchMode(tester, TaskViewMode.eisenhower);

    await openSortMenu(tester);
    await tester.tap(find.text('编辑象限规则'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrantRulesPage), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('四象限规则'))).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传进 push 出来的路由就等于整条用例在 1.0 上排版',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('入口与规则页标题各是独立可读屏节点', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );
      await _switchMode(tester, TaskViewMode.eisenhower);

      await openSortMenu(tester);
      expect(
        find.bySemanticsLabel(RegExp('编辑象限规则')),
        findsOneWidget,
        reason: '菜单项只有文字没有语义名字时，读屏念不出这是干什么的',
      );
      await tester.tap(find.text('编辑象限规则'));
      await tester.pumpAndSettle();

      final titleNode = tester.getSemantics(find.text('四象限规则'));
      expect(titleNode.label, contains('四象限规则'));
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _switchMode(WidgetTester tester, TaskViewMode mode) async {
  await tester.tap(find.byKey(const Key('todo-view-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode.label).last);
  await tester.pumpAndSettle();
}
