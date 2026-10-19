import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/command_palette.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/keyboard_shortcuts_dialog.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/109 / FL #579 面③：嘀嗒《03-特色功能/08-桌面快捷键.md》:26「在设置里查看快捷键界面，
/// 可以修改」。判据的着力点不是"界面上有个按钮"，而是**改完那把键真的换了人**：
/// 弹层里量"落库拿到什么、行内容显示什么"，工作区量"新键按得响、旧键不再响、重置回默认又响"。
/// 读那枚错误提示自己的文案：`find.textContaining` 会被行标签满足，量不出"报错在说话"。
String _errorText(WidgetTester tester) {
  final finder = find.byKey(const Key('keyboard-shortcuts-error'));
  expect(finder, findsOneWidget, reason: '拒绝必须当场可见');
  return tester.widget<Text>(finder).data ?? '';
}

void main() {
  const ctrlAltJ = 'ctrl+alt+0x6a';
  const ctrlAltK = 'ctrl+alt+0x6b';

  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<List<(String, String?)>> pumpDialog(
    WidgetTester tester, {
    Map<String, String> overrides = const <String, String>{},
    Future<void> Function(String kindName, String? spec)? onSave,
    Size viewport = const Size(1440, 900),
  }) async {
    final calls = <(String, String?)>[];
    late final BuildContext hostContext;
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: themed(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    unawaited(
      showKeyboardShortcutsDialog(
        hostContext,
        overrides: overrides,
        onSave: onSave == null
            ? null
            : (kindName, spec) async {
                await onSave(kindName, spec);
                calls.add((kindName, spec));
              },
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  /// 按下一个组合键：修饰键先按住、触发键后按、再全部松开
  /// （`HardwareKeyboard` 的修饰状态是 `SingleActivator` 判定要看的）。
  Future<void> press(
    WidgetTester tester, {
    required LogicalKeyboardKey key,
    bool control = false,
    bool alt = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('快捷键界面里的改键', () {
    testWidgets('没给落库通道时是只读：没有改键控件，并说得出为什么', (tester) async {
      await pumpDialog(tester);

      expect(
        find.byKey(const Key('keyboard-shortcuts-readonly')),
        findsOneWidget,
        reason: '"改不了"要在界面上讲明白，不是把按钮藏了就完事',
      );
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.text('Ctrl+K / ⌘K'), findsOneWidget, reason: '只读时行内容照旧');
    });

    testWidgets('给了落库通道就出现改键与重置；按新组合键 ⇒ 落库拿到规范串并当场显示', (tester) async {
      final calls = await pumpDialog(tester, onSave: (kindName, spec) async {});

      expect(
        find.byIcon(Icons.edit),
        findsNWidgets(3),
        // FL #345 A 批：注册表 3 个动作（addTask 全局添加）⇒ 3 枚「修改」
        reason: '正对照：注册表 3 个动作都可改 ⇒ 各一枚「修改」',
      );
      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
      );
      await tester.pumpAndSettle();
      expect(find.text('请按下新的组合键（Esc 取消）'), findsOneWidget);

      await press(
        tester,
        key: LogicalKeyboardKey.keyJ,
        control: true,
        alt: true,
      );

      expect(calls, [('openCommandPalette', ctrlAltJ)]);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+Alt+J',
        reason: '列表要说真话：存的和显示的是同一把键',
      );
    });

    testWidgets('裸键被当场拒绝：说得出原因、不落库、还在等下一个键', (tester) async {
      final calls = await pumpDialog(tester, onSave: (kindName, spec) async {});

      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
      );
      await tester.pumpAndSettle();
      await press(tester, key: LogicalKeyboardKey.keyJ);

      expect(calls, isEmpty, reason: '裸键不许落库——它会被输入焦点守卫吞掉');
      final reason = _errorText(tester);
      expect(reason, contains('Ctrl'));
      expect(reason, contains('输入框'), reason: '要说清为什么这类键不让绑，不能只甩一句"不行"');
      expect(
        find.text('请按下新的组合键（Esc 取消）'),
        findsOneWidget,
        reason: '一次拒绝不该顺带退出捕获，否则用户以为已经改好了',
      );

      // 退出捕获后行内容还是默认两条 ⇒ 被拒的那次按键没改动任何键位。
      await press(tester, key: LogicalKeyboardKey.escape);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+K / ⌘K',
      );

      // 同一条用例里给正对照：重新进入捕获（那句拒绝说明该跟着清掉），
      // 换一个合法组合就能落库。
      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('keyboard-shortcuts-error')),
        findsNothing,
        reason: '重新开始一次改键，上一条拒绝说明不该还挂着',
      );
      await press(
        tester,
        key: LogicalKeyboardKey.keyJ,
        control: true,
        alt: true,
      );
      expect(calls, [('openCommandPalette', ctrlAltJ)]);
    });

    testWidgets('撞键被拒绝：说得出被谁占了', (tester) async {
      final calls = await pumpDialog(tester, onSave: (kindName, spec) async {});

      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-showShortcuts')),
      );
      await tester.pumpAndSettle();
      await press(tester, key: LogicalKeyboardKey.keyK, control: true);

      expect(calls, isEmpty, reason: 'Ctrl+K 是「打开指令菜单」在用的键');
      expect(
        _errorText(tester),
        contains('打开指令菜单'),
        reason:
            '拒绝要指名被谁占了——读的是那枚 error 节点自己的文案，'
            '不是"全树某处有这几个字"（行标签里本来就有）',
      );
    });

    testWidgets('Esc 取消捕获：不落库，行内容仍是原键位', (tester) async {
      final calls = await pumpDialog(tester, onSave: (kindName, spec) async {});

      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
      );
      await tester.pumpAndSettle();
      await press(tester, key: LogicalKeyboardKey.escape);

      expect(calls, isEmpty);
      expect(
        find.text('请按下新的组合键（Esc 取消）'),
        findsNothing,
        reason: '正对照：Esc 确实退出了捕获态',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+K / ⌘K',
      );
    });

    testWidgets('重置 ⇒ 传 null 删覆盖，行内容回到默认两条', (tester) async {
      final calls = await pumpDialog(
        tester,
        overrides: const {'openCommandPalette': ctrlAltJ},
        onSave: (kindName, spec) async {},
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+Alt+J',
        reason: '正对照：先让"已改过"的状态显出来，重置才有东西可退回',
      );

      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-reset-openCommandPalette')),
      );
      await tester.pumpAndSettle();

      expect(calls, [('openCommandPalette', null)]);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+K / ⌘K',
      );
    });

    testWidgets('落库抛错 ⇒ 报出失败且不显示新键位（存不下就不算改过）', (tester) async {
      await pumpDialog(
        tester,
        onSave: (kindName, spec) async => throw StateError('库没打开'),
      );

      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-openCommandPalette')),
      );
      await tester.pumpAndSettle();
      await press(
        tester,
        key: LogicalKeyboardKey.keyJ,
        control: true,
        alt: true,
      );

      expect(find.byKey(const Key('keyboard-shortcuts-error')), findsOneWidget);
      expect(find.textContaining('保存失败'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('keyboard-shortcuts-display-openCommandPalette'),
              ),
            )
            .data,
        'Ctrl+K / ⌘K',
        reason: '写库失败却显示新键位 = 界面在说谎',
      );
    });
  });

  group('改键真的换人（工作区里按下一把键）', () {
    Future<TodoVisualFixture> pumpShell(WidgetTester tester) =>
        pumpTodoVisualScenario(
          tester,
          viewport: TodoVisualViewports.wide,
          fixtureSet: TodoVisualFixtureSet.populated,
          child: const HomeShell(),
        );

    Future<void> closePalette(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('todo-command-palette-close')));
      await tester.pumpAndSettle();
      expect(find.byType(CommandPalette), findsNothing);
    }

    testWidgets('改键后新键开面板、旧键不再开；重置回默认旧键又生效', (tester) async {
      final fixture = await pumpShell(tester);
      final repo = SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );

      // 默认（正对照）：Ctrl+K 开面板。
      await press(tester, key: LogicalKeyboardKey.keyK, control: true);
      expect(
        find.byType(CommandPalette),
        findsOneWidget,
        reason: '默认键位必须还能按，否则这条判据在测的是别的东西',
      );
      await closePalette(tester);

      await repo.saveShortcut(kindName: 'openCommandPalette', combo: ctrlAltK);
      await tester.pumpAndSettle();

      await press(tester, key: LogicalKeyboardKey.keyK, control: true);
      expect(
        find.byType(CommandPalette),
        findsNothing,
        reason: '旧键还开着面板 ⇒ 覆盖只改了显示、没改生效',
      );

      await press(
        tester,
        key: LogicalKeyboardKey.keyK,
        control: true,
        alt: true,
      );
      expect(find.byType(CommandPalette), findsOneWidget, reason: '新键要真的能开面板');
      await closePalette(tester);

      await repo.saveShortcut(kindName: 'openCommandPalette', combo: null);
      await tester.pumpAndSettle();

      await press(tester, key: LogicalKeyboardKey.keyK, control: true);
      expect(
        find.byType(CommandPalette),
        findsOneWidget,
        reason: '重置要回到今天的键位，不是回到一个没人按得出的空档',
      );
    });

    testWidgets('把「显示键盘快捷键」改成 Ctrl+Alt+/ 后，? 不再开列表、新键开', (tester) async {
      final fixture = await pumpShell(tester);
      final repo = SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );

      await press(tester, key: LogicalKeyboardKey.slash, shift: true);
      expect(
        find.byType(KeyboardShortcutsDialog),
        findsOneWidget,
        reason: '正对照：默认 ? 开快捷键列表',
      );
      await tester.tap(find.byKey(const Key('keyboard-shortcuts-close')));
      await tester.pumpAndSettle();

      await repo.saveShortcut(
        kindName: 'showShortcuts',
        combo: 'ctrl+alt+0x2f',
      );
      await tester.pumpAndSettle();

      await press(tester, key: LogicalKeyboardKey.slash, shift: true);
      expect(
        find.byType(KeyboardShortcutsDialog),
        findsNothing,
        reason: '改走之后 ? 不该还开着列表',
      );

      await press(
        tester,
        key: LogicalKeyboardKey.slash,
        control: true,
        alt: true,
      );
      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
    });
  });
}
