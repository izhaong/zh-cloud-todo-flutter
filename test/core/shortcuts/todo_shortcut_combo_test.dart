import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/shortcuts/todo_shortcut_combo.dart';
import 'package:zh_cloud_todo_flutter/core/shortcuts/todo_shortcut_registry.dart';

/// specs/109 / FL #579 面③：嘀嗒《03-特色功能/08-桌面快捷键.md》:26「在设置里查看快捷键界面，
/// 可以修改」、`:29`「显示为灰色的快捷键不能修改」。
///
/// 键位身份用 `LogicalKeyboardKey.keyId` 存（下面这些 0x6a/0x6b/0x2f 是现测出来的：
/// `Key J`=0x6a、`Key K`=0x6b、`Slash`=0x2f，`findKeyByKeyId` 能原样取回），
/// 显示文案取 `keyLabel` ⇒ 存的是键位，不是某个布局下打出来的字符。
void main() {
  const ctrlK = 'ctrl+0x6b';
  const metaK = 'meta+0x6b';
  const ctrlAltJ = 'ctrl+alt+0x6a';
  const ctrlShiftJ = 'ctrl+shift+0x6a';
  const shiftSlash = 'shift+0x2f';

  Intent forKind(TodoShortcutKind kind) => const _ProbeIntent();

  String encodeRows(List<TodoShortcutRow> rows) => rows
      .map((row) => '${row.kind.name}:${row.label}:${row.displays.join(" / ")}')
      .join(' || ');

  group('组合键规范串', () {
    test('形状与显示：修饰键固定顺序，末段是 keyId，显示用 keyLabel', () {
      const combo = TodoShortcutCombo(
        keyId: 0x6a,
        ctrl: true,
        alt: true,
        shift: true,
      );
      expect(combo.spec, 'ctrl+alt+shift+0x6a');
      expect(combo.display, 'Ctrl+Alt+Shift+J');
      expect(combo.hasUsableModifier, isTrue);
    });

    test('往返：自己写出的规范串解析得回来，并换成真 SingleActivator', () {
      const combo = TodoShortcutCombo(keyId: 0x2f, ctrl: true, shift: true);
      final parsed = TodoShortcutCombo.parse(combo.spec);
      expect(parsed, isNotNull);
      expect(parsed!.spec, combo.spec);
      expect(parsed.display, 'Ctrl+Shift+/');
      final activator = parsed.activator;
      expect(activator, isA<SingleActivator>());
      expect(activator!.trigger, LogicalKeyboardKey.slash);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
      expect(activator.meta, isFalse);
    });

    test('注册表的默认键位折算成规范串；字符型激活器折不出来（不当作用户可写的值）', () {
      final specs = <String?>[
        for (final binding in todoShortcutBindings)
          TodoShortcutCombo.specOfActivator(binding.activator),
      ];
      expect(specs, containsAllInOrder([ctrlK, metaK, shiftSlash, null]));
    });

    test('认不出的形状一律当"没有覆盖"', () {
      expect(TodoShortcutCombo.parse(null), isNull);
      expect(TodoShortcutCombo.parse('0x6a'), isNull, reason: '裸键连语法都不给过');
      expect(TodoShortcutCombo.parse('ctrl+'), isNull);
      expect(TodoShortcutCombo.parse('hyper+0x6a'), isNull);
      expect(TodoShortcutCombo.parse('ctrl+ctrl+0x6a'), isNull);
      expect(
        TodoShortcutCombo.parse('ctrl+k'),
        isNull,
        reason: '末段必须是 0x 十六进制 id',
      );
      expect(
        TodoShortcutCombo.parse('ctrl+0x7f7f7f'),
        isNull,
        reason: 'SDK 认不出的键位不许被绑',
      );
    });

    test('fromEvent：只按住修饰键不成形，触发键 + 修饰状态才成形', () {
      final shiftOnly = TodoShortcutCombo.fromEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
        ),
      );
      expect(shiftOnly, isNull, reason: '修饰键自己不是触发键，界面要继续等下一个键');
    });
  });

  group('生效键位与校验', () {
    test('没有覆盖时行内容与注册表逐字一致（默认行为不回退）', () {
      expect(
        encodeRows(todoShortcutRowsFor(const <String, String>{})),
        encodeRows(todoShortcutRows),
      );
      expect(encodeRows(todoShortcutRows), contains('Ctrl+K / ⌘K'));
    });

    test('覆盖只顶掉它那一个动作，另一个动作仍是默认两条', () {
      final rows = todoShortcutRowsFor(const {'openCommandPalette': ctrlAltJ});
      expect(
        encodeRows(rows),
        'openCommandPalette:打开指令菜单:Ctrl+Alt+J || showShortcuts:显示键盘快捷键:?',
      );
    });

    test('映射表真的换成新键位：旧键不再占位，未覆盖的动作照常占位', () {
      final map = todoShortcutActivators(
        forKind: forKind,
        overrides: const {'openCommandPalette': ctrlAltJ},
      );
      final specs = map.keys
          .map(TodoShortcutCombo.specOfActivator)
          .whereType<String>()
          .toSet();
      expect(specs, contains(ctrlAltJ));
      expect(specs, isNot(contains(ctrlK)), reason: '旧键还挂着就是"两套键都能按"，界面却只列新键');
      expect(specs, isNot(contains(metaK)));
      expect(
        map.length,
        3,
        reason: '1 条覆盖 + showShortcuts 的 slash+shift 与字符 ? 两条',
      );
    });

    test('坏值不改键：解析不出或缺 Ctrl/⌘/Alt 的覆盖一律当没有覆盖', () {
      for (final bad in ['不是规范串', '0x6a', 'shift+0x6a']) {
        final rows = todoShortcutRowsFor({'openCommandPalette': bad});
        expect(
          encodeRows(rows),
          encodeRows(todoShortcutRows),
          reason: '库里躺着 "$bad" 时应当用默认键位，而不是把功能弄没',
        );
        final map = todoShortcutActivators(
          forKind: forKind,
          overrides: {'openCommandPalette': bad},
        );
        expect(map.length, todoShortcutBindings.length);
      }
    });

    test('裸键与只按 Shift 被拒绝，并说得出为什么', () {
      final reason = validateShortcutOverride(
        kind: TodoShortcutKind.openCommandPalette,
        combo: const TodoShortcutCombo(keyId: 0x6a, shift: true),
        overrides: const <String, String>{},
      );
      expect(reason, isNotNull);
      expect(reason, contains('Ctrl'));
      expect(reason, contains('输入框'), reason: '要说清"为什么这类键不让绑"，不能只说不行');
    });

    test('撞键被拒绝：把「显示键盘快捷键」改成「打开指令菜单」正用的 Ctrl+K', () {
      final reason = validateShortcutOverride(
        kind: TodoShortcutKind.showShortcuts,
        combo: TodoShortcutCombo.parse(ctrlK),
        overrides: const <String, String>{},
      );
      expect(reason, isNotNull);
      expect(reason, contains('打开指令菜单'), reason: '要指出被谁占了');
    });

    test('改回自己现在的键位不算撞键；合法的新键位放行', () {
      expect(
        validateShortcutOverride(
          kind: TodoShortcutKind.openCommandPalette,
          combo: TodoShortcutCombo.parse(ctrlK),
          overrides: const <String, String>{},
        ),
        isNull,
        reason: '同一个动作自己占的键不是撞键',
      );
      expect(
        validateShortcutOverride(
          kind: TodoShortcutKind.openCommandPalette,
          combo: TodoShortcutCombo.parse(ctrlShiftJ),
          overrides: const <String, String>{},
        ),
        isNull,
      );
    });

    test('撞键比的是生效值：对方已被改掉时，旧默认键就空出来了', () {
      // 显示键盘快捷键改成 Ctrl+Alt+J 之后，Ctrl+K 只剩「打开指令菜单」在用；
      // 反过来把「打开指令菜单」按回 Ctrl+K 不该报撞键。
      expect(
        validateShortcutOverride(
          kind: TodoShortcutKind.openCommandPalette,
          combo: TodoShortcutCombo.parse(ctrlShiftJ),
          overrides: const {'showShortcuts': ctrlAltJ},
        ),
        isNull,
      );
      expect(
        validateShortcutOverride(
          kind: TodoShortcutKind.openCommandPalette,
          combo: TodoShortcutCombo.parse(ctrlAltJ),
          overrides: const {'showShortcuts': ctrlAltJ},
        ),
        isNotNull,
        reason: '对方生效值是 Ctrl+Alt+J ⇒ 这才叫撞键',
      );
    });
  });
}

/// 只为把映射表建起来；判据量的是 activator 那一侧。
class _ProbeIntent extends Intent {
  const _ProbeIntent();
}
