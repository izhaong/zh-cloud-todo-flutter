import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/100 智能分组：嘀嗒《03-用分组和排序管理任务》六维档位在任务列表页的接线测试。
///
/// 判定口径：
/// - 头部「智能分组」菜单列出嘀嗒的全部档位，文案与嘀嗒小节标题逐字一致；
/// - 选中后组头用嘀嗒的桶名（时间/优先级/标签），多标签任务在每个标签组各出现一次；
/// - 分组偏好按清单持久化：重新挂载页面（同一容器）后不点任何东西就恢复；
/// - 320px + 1.3 倍字号下打开菜单并切档不溢出。
void main() {
  testWidgets('分组菜单列出嘀嗒七档，选中「按时间分组」后组头用嘀嗒桶名', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture);

    await openGroupingMenu(tester);
    expect(find.text('不分组'), findsOneWidget);
    expect(find.text('按清单分组'), findsOneWidget);
    expect(find.text('按时间分组'), findsOneWidget);
    expect(find.text('按优先级分组'), findsOneWidget);
    expect(find.text('按标签分组'), findsOneWidget);
    expect(find.text('按指派人分组'), findsOneWidget);
    expect(find.text('按创建时间分组'), findsOneWidget);

    await tester.tap(find.text('按时间分组').last);
    await tester.pumpAndSettle();
    // 组头按 key 断言：任务行自己的到期徽标也叫「明天」，裸文本会撞车。
    expect(find.byKey(const Key('todo-task-group-time-今天')), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-time-明天')), findsOneWidget);
    expect(
      find.byKey(const Key('todo-task-group-time-最近 7 天')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('todo-task-group-time-无日期')), findsOneWidget);
  });

  testWidgets('按优先级分组：四个组头齐全，最高优先级任务落在「高优先级」组', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture);

    await selectGrouping(tester, '按优先级分组');
    expect(find.text('高优先级'), findsOneWidget);
    expect(find.text('中优先级'), findsOneWidget);
    expect(find.text('低优先级'), findsOneWidget);
    expect(find.text('无优先级'), findsOneWidget);
    // 夹具里唯一的 priority=3 任务（置顶的「确定今天最重要的三件事」）必须在高优先级组。
    expect(find.text('确定今天最重要的三件事'), findsOneWidget);
  });

  testWidgets('按标签分组：多标签任务在每个标签组各出现一次', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    // 夹具 inbox 有 13 条任务 + 5 个组头，普通视口是懒加载列表、底部组不 build；
    // 用超高视口把所有组都拉出来，才能数「每组各一次」。
    await pumpPage(tester, fixture, viewport: const Size(1280, 3200));

    await selectGrouping(tester, '按标签分组');
    // 「准备项目周会材料」挂了 专注/评审/跟进 三个标签，应在三个组里各渲染一次。
    expect(find.byKey(const Key('todo-task-group-tag-专注')), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-tag-评审')), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-tag-跟进')), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-tag-协作')), findsOneWidget);
    expect(find.byKey(const Key('todo-task-group-tag-none')), findsOneWidget);
    expect(find.text('准备项目周会材料'), findsNWidgets(3));
  });

  testWidgets('按指派人分组：夹具全部无执行人，只有「无指派人」一个组', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture);

    await selectGrouping(tester, '按指派人分组');
    expect(find.text('无指派人'), findsOneWidget);
    expect(find.text('确定今天最重要的三件事'), findsOneWidget);
  });

  testWidgets('分组偏好按清单持久化：重挂载页面后不点任何东西就恢复', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture);

    await selectGrouping(tester, '按优先级分组');
    expect(find.text('高优先级'), findsOneWidget);

    // 卸载整棵树再重挂（同一个 ProviderContainer / 数据库）。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await pumpPage(tester, fixture);
    await tester.pumpAndSettle();

    expect(find.text('高优先级'), findsOneWidget, reason: '重挂载后偏好没恢复，说明没落库或没读回');
    // 菜单里当前档位要打勾；check 图标在任务行里也有，认它专属的 semanticLabel
    // 「当前分组」（读屏读的就是这个属性）。
    await openGroupingMenu(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == '当前分组',
      ),
      findsOneWidget,
    );
  });

  testWidgets('320px + 1.3 倍字号：开菜单、切档、看组头都不溢出', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture, narrowWithLargeText: true);

    await selectGrouping(tester, '按标签分组');
    expect(tester.takeException(), isNull);
    expect(find.text('评审'), findsOneWidget);

    // 读屏：菜单项文案可定位，勾选项带专属 semanticLabel「当前分组」。
    await openGroupingMenu(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-grouping-byPriority')),
        matching: find.text('按优先级分组'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == '当前分组',
      ),
      findsOneWidget,
    );
  });
}

Future<void> pumpPage(
  WidgetTester tester,
  TodoVisualFixture fixture, {
  bool narrowWithLargeText = false,
  Size? viewport,
}) async {
  tester.view.physicalSize = narrowWithLargeText
      ? const Size(320, 844)
      : (viewport ?? TodoVisualViewports.wide);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        builder: narrowWithLargeText
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child ?? const SizedBox.shrink(),
              )
            : null,
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: TasksByListPage(
            initialListId: TodoVisualFixture.inboxListId,
            lockedListId: true,
            hideAppBar: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> openGroupingMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-grouping-menu')));
  await tester.pumpAndSettle();
}

Future<void> selectGrouping(WidgetTester tester, String label) async {
  await openGroupingMenu(tester);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
