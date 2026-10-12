import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/keyboard_shortcuts_dialog.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/110 / FL #581：嘀嗒《03-特色功能/08-桌面快捷键.md》常见问题里那句
/// 「在侧边栏打开快捷键界面，可以修改」——第三种进法。
///
/// 判据不是"侧栏多了一个按钮"，而是**从这个门进去照样能改、改的键真的落库**：
/// 设置页、指令菜单、侧栏三处必须共用同一份生效键位与落库通道，
/// 否则就出现"某个入口进去只能看不能改"的第二等入口。
void main() {
  Future<SidebarVisibilityRepository> repoOf(TodoVisualFixture fixture) async =>
      SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );

  Future<TodoVisualFixture> pumpShell(WidgetTester tester) =>
      pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

  testWidgets('侧栏 dock 那枚「快捷键」打开同一个界面，且在这里改的键真的落库', (tester) async {
    final fixture = await pumpShell(tester);
    final repo = await repoOf(fixture);

    expect(
      find.byType(KeyboardShortcutsDialog),
      findsNothing,
      reason: '正对照：没点之前不该已经开着弹层',
    );
    expect(
      find.byTooltip('键盘快捷键'),
      findsOneWidget,
      reason: '嘀嗒那条要的是看得见的入口，不是藏在长按里的暗门',
    );

    await tester.tap(find.byTooltip('键盘快捷键'));
    await tester.pumpAndSettle();

    expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
    expect(
      find.byKey(const Key('keyboard-shortcuts-readonly')),
      findsNothing,
      reason: '这个入口带着落库通道进来，不许是只读的',
    );
    expect(
      find.byIcon(Icons.edit),
      findsNWidgets(2),
      reason: '两个动作都可改 ⇒ 两枚「修改」，与设置页那个入口同一形态',
    );

    await tester.tap(
      find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(await repo.getShortcuts(), {
      'openCommandPalette': 'ctrl+alt+0x6a',
    }, reason: '从侧栏改的键不落库 = 这一行只是把界面又开了一次');
  });

  testWidgets('侧栏入口打开时显示的是生效键位，不是注册表默认值', (tester) async {
    final fixture = await pumpShell(tester);
    await (await repoOf(
      fixture,
    )).saveShortcut(kindName: 'openCommandPalette', combo: 'ctrl+alt+0x6a');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('键盘快捷键'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(
              const Key('keyboard-shortcuts-display-openCommandPalette'),
            ),
          )
          .data,
      'Ctrl+Alt+J',
      reason: '三处入口得说同一套话：这里若还显示 Ctrl+K / ⌘K，就是又抄了一遍默认值',
    );
  });

  testWidgets('番茄专注关掉后 dock 少一枚，「快捷键」那枚不许跟着消失', (tester) async {
    final fixture = await pumpShell(tester);

    expect(
      find.byTooltip('番茄专注'),
      findsOneWidget,
      reason: '正对照：默认 dock 里有番茄专注',
    );
    expect(find.byTooltip('键盘快捷键'), findsOneWidget);

    await (await repoOf(
      fixture,
    )).saveFeature(module: TodoFeatureModule.pomodoro, enabled: false);
    await tester.pumpAndSettle();

    expect(find.byTooltip('番茄专注'), findsNothing);
    expect(
      find.byTooltip('键盘快捷键'),
      findsOneWidget,
      reason: '快捷键不是"功能模块"那三档之一，别被别人的开关顺手收掉',
    );
  });
}
