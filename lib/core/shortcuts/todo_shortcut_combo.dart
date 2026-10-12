import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》:26「在设置里查看快捷键界面，可以修改」
/// 要求改键能存下来 ⇒ 组合键需要一个"可持久化的身份"，而不是只有 `ShortcutActivator`。
///
/// 规范串：`ctrl+meta+alt+shift+0x<hex keyId>`，修饰键固定按这个顺序，末段是
/// [LogicalKeyboardKey.keyId] 的十六进制。键位实例经
/// [LogicalKeyboardKey.findKeyByKeyId] 取回（这份 SDK 里唯一公开的"按 id 找键"通道），
/// 显示文案取 [LogicalKeyboardKey.keyLabel] ⇒ 存的是**键位身份**，
/// 不是某个布局下打出来的字符（`Ctrl+2` 与 `Ctrl+@` 在英文布局上是同一个键，
/// 存 id 就只会显示成那个键自己的标签）。
class TodoShortcutCombo {
  const TodoShortcutCombo({
    required this.keyId,
    this.ctrl = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
  });

  final int keyId;
  final bool ctrl;
  final bool meta;
  final bool alt;
  final bool shift;

  /// Ctrl/⌘/Alt 至少要有一个：只按 Shift 或裸键都会落进
  /// `TodoShortcutManager` 的编辑焦点守卫（裸键在输入框里让位给打字），
  /// 改到那种键等于把功能藏起来，所以不允许绑。
  bool get hasUsableModifier => ctrl || meta || alt;

  String get spec => [
    if (ctrl) 'ctrl',
    if (meta) 'meta',
    if (alt) 'alt',
    if (shift) 'shift',
    '0x${keyId.toRadixString(16)}',
  ].join('+');

  /// 键位标签；SDK 认不出这个 id、或它没有标签时回 null。
  String? get label {
    final text = _trigger?.keyLabel ?? '';
    return text.isEmpty ? null : text;
  }

  /// 给用户看的写法（`Ctrl+K` / `⌘J` / `Alt+Shift+2`）；标签取不到时回 null。
  String? get display {
    final text = label;
    if (text == null) return null;
    return [
      if (ctrl) 'Ctrl',
      if (meta) '⌘',
      if (alt) 'Alt',
      if (shift) 'Shift',
      text,
    ].join('+');
  }

  LogicalKeyboardKey? get _trigger => LogicalKeyboardKey.findKeyByKeyId(keyId);

  /// 换成真正参与 `Shortcuts` 映射的激活器；键位认不出时回 null。
  SingleActivator? get activator {
    final trigger = _trigger;
    if (trigger == null || label == null) return null;
    return SingleActivator(
      trigger,
      control: ctrl,
      meta: meta,
      alt: alt,
      shift: shift,
    );
  }

  /// 语法解析：形状不对、修饰键词不认识、键位认不出、没有标签 ⇒ 一律 null（当作没有覆盖）。
  static TodoShortcutCombo? parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('+');
    if (parts.length < 2) return null;
    var ctrl = false, meta = false, alt = false, shift = false;
    for (final modifier in parts.sublist(0, parts.length - 1)) {
      switch (modifier) {
        case 'ctrl':
          if (ctrl) return null;
          ctrl = true;
        case 'meta':
          if (meta) return null;
          meta = true;
        case 'alt':
          if (alt) return null;
          alt = true;
        case 'shift':
          if (shift) return null;
          shift = true;
        default:
          return null;
      }
    }
    final keyPart = parts.last;
    if (!RegExp(r'^0x[0-9a-f]+$').hasMatch(keyPart)) return null;
    final keyId = int.tryParse(keyPart.substring(2), radix: 16);
    if (keyId == null) return null;
    final combo = TodoShortcutCombo(
      keyId: keyId,
      ctrl: ctrl,
      meta: meta,
      alt: alt,
      shift: shift,
    );
    if (combo._trigger == null || combo.label == null) return null;
    return combo;
  }

  /// 从一次按键捕获组合：修饰键自己不算触发键（回 null，界面继续等下一个键）。
  static TodoShortcutCombo? fromEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final keyId = event.logicalKey.keyId;
    if (_modifierKeyIds.contains(keyId)) return null;
    final keyboard = HardwareKeyboard.instance;
    return TodoShortcutCombo(
      keyId: keyId,
      ctrl: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
    );
  }

  /// 修饰键自己不能当触发键（`SingleActivator` 也会断言这一点）。
  /// 用 `final` 而不是 `const`：`keyId` 是 getter，常量表达式里取不到。
  static final Set<int> _modifierKeyIds = <int>{
    LogicalKeyboardKey.control.keyId,
    LogicalKeyboardKey.controlLeft.keyId,
    LogicalKeyboardKey.controlRight.keyId,
    LogicalKeyboardKey.shift.keyId,
    LogicalKeyboardKey.shiftLeft.keyId,
    LogicalKeyboardKey.shiftRight.keyId,
    LogicalKeyboardKey.alt.keyId,
    LogicalKeyboardKey.altLeft.keyId,
    LogicalKeyboardKey.altRight.keyId,
    LogicalKeyboardKey.meta.keyId,
    LogicalKeyboardKey.metaLeft.keyId,
    LogicalKeyboardKey.metaRight.keyId,
  };

  /// 把注册表里的默认激活器折算成规范串，用来做撞键比较；
  /// 不是 `SingleActivator` 的（例如字符 `?`）折不出来，回 null。
  static String? specOfActivator(ShortcutActivator activator) {
    if (activator is! SingleActivator) return null;
    final keyId = activator.trigger.keyId;
    if (_modifierKeyIds.contains(keyId)) return null;
    return TodoShortcutCombo(
      keyId: keyId,
      ctrl: activator.control,
      meta: activator.meta,
      alt: activator.alt,
      shift: activator.shift,
    ).spec;
  }
}
