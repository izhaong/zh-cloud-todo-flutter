import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'todo_shortcut_combo.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》：`:18`「你可以输入「?」，方便的查看快捷键列表」。
/// 这份注册表是**默认值**的唯一事实源：工作区的 `Shortcuts` 映射与对话框里的列表都由它生成，
/// 这样界面永远不会列出一个其实没绑定的键位。`:26`「在设置里查看快捷键界面，可以修改」
/// 的"改键"由覆盖表兑现：生效行见 [todoShortcutRowsFor]，生效映射见 [todoShortcutActivators]。
enum TodoShortcutKind { openCommandPalette, showShortcuts, addTask }

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
  // FL #345 A 批：全局添加任务（嘀嗒《08-桌面快捷键》:178-180「全局添加
  // Ctrl / Cmd + Alt + A，一键调出任务添加条」）。v1 兑现为**应用内全局**
  // （工作区任意位置生效）；OS 级全局热键（其它应用在前景时也能调出）需要
  // 平台通道，随桌面壳成熟度另刀。
  TodoShortcutBinding(
    kind: TodoShortcutKind.addTask,
    label: '添加任务',
    display: 'Ctrl+Alt+A',
    activator: SingleActivator(
      LogicalKeyboardKey.keyA,
      control: true,
      alt: true,
    ),
  ),
  TodoShortcutBinding(
    kind: TodoShortcutKind.addTask,
    label: '添加任务',
    display: '⌘⌥A',
    activator: SingleActivator(LogicalKeyboardKey.keyA, meta: true, alt: true),
  ),
  TodoShortcutBinding(
    kind: TodoShortcutKind.openCommandPalette,
    // 嘀嗒《03-特色功能/08-桌面快捷键.md》:9「使用 ⌘+K 或者 Ctrl+K 打开「指令菜单」，
    // 输入名称，轻松前往应用内各大功能模块」。原先这里绑的是全局搜索（语义不等），
    // 本轮换成面板，搜索改作面板里的一条命令（specs/109 裁定）。
    label: '打开指令菜单',
    display: 'Ctrl+K',
    activator: SingleActivator(LogicalKeyboardKey.keyK, control: true),
  ),
  TodoShortcutBinding(
    kind: TodoShortcutKind.openCommandPalette,
    // 同一动作的第二种布局：`:9` 把 ⌘+K 与 Ctrl+K 并列，两条都要绑，
    // 展示由 todoShortcutRows 去重后各留一行。
    label: '打开指令菜单',
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

/// 注册表里出现过的动作，按注册表顺序去重 ⇒ 行的顺序永远跟着默认值走，不由界面另数。
List<TodoShortcutKind> get _kindsInRegistryOrder {
  final order = <TodoShortcutKind>[];
  for (final binding in todoShortcutBindings) {
    if (!order.contains(binding.kind)) order.add(binding.kind);
  }
  return order;
}

/// 某个动作的默认显示文案（去重后可能有多条，如 `Ctrl+K` 与 `⌘K`）。
List<String> _defaultDisplays(TodoShortcutKind kind) {
  final displays = <String>[];
  for (final binding in todoShortcutBindings) {
    if (binding.kind != kind) continue;
    if (!displays.contains(binding.display)) displays.add(binding.display);
  }
  return displays;
}

/// 覆盖表里这一档是不是**真的生效**：形状要解析得出、键位要认得出，
/// 而且必须带 Ctrl/⌘/Alt —— 手工写进库里的裸键覆盖一律当"没有覆盖"，
/// 否则用户会被自己存的值坑到再也按不出这个功能。
TodoShortcutCombo? _effectiveOverride(
  TodoShortcutKind kind,
  Map<String, String> overrides,
) {
  final combo = TodoShortcutCombo.parse(overrides[kind.name]);
  if (combo == null || !combo.hasUsableModifier || combo.activator == null) {
    return null;
  }
  return combo;
}

/// 这个动作**当前生效**的激活器集合：有覆盖就只认覆盖那一条，否则认注册表里的默认若干条。
List<ShortcutActivator> effectiveShortcutActivators(
  TodoShortcutKind kind,
  Map<String, String> overrides,
) {
  final activator = _effectiveOverride(kind, overrides)?.activator;
  if (activator != null) return [activator];
  return [
    for (final binding in todoShortcutBindings)
      if (binding.kind == kind) binding.activator,
  ];
}

/// 嘀嗒 :26 的"可以修改"要能在界面上说出**现在按什么键**，所以行内容由生效值算，
/// 不是把注册表抄一遍。
List<TodoShortcutRow> todoShortcutRowsFor(Map<String, String> overrides) {
  final rows = <TodoShortcutRow>[];
  for (final kind in _kindsInRegistryOrder) {
    final display = _effectiveOverride(kind, overrides)?.display;
    rows.add(
      TodoShortcutRow(
        kind: kind,
        label: shortcutLabelOf(kind),
        displays: List.unmodifiable(
          display == null ? _defaultDisplays(kind) : <String>[display],
        ),
      ),
    );
  }
  return rows;
}

/// 没有任何覆盖时的行（= 今天的行为）。
List<TodoShortcutRow> get todoShortcutRows =>
    todoShortcutRowsFor(const <String, String>{});

/// 动作名取自注册表；注册表里没有这个动作的绑定时回枚举名（新增 kind 忘了配绑定
/// 也不至于把界面弄崩）。
String shortcutLabelOf(TodoShortcutKind kind) {
  for (final binding in todoShortcutBindings) {
    if (binding.kind == kind) return binding.label;
  }
  return kind.name;
}

/// 改键校验：能生效回 null，否则回一句"为什么不行"。
/// 两条规则都是嘀嗒那句「显示为灰色的快捷键不能修改」（`:29`）在本端的兑现方式，
/// 理由见 [TodoShortcutCombo.hasUsableModifier] 与撞键那支。
String? validateShortcutOverride({
  required TodoShortcutKind kind,
  required TodoShortcutCombo? combo,
  required Map<String, String> overrides,
}) {
  if (combo == null) return '这个组合键认不出来，请重新按';
  if (!combo.hasUsableModifier) {
    return '必须带上 Ctrl、⌘ 或 Alt：裸键和只按 Shift 的键在输入框里要让位给打字，'
        '改到那种键等于把这个功能藏起来';
  }
  final spec = combo.spec;
  for (final other in _kindsInRegistryOrder) {
    if (other == kind) continue;
    final taken = effectiveShortcutActivators(
      other,
      overrides,
    ).any((activator) => TodoShortcutCombo.specOfActivator(activator) == spec);
    if (taken) return '这个组合已经是「${shortcutLabelOf(other)}」的键位，先给它换一个';
  }
  return null;
}

Map<ShortcutActivator, Intent> todoShortcutActivators({
  required Intent Function(TodoShortcutKind kind) forKind,
  Map<String, String> overrides = const <String, String>{},
}) {
  return <ShortcutActivator, Intent>{
    for (final kind in _kindsInRegistryOrder)
      for (final activator in effectiveShortcutActivators(kind, overrides))
        activator: forKind(kind),
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
