import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxParentData, RenderBox, RenderFlex;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《任务详情》把次要/破坏性动作收在右上角「...」里（`:372`「点击右上角「...」-「更多」-「任务动态」」、
/// `:399`「点击右上角「...」-「更多」…自定义任务详情操作菜单」）。本端嵌入态操作头照这个形状收，
/// 同时修掉 Issue #279 记的溢出。
void main() {
  const taskId = TodoVisualFixture.metadataTaskId;

  /// `pushed: true` 用一条真路由承载面板 —— 「移至收集箱」后要把面板关掉，
  /// 挂在 `home:` 下没有可 pop 的路由，那条语义就只能假装验过。
  Future<TodoVisualFixture> pumpPane(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    bool embedded = true,
    bool pushed = false,
    VisualDensity? visualDensity,
  }) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            // 显式给密度，不靠 adaptivePlatformDensity 的默认值 —— 折叠阈值是从
            // `Theme.of(context).visualDensity` 推的，测试基线得自己钉住。
            visualDensity: visualDensity ?? VisualDensity.standard,
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: pushed
              ? Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          // 嵌入态正文里有 TextField，生产上它挂在 workspace 的
                          // Scaffold 里；路由自己得给一层 Material 祖先，否则测的是脚手架不是面板。
                          builder: (_) => Scaffold(
                            body: TaskDetailPane(
                              taskId: taskId,
                              embedded: embedded,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('open-detail'),
                    ),
                  ),
                )
              : Scaffold(
                  body: TaskDetailPane(taskId: taskId, embedded: embedded),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<TodoTask> taskOf(AppDatabase db) => (db.select(
    db.todoTasks,
  )..where((row) => row.id.equals(taskId))).getSingle();

  Finder headerRow() {
    final pane = find.byKey(const Key('todo-task-detail-pane'));
    return find.descendant(of: pane, matching: find.byType(Row)).first;
  }

  Future<void> openMoreMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
  }

  /// 操作头真正需要的宽度：把 Row 每个孩子的 `parentData.offset.dx + size.width` 取最大值。
  ///
  /// 不用 `getSize(headerRow()).width <= 面板宽` —— 溢出的那一帧里 RenderFlex 的 **size
  /// 仍是被约束夹住的 304**，那条断言恒真（第 1 轮复核抓到）。孩子的偏移是逐位累加的，
  /// 所以这个数就是「有没有画到面板外」的直接读数。
  double headerChildrenExtent(WidgetTester tester) {
    final flex = tester.renderObject<RenderFlex>(headerRow());
    var extent = 0.0;
    flex.visitChildren((child) {
      final box = child as RenderBox;
      final right =
          (box.parentData! as BoxParentData).offset.dx + box.size.width;
      if (right > extent) extent = right;
    });
    return extent;
  }

  void expectHeaderFits(WidgetTester tester, double panelWidth) {
    final available = tester.getSize(headerRow()).width;
    expect(available, panelWidth - 16, reason: '面板 $panelWidth 减左右各 8 内边距');
    expect(
      headerChildrenExtent(tester),
      lessThanOrEqualTo(available),
      reason: '$panelWidth dp 面板上操作头的孩子画到了面板外',
    );
  }

  double headerIconExtent(WidgetTester tester, String tooltip) => tester
      .getSize(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      )
      .width;

  // 每种组合各自一条 testWidgets：合成一个循环的话，`takeException()` 只吐第一条待报异常，
  // 后 7 格永远红不了（第 1 轮复核抓到）。
  for (final scale in const [1.0, 1.3]) {
    for (final width in const [320.0, 355.0, 356.0, 390.0]) {
      final folded = width < 356;
      testWidgets('标准密度 $width dp + 字号 $scale：零溢出，折叠线在 356', (tester) async {
        await pumpPane(tester, size: Size(width, 700), textScale: scale);
        // 先量几何再看异常：溢出时这条给出「孩子画到哪」的数，`takeException` 只有一句像素数。
        expectHeaderFits(tester, width);
        expect(
          tester.takeException(),
          isNull,
          reason: '操作头在 $width dp + $scale 倍字号下溢出（Issue #279）',
        );
        expect(
          headerIconExtent(tester, '关闭详情'),
          48.0,
          reason: '钉住阈值公式里的 48：356 = 7×48 + 4 + 16',
        );
        expect(
          find.byTooltip('移至收集箱'),
          folded ? findsNothing : findsOneWidget,
          reason: '$width dp 面板${folded ? '该折进菜单' : '放不下才该折'}',
        );
        expect(find.byTooltip('删除'), folded ? findsNothing : findsOneWidget);
      });
    }
  }

  // 复核提过一条：`ThemeData` 的密度是 `adaptivePlatformDensity`，桌面/Web 是紧凑档，
  // 若这几枚图标跟着缩到 40dp，写死的 340 就会让 300~355dp 的面板白折一次。
  // **实测不缩**：本仓主题 `useMaterial3: true`（`lib/app.dart:109`、`:150`），而 M3 的
  // `IconButton` 把样式里的 `visualDensity` 硬编成 standard（SDK
  // `material/icon_button.dart:1152` 等四处 getter）。我按复核的说法把阈值改成随密度算过一次，
  // 结果紧凑主题 + 面板 300dp（内容 284dp）直接报 `A RenderFlex overflowed by 56 pixels`
  // （= 7×48+4 − 284）：图标根本没缩。
  // 这条钉住那个读数：紧凑密度下折叠行为与标准密度一致，图标仍 48dp。
  // 若将来 M3 真改成跟随密度，红的是最后两条 `findsNothing`（那时阈值该重算，而不是照抄 40）。
  testWidgets('紧凑主题密度不改变折叠线：320dp 面板照样折，图标仍 48dp', (tester) async {
    await pumpPane(
      tester,
      size: const Size(320, 700),
      visualDensity: VisualDensity.compact,
    );
    expectHeaderFits(tester, 320);
    expect(tester.takeException(), isNull);
    expect(
      headerIconExtent(tester, '关闭详情'),
      48.0,
      reason: 'M3 的 IconButton 不吃 ThemeData.visualDensity，48 这个数是量出来的',
    );
    expect(find.byTooltip('移至收集箱'), findsNothing);
    expect(find.byTooltip('删除'), findsNothing);
  });

  testWidgets('「移至收集箱」与「删除」收在「更多任务操作」里，仍然点到、语义不变', (tester) async {
    final fixture = await pumpPane(
      tester,
      size: const Size(320, 700),
      pushed: true,
    );
    await tester.tap(find.text('open-detail'));
    await tester.pumpAndSettle();
    final before = await taskOf(fixture.database);

    await openMoreMenu(tester);
    expect(find.text('移至收集箱'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除任务'), findsOneWidget, reason: '删除要先给确认，不能直接删');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    final afterCancel = await taskOf(fixture.database);
    expect(afterCancel.listId, before.listId);
    expect(afterCancel.toJson(), before.toJson(), reason: '取消删除不该动任何一列');

    await openMoreMenu(tester);
    await tester.tap(find.text('移至收集箱'));
    await tester.pumpAndSettle();
    final afterMove = await taskOf(fixture.database);
    expect(afterMove.listId, 'inbox');
    expect(find.byKey(const Key('todo-task-detail-pane')), findsNothing);
    expect(find.text('已移至收集箱'), findsOneWidget);
  });

  testWidgets('挪进菜单的两项各自有读屏语义，操作头剩下的图标仍带 tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPane(tester, size: const Size(320, 700));
    await openMoreMenu(tester);

    expect(tester.getSemantics(find.text('移至收集箱')).label, contains('移至收集箱'));
    expect(tester.getSemantics(find.text('删除')).label, contains('删除'));
    for (final tooltip in const ['关闭详情', '置顶', '勾选完成', '协作（指派/评论/成员）']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    handle.dispose();
  });

  testWidgets('嵌入态宽面板不折叠：两枚图标仍在栏上，菜单里不重复出现', (tester) async {
    await pumpPane(tester, size: const Size(760, 900));
    expect(find.byTooltip('移至收集箱'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);
    await openMoreMenu(tester);
    expect(find.text('移至收集箱'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('整页态宽屏的「更多任务操作」不重复出现图标栏上已有的两项', (tester) async {
    await pumpPane(tester, size: const Size(1200, 900), embedded: false);
    await openMoreMenu(tester);
    expect(find.text('移至收集箱'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('关联主任务'), findsOneWidget);
  });
}
