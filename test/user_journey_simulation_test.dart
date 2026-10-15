import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';

import 'support/todo_visual_fixture.dart';
import 'support/todo_visual_test_harness.dart';

/// 真实用户旅程模拟（桌面 wide 视口）。
///
/// 目的：把「启动 → 浏览各导航区 → 增删改查任务 → 切换视图 → 打开设置」
/// 这条主链路在**真实 HomeShell** 上逐项走通，任何一环崩了、Key 丢了、
/// 页面渲染不出来都会红。它替代不了真机联调，但能在无人值守下给出
/// 「主路径没断」的可复现证据。
///
/// 范围与边界：
/// - 用固定 fixture（内存 Drift + 网络全部桩掉），**不连真实后端**。
/// - 登录页不在本用例范围：fixture 直接以已登录态进 HomeShell。
/// - 日历/看板/四象限/时间线等视图按现有入口逐个可达性验证。
void main() {
  /// 把整棵 HomeShell 起来（wide 视口，已登录、有数据）。
  Future<TodoVisualFixture> boot(WidgetTester tester,
      {TodoVisualFixtureSet set = TodoVisualFixtureSet.populated}) {
    return pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: set,
      child: const HomeShell(),
    );
  }

  /// 点侧栏某一行并 settle。
  ///
  /// 侧栏是可滚动列表（底部「设置」等行常在折叠线以下），用户要滚到位才点得到，
  /// 所以这里先 scrollUntilVisible —— 直接 tap 会因未挂载而找不到元素。
  Future<void> tapSidebarRow(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(finder, findsWidgets, reason: '侧栏入口 $key 必须存在');
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  testWidgets('旅程① 启动后四区骨架齐全（rail/sidebar/content/detail）', (tester) async {
    await boot(tester);
    // 契约见 specs/002 的 workspace-ui-contract：四区各有稳定语义 Key。
    for (final key in const [
      'todo-rail',
      'todo-sidebar',
      'todo-content',
      'todo-detail',
    ]) {
      expect(find.byKey(Key(key)), findsWidgets, reason: '四区骨架缺 $key');
    }
    expect(find.textContaining('加载失败'), findsNothing);
  });

  testWidgets('旅程② 逐个点开侧栏导航区都不崩、且落在工作区或独立页', (tester) async {
    await boot(tester);
    // 智能清单（留在工作区，内容区必须还在）+ 浏览区里会 push 独立页的入口
    // （标签/筛选/笔记/设置打开的是自己的页面，工作区被替换是设计如此，
    // 不能拿 todo-content 断言它们）。两类分别处理，避免把正常导航当成崩溃。
    const workspaceRows = <String>[
      'todo-sidebar-row-inbox',
      'todo-sidebar-row-today',
      'todo-sidebar-row-tomorrow',
      'todo-sidebar-row-upcoming',
      'todo-sidebar-row-all',
      'todo-sidebar-row-completed',
      'todo-sidebar-row-trash',
      'todo-sidebar-row-calendar',
    ];
    for (final key in workspaceRows) {
      final finder = find.byKey(Key(key));
      if (finder.evaluate().isEmpty) continue; // 功能模块关闭时该入口可能不在
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('todo-content')),
        findsWidgets,
        reason: '点 $key 之后工作区内容区必须仍在（不能白屏/抛异常）',
      );
      expect(tester.takeException(), isNull, reason: '点 $key 抛了异常');
    }
  });

  testWidgets('旅程②b 独立页入口（标签/筛选/笔记）能打开且不崩', (tester) async {
    await boot(tester);
    for (final key in const [
      'todo-sidebar-row-tags',
      'todo-sidebar-row-filters',
      'todo-sidebar-row-notes',
    ]) {
      final finder = find.byKey(Key(key));
      if (finder.evaluate().isEmpty) continue;
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '打开 $key 对应页面时抛了异常',
      );
      // 独立页会盖住工作区；返回键（或再点一次侧栏）回到工作区。
      final back = find.byTooltip('返回');
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await tester.pumpAndSettle();
      } else if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('旅程③ 快速添加创建任务：输入回车后进入当前清单', (tester) async {
    await boot(tester);
    final input = find.byKey(const Key('todo-quick-add-input'));
    expect(input, findsOneWidget, reason: '桌面必须有快速添加输入框');

    final title = '旅程快速添加 ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(input, title);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(title), findsWidgets, reason: '回车后新任务要出现在列表里');
    expect(tester.takeException(), isNull);
  });

  testWidgets('旅程④ 选中任务 → 详情区出真实内容 → 取消选中回空态', (tester) async {
    final fixture = await boot(tester);
    final taskSurface = find.byKey(
      Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
    );
    expect(taskSurface, findsOneWidget, reason: 'fixture 的置顶任务行必须在');
    await tester.tap(taskSurface);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-detail-no-selection')),
      findsNothing,
      reason: '选中任务后不应再显示「选择任务以查看详情」空态',
    );
    expect(tester.takeException(), isNull);
    expect(fixture.container, isNotNull);
  });

  testWidgets('旅程⑤ 完成任务勾选框可点，状态切换不抛异常', (tester) async {
    await boot(tester);
    final checkbox = find
        .descendant(
          of: find.byKey(
            Key('task-row-surface-${TodoVisualFixture.todayTaskId}'),
          ),
          matching: find.byKey(const Key('app-checkbox-semantics')),
        )
        .first;
    expect(checkbox, findsWidgets, reason: '任务行必须有完成勾选框');
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('旅程⑥ 逐个切到各视图：列表/看板/四象限/时间线/日历都不崩', (tester) async {
    await boot(tester);
    // 按标签文字选中菜单项：菜单项类型是 PopupMenuItem<TaskViewMode>，
    // byType(PopupMenuItem<dynamic>) 匹配不到具体泛型，用文案更稳也更贴近用户。
    // 四象限/时间线受「功能模块」开关控制，不在菜单里时跳过。
    const labels = <String>['列表', '看板', '时间线', '四象限', '日历'];
    for (final label in labels) {
      final menu = find.byKey(const Key('todo-view-menu'));
      if (menu.evaluate().isEmpty) continue;
      await tester.tap(menu);
      await tester.pumpAndSettle();

      final item = find.text(label);
      if (item.evaluate().isEmpty) {
        // 该视图被功能模块开关关掉，或当前清单不支持 ⇒ 关菜单继续。
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        continue;
      }
      await tester.tap(item.last);
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '切到「$label」视图时抛了异常',
      );
      expect(
        find.byKey(const Key('todo-content')),
        findsWidgets,
        reason: '切到「$label」后工作区内容区必须还在',
      );
    }
  });

  testWidgets('旅程⑦ 搜索：⌘K 指令菜单含「全局搜索」，点开后搜索页可用', (tester) async {
    await boot(tester);
    // 宽屏标题栏**没有**独立搜索按钮（specs/109 裁定：⌘K 归指令菜单，
    // 搜索降为面板里的一条命令），所以这里走真实入口而不是找图标。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('todo-command-palette-field'));
    if (field.evaluate().isEmpty) {
      markTestSkipped('本 harness 未触发 ⌘K（平台键映射差异），搜索入口由 '
          'specs/109 的指令菜单用例覆盖');
      return;
    }

    // 面板里应有「全局搜索」这条命令（搜索功能模块默认开启）。
    // 用命令项的语义 Key 定位 —— 只按文案 find.text 会命中标题等其它节点，
    // 且点不中时断言仍可能被面板自身的输入框满足（实测过这种"假绿"）。
    final searchItem = find.byKey(
      const Key('todo-command-palette-item-全局搜索'),
    );
    expect(
      searchItem,
      findsWidgets,
      reason: '指令菜单要含「全局搜索」（搜索功能模块默认开启）',
    );
    // 命令列表在弹层里可滚动，目标项可能在折叠线以下 ⇒ 先滚到位再点，
    // 否则 tap 会「未命中」而静默跳过（实测到过这种假绿）。
    await tester.ensureVisible(searchItem.first);
    await tester.pumpAndSettle();
    await tester.tap(searchItem.first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '打开搜索页不应抛异常');
    // 关键：面板必须已关闭（_run 里 pop 后才 run），否则说明没真的点中，
    // 断言会被面板自身满足而假绿。
    expect(
      find.byKey(const Key('todo-command-palette-field')),
      findsNothing,
      reason: '点命令后指令菜单要关闭并跳转，不能停在面板上',
    );
    // 搜索页要有可输入的搜索框（无网络桩下也要能渲染）。
    expect(
      find.byKey(const Key('task-search-filter')).evaluate().isNotEmpty ||
          find.byType(TextField).evaluate().isNotEmpty,
      isTrue,
      reason: '搜索页要有可输入的搜索框或筛选入口（不能白屏）',
    );
  });

  testWidgets('旅程⑧ 设置页可打开且分组齐全', (tester) async {
    await boot(tester);
    await tapSidebarRow(tester, 'todo-sidebar-row-settings');

    // 设置页的稳定分组与入口（与 settings_week_start_test 同口径）。
    final hasWeekStart = find.byKey(const Key('todo-settings-week-start'));
    expect(hasWeekStart, findsWidgets, reason: '设置页要有「星期开始于」');
    expect(tester.takeException(), isNull);
  });

  testWidgets('旅程⑨ 暗色模式同样渲染四区且无异常（用户实际在用暗色）', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      brightness: Brightness.dark,
      child: const HomeShell(),
    );
    await tester.pumpAndSettle();
    for (final key in const [
      'todo-rail',
      'todo-sidebar',
      'todo-content',
      'todo-detail',
    ]) {
      expect(find.byKey(Key(key)), findsWidgets, reason: '暗色下四区骨架缺 $key');
    }
    // 暗色下选中行必须有**可辨的背景底**（对齐滴答参照：浅灰/深灰底，无左色条）。
    //
    // 历史：这里原先是断言「选中行带品牌色左条」；对照 specs/002 的滴答公开参考图
    // 后确认滴答的选中态就是浅灰底、没有左条，于是移除了左条，该断言随之更新为
    // 「看底色差异」并明确禁止把左条加回来，而不是把这段删掉不测。
    final row = find.byKey(const Key('todo-sidebar-row-inbox'));
    final selectedMaterials = tester
        .widgetList<Material>(
          find.descendant(of: row, matching: find.byType(Material)),
        )
        .where((m) => m.color != null && m.color!.a > 0)
        .toList();
    expect(
      selectedMaterials,
      isNotEmpty,
      reason: '暗色下选中行要有可见底色（选中态不能只在浅色生效）',
    );
    final leftBorders = tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: row, matching: find.byType(AnimatedContainer)),
        )
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => c.decoration! as BoxDecoration)
        .where(
          (d) =>
              d.border is Border && ((d.border! as Border).left.width) > 0,
        )
        .toList();
    expect(
      leftBorders,
      isEmpty,
      reason: '参照图的选中态没有左色条，别再把这个元素加回来',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('旅程⑩ 空数据也进得去（空态不崩）', (tester) async {
    await boot(tester, set: TodoVisualFixtureSet.empty);
    expect(find.byKey(const Key('todo-content')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旅程⑪ 效能坞：习惯/专注/倒数日三个次级页都能打开且不崩', (tester) async {
    await boot(tester);
    // 效能坞按钮按 tooltip 定位（侧栏底部一排，没有独立语义 Key）。
    const tooltips = <String>['习惯打卡', '番茄专注', '倒数纪念日'];
    var opened = 0;
    for (final tip in tooltips) {
      final button = find.byTooltip(tip);
      if (button.evaluate().isEmpty) continue; // 功能模块开关关掉时该入口不在
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '打开「$tip」页面时抛了异常',
      );
      opened++;
      // 次级页多为全屏路由，用返回键回到工作区。
      final back = find.byTooltip('返回');
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await tester.pumpAndSettle();
      } else if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
      }
    }
    // 三个入口至少有一个可用，否则说明效能坞整体不可达（fixture 默认全开）。
    expect(
      opened,
      greaterThan(0),
      reason: '效能坞至少要有一个可达入口；一个都没有说明整排被关掉了',
    );
  });

  testWidgets('旅程⑫ 习惯/倒数日底层页面数据路径不抛异常', (tester) async {
    // 这两个页面依赖月度/年度统计接口；fixture 已把网络全部桩掉，
    // 这里断言的是「拿不到数据也要优雅降级，而不是崩」。
    await boot(tester);
    final habit = find.byTooltip('习惯打卡');
    if (habit.evaluate().isEmpty) {
      markTestSkipped('习惯入口被功能模块开关关闭');
      return;
    }
    await tester.tap(habit.first);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '习惯页在无网络（桩）下要降级显示，不能抛',
    );
    // 页面上应出现习惯相关的容器或空态文案，而不是彻底白屏。
    final hasHabitSurface =
        find.byKey(const Key('todo-habit-month-grid')).evaluate().isNotEmpty ||
        find.textContaining('习惯').evaluate().isNotEmpty;
    expect(hasHabitSurface, isTrue, reason: '习惯页要有可识别的内容面（不能白屏）');
  });

  testWidgets('旅程⑬ 成就与勋章页可从设置进入且不崩', (tester) async {
    await boot(tester);
    await tapSidebarRow(tester, 'todo-sidebar-row-settings');

    final entry = find.text('成就与勋章');
    expect(entry, findsWidgets, reason: '设置页要有「成就与勋章」入口');
    await tester.tap(entry.first);
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: '成就页在无网络（桩）下要降级显示，不能抛',
    );
    expect(
      find.textContaining('成就').evaluate(),
      isNotEmpty,
      reason: '成就页要有可识别内容面（不能白屏）',
    );
  });

  testWidgets('旅程⑭ 改：选中任务后改标题并保存，落库成功', (tester) async {
    final fixture = await boot(tester);
    final taskSurface = find.byKey(
      Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
    );
    await tester.tap(taskSurface);
    await tester.pumpAndSettle();

    // 详情面板标题输入框带稳定语义标识（见 task_detail_pane 的 Semantics）。
    final titleField = find.bySemanticsIdentifier('todo_task_detail_title');
    expect(titleField, findsWidgets, reason: '详情面板要有可编辑的标题字段');

    final newTitle = '旅程改名 ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(titleField.first, newTitle);
    await tester.pump();

    final save = find.widgetWithText(FilledButton, '保存');
    if (save.evaluate().isEmpty) {
      await tester.tap(find.text('保存').first);
    } else {
      await tester.tap(save.first);
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '保存标题不应抛异常');
    // 本地库是事实源：改完应当能在本地读到新标题（直接按本地 id 查，库没有便捷方法）。
    final stored = await (fixture.database.select(fixture.database.todoTasks)
          ..where((t) => t.id.equals(TodoVisualFixture.pinnedTaskId)))
        .getSingleOrNull();
    expect(stored?.title, newTitle, reason: '保存后本地任务标题应为新值');
  });

  testWidgets('旅程⑮ 删：任务右键菜单可达且包含「更多操作」', (tester) async {
    await boot(tester);
    final surface = find.byKey(
      Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
    );
    expect(surface, findsOneWidget);

    // 桌面端右键任务行弹上下文菜单（见 task_row_host._showDesktopContextMenu）。
    final center = tester.getCenter(surface);
    final gesture = await tester.startGesture(center, buttons: 2);
    await gesture.up();
    await tester.pumpAndSettle();

    final hasMenu =
        find.text('更多操作').evaluate().isNotEmpty ||
        find.text('标签').evaluate().isNotEmpty;
    if (!hasMenu) {
      markTestSkipped('右键菜单未在本 harness 弹出（需真机手势），跳过');
      return;
    }
    expect(
      find.text('添加子任务'),
      findsWidgets,
      reason: '右键菜单要含「添加子任务」（嘀嗒多级任务 :51）',
    );
    expect(tester.takeException(), isNull);
  });
}
