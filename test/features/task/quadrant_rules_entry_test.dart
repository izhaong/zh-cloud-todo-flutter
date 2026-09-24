import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/quadrant/quadrant_rules_page.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《03-四象限/02-如何编辑四象限规则》：四象限页面右上角「...」里选「编辑」进规则页。
/// `QuadrantRulesPage` 早就实现完整，但全库没有任何导航指向它 ⇒ 本轮补入口。
void main() {
  Future<void> openSortMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('入口只在四象限视图出现，另四种视图的「...」里都没有它', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    for (final mode in const [
      TaskViewMode.kanban,
      TaskViewMode.timeline,
      TaskViewMode.calendar,
      TaskViewMode.list,
    ]) {
      await _switchMode(tester, mode);
      await openSortMenu(tester);
      // 正对照：先证明菜单真的展开了，否则下面的 findsNothing 是空转。
      expect(
        find.text('批量编辑'),
        findsOneWidget,
        reason: '${mode.label} 视图下菜单没打开，负向断言不成立',
      );
      expect(
        find.text('编辑象限规则'),
        findsNothing,
        reason: '象限规则只在四象限视图有意义，动作不能常驻共用菜单',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

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
    // 取数必然失败，但**不是**夹具的 `_NoNetworkApiClient` 拦的：`QuadrantApi` 拿的是
    // `apiClient.raw` 那个 Dio（`efficiency_providers.dart:21`、`efficiency_api.dart:496-502`），
    // 绕过了 ApiClient.get/post 的覆写，真正被拒的是 flutter_test 默认掐断的真实 socket。
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

  testWidgets('规则页的数据态列表与编辑器弹窗在 320px + 1.3 倍字体下排版不溢出', (tester) async {
    // 入口把这条路打开给手机之前，规则页只有桌面直链能到；现在它的排版归本切片负责。
    // 「有数据」态只能在这里造：夹具的 `overridesBuilder` 在 develop 上就有
    // （`test/support/todo_visual_fixture.dart:60`、`:90` 展开进 container），
    // 但 `pumpTodoVisualScenario` 没把它透传出来（`test/support/todo_visual_test_harness.dart:35`
    // 只传 `set:`）⇒ 走真实入口拿不到数据态。弹窗那半边不需要数据，由下一条用例在真实入口上验。
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quadrantRulesProvider.overrideWith(
            (ref) async => const [
              QuadrantRuleDto(
                id: 1,
                name: '按优先级分四象限',
                type: QuadrantRuleType.priorityTime,
                isDefault: true,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: QuadrantRulesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('按优先级分四象限'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('四象限规则'))).scale(10),
      closeTo(13, 0.001),
      reason: '这条用例自己泵页，档位没生效就等于整条在 1.0 上排版',
    );
    expect(tester.takeException(), isNull, reason: '窄屏 + 大字体下规则列表溢出');

    // 这条是 isExpanded 的**唯一可观测判据**（见探针 PD/PD2）：默认 `MaterialApp` 用的是测试字体
    // （Ahem，每个字符占满字号宽），摘掉 `isExpanded` 时这里溢出；下一条用例走生产主题 +
    // `TodoGoldenSans`，同样摘掉却不溢出 ⇒ 溢出量与字体度量绑定，不能报成生产口径的像素数。
    await tester.tap(find.byTooltip('新建规则'));
    await tester.pumpAndSettle();
    expect(find.text('新建四象限规则'), findsOneWidget);
    // 溢出才是判据。`AlertDialog` 自身盒子在 320px 下就是铺满 320（实测 getSize 返回 320.0），
    // 拿「弹窗宽度 < 屏宽」当断言是错的判据 —— 真正撑爆的是里面未按可用宽度收缩的下拉框选中项。
    expect(
      tester.takeException(),
      isNull,
      reason:
          '窄屏 + 大字体下编辑器弹窗溢出（`DropdownButtonFormField` 未 isExpanded 时选中项按内容撑宽）',
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

    // 弹窗不需要数据：`quadrant_rules_page.dart:20-24` 的 AppBar 动作无条件渲染，失败态下也在
    // ⇒ 这条证明**真实入口 + 生产主题**下打开编辑器弹窗不溢出（用的是 TodoGoldenSans 度量）。
    // 注意：它抓不到 `isExpanded`（探针 PD2 摘掉该行后这条仍绿），isExpanded 的判据在上一条用例里。
    await tester.tap(find.byTooltip('新建规则'));
    await tester.pumpAndSettle();
    expect(find.text('新建四象限规则'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '生产主题 + 真实入口下 320px/1.3 打开编辑器弹窗溢出',
    );
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
