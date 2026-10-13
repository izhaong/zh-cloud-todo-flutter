import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/command_palette.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/keyboard_shortcuts_dialog.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_search_page.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》:9「使用 ⌘+K 或者 Ctrl+K 打开「指令菜单」，
/// 输入名称，轻松前往应用内各大功能模块。」（specs/109 / FL #579 面①）。
///
/// 判据着力点不是"面板上有一行字"，而是**这条命令点了真的去得到**：
/// 每个"某条命令不在列表里"的负向，都在同一条用例里先证它本来在。
void main() {
  const field = Key('todo-command-palette-field');
  Key itemKey(String label) => Key('todo-command-palette-item-$label');

  Finder item(String label) => find.byKey(itemKey(label));
  Finder header(String name) =>
      find.byKey(Key('todo-command-palette-group-$name'));

  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  /// 面板单独可测：命令表由调用方给，这里用一枚 Builder 取 context 走真实入口
  /// `showCommandPalette`，而不是绕过它直接 pump 内部 Widget。
  Future<void> openPalette(
    WidgetTester tester, {
    required List<TodoPaletteCommand> commands,
  }) async {
    late final BuildContext hostContext;
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
    // showDialog 返回的 Future 要等弹层关闭才完成，await 它会把用例挂到超时。
    unawaited(showCommandPalette(hostContext, commands: commands));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('面板本身', () {
    testWidgets('空查询列出全部命令，输入名称片段后只剩匹配项（名称与说明都能匹配）', (tester) async {
      await openPalette(
        tester,
        commands: const [
          TodoPaletteCommand(label: '前往「日历」', run: _paletteNoop),
          TodoPaletteCommand(label: '习惯打卡', hint: '每日打卡记录', run: _paletteNoop),
          TodoPaletteCommand(label: '设置', run: _paletteNoop),
        ],
      );

      expect(find.byType(CommandPalette), findsOneWidget);
      for (final label in const ['前往「日历」', '习惯打卡', '设置']) {
        expect(
          find.byKey(itemKey(label)),
          findsOneWidget,
          reason: '空查询就该把调用方给的命令全列出来：$label',
        );
      }

      await tester.enterText(find.byKey(field), '日历');
      await tester.pump();
      expect(find.byKey(itemKey('前往「日历」')), findsOneWidget);
      expect(
        find.byKey(itemKey('设置')),
        findsNothing,
        reason: '过滤没生效的话，下面那句"不匹配的不在了"就是空转',
      );

      // hint 也参与匹配：嘀嗒那句是「输入名称」，本端把说明一并当作可搜的关键词。
      await tester.enterText(find.byKey(field), '记录');
      await tester.pump();
      expect(
        find.byKey(itemKey('习惯打卡')),
        findsOneWidget,
        reason: '只按标题匹配的话，输入说明里的词就搜不到这条',
      );
      expect(find.byKey(itemKey('前往「日历」')), findsNothing);
    });

    testWidgets('回车执行第一条匹配命令，并把面板收起', (tester) async {
      final ran = <String>[];
      await openPalette(
        tester,
        commands: [
          TodoPaletteCommand(label: '前往「日历」', run: () => ran.add('日历')),
          TodoPaletteCommand(label: '前往「习惯」', run: () => ran.add('习惯')),
        ],
      );

      await tester.enterText(find.byKey(field), '前往');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ran, ['日历'], reason: '回车要执行的是首条匹配项，不是全部、也不是末条');
      expect(
        find.byType(CommandPalette),
        findsNothing,
        reason: '执行完面板该收起，否则跳过去的模块被盖住了',
      );
    });

    testWidgets('回车跳过禁用项，执行下一条可用命令', (tester) async {
      final ran = <String>[];
      await openPalette(
        tester,
        commands: [
          TodoPaletteCommand(
            label: '番茄专注',
            run: () => ran.add('番茄'),
            enabled: false,
            disabledHint: '功能模块里已关闭',
          ),
          TodoPaletteCommand(label: '番茄市集', run: () => ran.add('市集')),
        ],
      );

      // 两条都含"番茄"，用同一个片段把它们都留在列表里，禁用那条排在首位。
      await tester.enterText(find.byKey(field), '番茄');
      await tester.pump();
      expect(find.byKey(itemKey('番茄专注')), findsOneWidget);
      expect(find.byKey(itemKey('番茄市集')), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ran, ['市集'], reason: '首条是禁用的 ⇒ 回车要跳到下一条可用的，不能点了不动就当没发生');
      expect(find.byType(CommandPalette), findsNothing);
    });

    testWidgets('无匹配给出明确空态；清空查询后列表要回来', (tester) async {
      await openPalette(
        tester,
        commands: const [TodoPaletteCommand(label: '设置', run: _paletteNoop)],
      );

      await tester.enterText(find.byKey(field), '这段字任何命令里都没有');
      await tester.pump();
      expect(
        find.byKey(const Key('todo-command-palette-empty')),
        findsOneWidget,
      );
      expect(find.text('没有匹配的模块或命令'), findsOneWidget);
      expect(
        find.byKey(itemKey('设置')),
        findsNothing,
        reason: '空态出现时不该还挂着不匹配的命令',
      );

      await tester.enterText(find.byKey(field), '');
      await tester.pump();
      expect(
        find.byKey(itemKey('设置')),
        findsOneWidget,
        reason: '清空后必须恢复全量列表，否则"空态"其实是常驻控件',
      );
      expect(find.byKey(const Key('todo-command-palette-empty')), findsNothing);
    });

    testWidgets('灰掉的命令点了不动，且必须写明为什么灰（hint 缺失也要有原因）', (tester) async {
      final ran = <String>[];
      await openPalette(
        tester,
        commands: [
          TodoPaletteCommand(label: '设置', run: () => ran.add('设置')),
          TodoPaletteCommand(
            label: '番茄专注',
            run: () => ran.add('番茄'),
            enabled: false,
            disabledHint: '功能模块里已关闭',
          ),
        ],
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey('番茄专注')),
          matching: find.text('功能模块里已关闭'),
        ),
        findsOneWidget,
        reason: '没有 hint 的禁用项也要讲清为什么点不动，否则就是一条假控件',
      );

      await tester.tap(find.byKey(itemKey('番茄专注')));
      await tester.pump();
      expect(ran, isEmpty, reason: '禁用的命令不许被执行');
      expect(
        find.byType(CommandPalette),
        findsOneWidget,
        reason: '点灰项也不该把面板顺手关掉——用户还没挑到要去的模块',
      );

      // 正对照：同一条用例里证明"点了会跑"这条通道本身是通的。
      await tester.tap(find.byKey(itemKey('设置')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(ran, ['设置']);
      expect(find.byType(CommandPalette), findsNothing);
    });
  });

  group('分组（嘀嗒《08-桌面快捷键.md》:28 那层「帮助」）', () {
    Key groupKey(String name) => Key('todo-command-palette-group-$name');

    testWidgets('未分组命令在前、组标题在其后、组命令紧跟自己的标题', (tester) async {
      await openPalette(
        tester,
        commands: const [
          TodoPaletteCommand(label: '前往「日历」', run: _paletteNoop),
          TodoPaletteCommand(label: '全局搜索', run: _paletteNoop),
          TodoPaletteCommand(label: '显示键盘快捷键', group: '帮助', run: _paletteNoop),
        ],
      );

      expect(
        find.byKey(groupKey('帮助')),
        findsOneWidget,
        reason: '原文那条路径要能在这张面板里走：指令菜单 → 帮助 → 显示键盘快捷键',
      );
      final headerY = tester.getRect(find.byKey(groupKey('帮助'))).top;
      final commandY = tester.getRect(item('显示键盘快捷键')).top;
      expect(
        commandY,
        greaterThan(headerY),
        reason: '标题必须在自己那组命令的上方，不然"归到帮助"只是句空话',
      );
      for (final label in const ['前往「日历」', '全局搜索']) {
        expect(
          tester.getRect(item(label)).top,
          lessThan(headerY),
          reason: '$label 是"前往模块"那一类，不该被塞到帮助标题之下',
        );
      }
      expect(find.text('帮助'), findsOneWidget);
    });

    testWidgets('输入把整组筛空时，组标题跟着消失；清空后又回来', (tester) async {
      await openPalette(
        tester,
        commands: const [
          TodoPaletteCommand(label: '前往「日历」', run: _paletteNoop),
          TodoPaletteCommand(label: '显示键盘快捷键', group: '帮助', run: _paletteNoop),
        ],
      );
      expect(find.byKey(groupKey('帮助')), findsOneWidget);

      await tester.enterText(find.byKey(field), '日历');
      await tester.pump();
      expect(find.byKey(itemKey('显示键盘快捷键')), findsNothing);
      expect(
        find.byKey(groupKey('帮助')),
        findsNothing,
        reason: '组里一条都不剩还顶个标题，就是"看着有这层、点进去空的"',
      );

      await tester.enterText(find.byKey(field), '');
      await tester.pump();
      expect(
        find.byKey(groupKey('帮助')),
        findsOneWidget,
        reason: '反向对照：标题是随命中算出来的，不是常驻控件',
      );
    });

    testWidgets('只有分组命令命中时，回车执行的是命令本身（标题不是可执行项）', (tester) async {
      final ran = <String>[];
      await openPalette(
        tester,
        commands: [
          TodoPaletteCommand(label: '前往「日历」', run: () => ran.add('日历')),
          TodoPaletteCommand(
            label: '显示键盘快捷键',
            group: '帮助',
            run: () => ran.add('快捷键'),
          ),
        ],
      );

      await tester.enterText(find.byKey(field), '键盘');
      await tester.pump();
      expect(find.byKey(itemKey('前往「日历」')), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ran, ['快捷键']);
      expect(find.byType(CommandPalette), findsNothing);
    });

    testWidgets('多个分组按首次出现排序，组内保持调用方给的顺序', (tester) async {
      await openPalette(
        tester,
        commands: const [
          TodoPaletteCommand(label: '帮助甲', group: '帮助', run: _paletteNoop),
          TodoPaletteCommand(label: '乙一', group: '清单', run: _paletteNoop),
          TodoPaletteCommand(label: '帮助乙', group: '帮助', run: _paletteNoop),
          TodoPaletteCommand(label: '平铺项', run: _paletteNoop),
        ],
      );

      final tops = <String, double>{
        '平铺项': tester.getRect(item('平铺项')).top,
        '帮助': tester.getRect(header('帮助')).top,
        '帮助甲': tester.getRect(item('帮助甲')).top,
        '帮助乙': tester.getRect(item('帮助乙')).top,
        '清单': tester.getRect(header('清单')).top,
        '乙一': tester.getRect(item('乙一')).top,
      };
      expect(tops['平铺项']!, lessThan(tops['帮助']!));
      expect(tops['帮助']!, lessThan(tops['帮助甲']!));
      expect(tops['帮助甲']!, lessThan(tops['帮助乙']!));
      expect(tops['帮助乙']!, lessThan(tops['清单']!));
      expect(tops['清单']!, lessThan(tops['乙一']!));
    });
  });

  group('接进工作区（真实 ⌘K）', () {
    Future<TodoVisualFixture> pumpShell(WidgetTester tester) =>
        pumpTodoVisualScenario(
          tester,
          viewport: TodoVisualViewports.wide,
          fixtureSet: TodoVisualFixtureSet.populated,
          child: const HomeShell(),
        );

    Future<void> pressCtrlK(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('⌘K 开的是指令菜单，不是直接跳搜索页；搜索仍在面板里', (tester) async {
      final fixture = await pumpShell(tester);

      expect(find.byType(CommandPalette), findsNothing);
      expect(find.byType(TaskSearchPage), findsNothing);
      await pressCtrlK(tester);

      expect(
        find.byType(CommandPalette),
        findsOneWidget,
        reason: '嘀嗒 :9 把 ⌘K 定给指令菜单 ⇒ 键位要开面板',
      );
      expect(
        find.byType(TaskSearchPage),
        findsNothing,
        reason: '负向对照：⌘K 不许再直接进搜索页',
      );
      expect(
        find.byKey(itemKey('全局搜索')),
        findsOneWidget,
        reason:
            '搜索不能因为换语义就丢掉入口（面板里得有一条；'
            '这条命令点得到搜索页由 task_organize_search_test.dart 量）',
      );

      // 嘀嗒 :28「在「指令菜单」-「帮助」-「显示键盘快捷键」打开快捷键界面，可以修改」：
      // 真实 ⌘K 那条路径上，帮助这一层与"打开后能改"都要成立。
      expect(
        find.byKey(const Key('todo-command-palette-group-帮助')),
        findsOneWidget,
      );
      expect(
        tester.getRect(item('显示键盘快捷键')).top,
        greaterThan(tester.getRect(header('帮助')).top),
      );
      expect(
        find.byKey(const Key('keyboard-shortcuts-edit-showShortcuts')),
        findsNothing,
        reason: '前置条件：还没打开快捷键界面',
      );
      // 「帮助」在列表末尾，弹层里那条命令默认在视口外：直接 tap 会打在别处（实测就是这样空转）。
      await tester.ensureVisible(item('显示键盘快捷键'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(item('显示键盘快捷键')).bottom,
        lessThanOrEqualTo(900),
        reason: '正对照：这条命令确实被滚进了视口（视口高 900）',
      );
      await tester.tap(item('显示键盘快捷键'));
      await tester.pumpAndSettle();
      expect(
        find.byType(KeyboardShortcutsDialog),
        findsOneWidget,
        reason: '点了帮助里那条命令，快捷键界面必须真的弹出来',
      );
      expect(
        find.byKey(const Key('keyboard-shortcuts-edit-showShortcuts')),
        findsOneWidget,
        reason: '从帮助里进去的界面必须可改，否则 :28 那句"可以修改"落空',
      );
      expect(
        find.byKey(const Key('keyboard-shortcuts-readonly')),
        findsNothing,
        reason: '反向对照：这条路径不该给只读态',
      );

      // 交叉验证点名的那半句：`:28` 说的是"打开快捷键界面，可以修改"，
      // 光断"有修改按钮"不够 —— 要从这条路径真改一次，并量它落库。
      await tester.tap(
        find.byKey(const Key('keyboard-shortcuts-edit-showShortcuts')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('keyboard-shortcuts-capture-showShortcuts')),
        findsOneWidget,
        reason: '点「修改」要进入"等你按下新组合键"的捕获态',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final stored = await fixture.container.read(
        shortcutOverridesProvider.future,
      );
      expect(
        stored['showShortcuts'],
        'ctrl+alt+0x6a',
        reason: '从帮助进去改的键必须落库，否则那句"可以修改"只活在这一次打开里',
      );
    });

    testWidgets('面板里挑「设置」⇒ 真的进设置页（前往各模块不是列个名字）', (tester) async {
      await pumpShell(tester);

      expect(find.byType(SettingsRoute), findsNothing);
      await pressCtrlK(tester);
      expect(
        find.byKey(itemKey('设置')),
        findsOneWidget,
        reason: '正对照：默认就该列出「设置」这条',
      );

      await tester.enterText(find.byKey(field), '设置');
      await tester.pump();
      await tester.tap(find.byKey(itemKey('设置')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsRoute), findsOneWidget);
      expect(
        find.byType(CommandPalette),
        findsNothing,
        reason: '跳过去后面板要收起，否则设置页被弹层盖住',
      );
    });

    testWidgets('功能模块关掉的模块，面板里不许再列（番茄与搜索，正对照在前）', (tester) async {
      final fixture = await pumpShell(tester);
      final repo = SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );

      await pressCtrlK(tester);
      expect(
        find.byKey(itemKey('番茄专注')),
        findsOneWidget,
        reason: '正对照：番茄默认开着，面板里就该有这条',
      );
      expect(
        find.byKey(itemKey('全局搜索')),
        findsOneWidget,
        reason: '正对照：搜索默认开着，面板里就该有这条',
      );
      await tester.tap(find.byKey(const Key('todo-command-palette-close')));
      await tester.pumpAndSettle();
      expect(
        find.byType(CommandPalette),
        findsNothing,
        reason: '「关闭」按钮不收面板的话，下面重开的是第二个弹层，判据就废了',
      );

      await repo.saveFeature(
        module: TodoFeatureModule.pomodoro,
        enabled: false,
      );
      await repo.saveFeature(module: TodoFeatureModule.search, enabled: false);
      await tester.pumpAndSettle();

      await pressCtrlK(tester);
      expect(
        find.byKey(itemKey('番茄专注')),
        findsNothing,
        reason: '第 285 轮那套开关关掉番茄后，面板不许还给一条进不去的命令',
      );
      expect(
        find.byKey(itemKey('全局搜索')),
        findsNothing,
        reason: '搜索被关掉 ⇒ 面板里也不该留这条',
      );
      expect(
        find.byKey(itemKey('前往「日历」')),
        findsOneWidget,
        reason: '负向对照：面板确实重开了、其它命令还在，不是整个弹层没出来',
      );
    });
  });
}

/// const 命令表需要一个稳定的函数引用。
void _paletteNoop() {}
