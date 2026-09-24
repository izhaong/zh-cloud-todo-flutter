import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》：`:18`「你可以输入「?」，方便的查看快捷键列表」。
/// 这份注册表是**唯一事实源**：工作区的 `Shortcuts` 映射与对话框里的列表都由它生成，
/// 这样界面永远不会列出一个其实没绑定的键位。
enum TodoShortcutKind { openSearch, showShortcuts }

@immutable
class TodoShortcutBinding {
  const TodoShortcutBinding({
    required this.kind,
    required this.label,
    required this.display,
    required this.activator,
  });

  final TodoShortcutKind kind;
  final String label;

  /// 给用户看的键位文案；同一个动作在不同布局下可以有多个 activator，
  /// 但展示只保留一种写法（见 [todoShortcutRows] 的去重）。
  final String display;
  final ShortcutActivator activator;
}

const List<TodoShortcutBinding> todoShortcutBindings = [
  TodoShortcutBinding(
    kind: TodoShortcutKind.openSearch,
    label: '打开全局搜索',
    display: 'Ctrl+K',
    activator: SingleActivator(LogicalKeyboardKey.keyK, control: true),
  ),
  TodoShortcutBinding(
    kind: TodoShortcutKind.openSearch,
    label: '打开全局搜索',
    display: '⌘K',
    activator: SingleActivator(LogicalKeyboardKey.keyK, meta: true),
  ),
  // 嘀嗒《08-桌面快捷键.md:18》原话「你可以输入「?」」。键盘上没有独立的「?」逻辑键，
  // ? 是 Shift+/ 的字符；而不同平台把这次按键交给 Flutter 的形态并不一样
  // （Windows/Linux 多为 slash+shift 逻辑键，macOS 与 Web 常直接给字符 ?），
  // 所以两种 activator 都绑，展示仍统一写「?」（由 todoShortcutRows 去重）。
  TodoShortcutBinding(
    kind: TodoShortcutKind.showShortcuts,
    label: '显示键盘快捷键',
    display: '?',
    activator: SingleActivator(LogicalKeyboardKey.slash, shift: true),
  ),
  TodoShortcutBinding(
    kind: TodoShortcutKind.showShortcuts,
    label: '显示键盘快捷键',
    display: '?',
    activator: CharacterActivator('?'),
  ),
];

@immutable
class TodoShortcutRow {
  const TodoShortcutRow({
    required this.kind,
    required this.label,
    required this.displays,
  });

  final TodoShortcutKind kind;
  final String label;
  final List<String> displays;
}

List<TodoShortcutRow> get todoShortcutRows {
  final order = <TodoShortcutKind>[];
  final labels = <TodoShortcutKind, String>{};
  final displays = <TodoShortcutKind, List<String>>{};
  for (final binding in todoShortcutBindings) {
    if (!displays.containsKey(binding.kind)) {
      order.add(binding.kind);
      labels[binding.kind] = binding.label;
      displays[binding.kind] = <String>[];
    }
    if (!displays[binding.kind]!.contains(binding.display)) {
      displays[binding.kind]!.add(binding.display);
    }
  }
  return [
    for (final kind in order)
      TodoShortcutRow(
        kind: kind,
        label: labels[kind]!,
        displays: List.unmodifiable(displays[kind]!),
      ),
  ];
}

Map<ShortcutActivator, Intent> todoShortcutActivators({
  required Intent Function(TodoShortcutKind kind) forKind,
}) {
  return <ShortcutActivator, Intent>{
    for (final binding in todoShortcutBindings)
      binding.activator: forKind(binding.kind),
  };
}

/// 裸键（无 Ctrl/⌘/Alt）在输入框里属于用户要打的字，不该被快捷键吃掉。
/// 带修饰键的组合照旧放行——「?」本身在搜索框里就是字符，而 ⌘K 不会是。
class TodoShortcutManager extends ShortcutManager {
  TodoShortcutManager(Map<ShortcutActivator, Intent> shortcuts)
    : super(shortcuts: shortcuts);

  static bool primaryFocusIsEditing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    final widget = context.widget;
    // TextField 的焦点节点在 EditableText 之下，两种落点都要认。
    return widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final keyboard = HardwareKeyboard.instance;
      final withModifier =
          keyboard.isControlPressed ||
          keyboard.isMetaPressed ||
          keyboard.isAltPressed;
      if (!withModifier && primaryFocusIsEditing()) {
        return KeyEventResult.ignored;
      }
    }
    return super.handleKeypress(context, event);
  }
}
