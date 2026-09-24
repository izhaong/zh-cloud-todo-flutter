import 'package:flutter/material.dart';
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

  testWidgets('嵌入态操作头在 320/355/356/390 与字号 1.0/1.3 的每种组合下都不溢出', (tester) async {
    for (final scale in const [1.0, 1.3]) {
      for (final width in const [320.0, 355.0, 356.0, 390.0]) {
        await pumpPane(tester, size: Size(width, 700), textScale: scale);
        expect(
          tester.takeException(),
          isNull,
          reason: '操作头在 $width px + $scale 倍字号下溢出（Issue #279）',
        );
        expect(
          tester.getSize(headerRow()).width,
          lessThanOrEqualTo(width),
          reason: '行宽不该超过视口',
        );
      }
    }
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
