import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/command_palette.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_search_page.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

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
      await pumpShell(tester);

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
