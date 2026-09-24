import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/shortcuts/todo_shortcut_registry.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/keyboard_shortcuts_dialog.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》：
/// `:18`「你可以输入『?』，方便的查看快捷键列表」、
/// `:26`「在设置里查看快捷键界面，可以修改」（本端只读，理由见 spec.md）。
class _LocalIntentA extends Intent {}

class _LocalIntentB extends Intent {}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required Size viewport,
  required double textScale,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late final BuildContext dialogContext;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            dialogContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  // 注意：showDialog 返回的 Future 要等弹层关闭才完成，await 它会把用例挂到超时。
  unawaited(showKeyboardShortcutsDialog(dialogContext));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 模拟真实按键：`?` 在键盘上是 Shift+/ 打出的字符，所以 keyDown 同时带 slash 逻辑键
/// 与字符 `?`——两种 activator（`slash+shift` 与 `CharacterActivator('?')`）都吃得到。
Future<void> _pressQuestionMark(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '?');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  testWidgets('快捷键列表逐行显示注册表里的动作与键位（列表不许说谎）', (tester) async {
    await _pumpDialog(tester, viewport: const Size(1440, 900), textScale: 1.0);

    expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
    expect(find.text('键盘快捷键'), findsOneWidget);

    final rows = todoShortcutRows;
    expect(rows.length, 2, reason: '注册表有几个动作就渲染几行，不由界面另数');
    for (final row in rows) {
      expect(
        find.descendant(
          of: find.byType(KeyboardShortcutsDialog),
          matching: find.text(row.label),
        ),
        findsOneWidget,
        reason: '动作名要读得到：${row.label}',
      );
      // 一行只渲染一个 Text（多个键位用 " / " 连接），所以断言整串：
      // 逐个 display 用 find.text 必然 0 命中（第一版就栽在这里）。
      expect(
        find.descendant(
          of: find.byType(KeyboardShortcutsDialog),
          matching: find.text(row.displays.join(' / ')),
        ),
        findsOneWidget,
        reason: '${row.label} 的键位 ${row.displays} 必须与注册表一致',
      );
    }
  });

  testWidgets('无编辑焦点时按 ? 打开「键盘快捷键」（嘀嗒 :18）', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    await _pressQuestionMark(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(KeyboardShortcutsDialog),
      findsOneWidget,
      reason: '缺这一条就说明 ? 还没接进工作区的快捷键',
    );
  });

  testWidgets('焦点在输入框里时 ? 照常输入，不被快捷键吞掉', (tester) async {
    var invoked = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Shortcuts.manager(
            manager: TodoShortcutManager(
              todoShortcutActivators(
                forKind: (kind) => switch (kind) {
                  TodoShortcutKind.openSearch => _LocalIntentA(),
                  TodoShortcutKind.showShortcuts => _LocalIntentB(),
                },
              ),
            ),
            child: Actions(
              actions: {
                _LocalIntentB: CallbackAction<_LocalIntentB>(
                  onInvoke: (_) {
                    invoked++;
                    return null;
                  },
                ),
              },
              child: TextField(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // 先钉守卫的判据本身：认不出「正在编辑」，下面的「不消费」就只是空转。
    expect(
      TodoShortcutManager.primaryFocusIsEditing(),
      isTrue,
      reason: '焦点已在 TextField 里，判据必须认出来',
    );

    await _pressQuestionMark(tester);
    await tester.pump();

    expect(invoked, 0, reason: '在输入框里打 ? 不该触发快捷键');
    // 不断言 controller.text：flutter_test 的 sendKeyDownEvent 不走 TextInput 的
    // onKeyText 通道，字符插入是平台侧行为，本地测不到就不声称测过。
    // 守卫负责的是「不消费」，由 invoked == 0 与摘掉守卫必红的探针证明。
  });

  testWidgets('设置页提供「键盘快捷键」入口并打开同一界面（嘀嗒 :26）', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsRoute())),
    );
    await tester.pump();

    final tile = find.text('键盘快捷键').first;
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
  });

  testWidgets('320px + 1.3 倍字体：快捷键对话框不溢出', (tester) async {
    await _pumpDialog(tester, viewport: const Size(320, 720), textScale: 1.3);

    expect(tester.takeException(), isNull);
    final dialog = find.byType(KeyboardShortcutsDialog);
    expect(tester.getRect(dialog).right, lessThanOrEqualTo(320));
  });

  testWidgets('对话框标题与每行动作各有独立读屏语义', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpDialog(tester, viewport: const Size(1440, 900), textScale: 1.0);
    await tester.pump();

    final dialog = find.byType(KeyboardShortcutsDialog);
    // 限定 in dialog：否则钉的是"全树存在且唯一"，不是"归属这个弹层"。
    expect(
      find.descendant(of: dialog, matching: find.bySemanticsLabel('键盘快捷键')),
      findsOneWidget,
      reason: '未 ensureSemantics 时该 finder 恒空，这里已开启',
    );
    for (final row in todoShortcutRows) {
      expect(
        find.descendant(of: dialog, matching: find.bySemanticsLabel(row.label)),
        findsOneWidget,
        reason: '读屏要能单独念出动作名：${row.label}',
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.bySemanticsLabel(row.displays.join(' / ')),
        ),
        findsOneWidget,
        reason: '键位串也要各有一个语义节点，否则读屏只念得出动作名',
      );
    }
    // 注册表护栏：两个动作绝不能共用同一个 activator，
    // 否则 todoShortcutActivators 的 Map 字面量会静默覆盖成一条，界面却仍列两条。
    // 直接钉「建出来的映射没有少一条」：重复 activator 会被 Map 字面量静默覆盖，
    // 而 todoShortcutBindings 是 const 列表 ⇒ 常量规范化让重复项成为同一实例，映射长度必降。
    // 复核第二轮 NIT5：这条比下面的字符串去重更硬（不依赖 Diagnosticable.toString 的 debug 排版）。
    expect(
      todoShortcutActivators(
        forKind: (kind) => kind == TodoShortcutKind.openSearch
            ? _LocalIntentA()
            : _LocalIntentB(),
      ).length,
      todoShortcutBindings.length,
      reason: '每条 binding 都必须占一个独立的映射位，不能被静默覆盖',
    );
    expect(
      todoShortcutBindings
          .map((b) => '${b.activator.runtimeType}:${b.activator}')
          .toSet()
          .length,
      todoShortcutBindings.length,
      reason: '每条 binding 的 activator 必须互不相同',
    );
    handle.dispose();
  });
}
