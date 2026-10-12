import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/error_text.dart';
import '../../core/shortcuts/todo_shortcut_combo.dart';
import '../../core/shortcuts/todo_shortcut_registry.dart';

/// 打开快捷键界面。
///
/// [onSave] 为 null ⇒ 只读（本地数据库尚未就绪时就是这样）：行内容照旧由生效键位生成，
/// 只是不给改键控件。传了 [onSave] 才出现「修改」与「重置」——嘀嗒《08-桌面快捷键.md》:26
/// 「在设置里查看快捷键界面，可以修改」。
Future<void> showKeyboardShortcutsDialog(
  BuildContext context, {
  Map<String, String> overrides = const <String, String>{},
  Future<void> Function(String kindName, String? spec)? onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        KeyboardShortcutsDialog(overrides: overrides, onSave: onSave),
  );
}

/// 嘀嗒《08-桌面快捷键.md》:18「你可以输入「?」，方便的查看快捷键列表」+ `:26` 可修改。
/// 行内容来自 [todoShortcutRowsFor]（默认值出自 [todoShortcutBindings] 这份唯一事实源，
/// 改过键就按生效值显示），因此界面永远不会列出一个其实没绑定的键位。
class KeyboardShortcutsDialog extends StatefulWidget {
  const KeyboardShortcutsDialog({
    super.key,
    this.overrides = const <String, String>{},
    this.onSave,
  });

  final Map<String, String> overrides;

  /// 落库通道：`spec == null` 表示删掉这一档的覆盖、回到默认键位。
  final Future<void> Function(String kindName, String? spec)? onSave;

  @override
  State<KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<KeyboardShortcutsDialog> {
  /// 弹层是独立路由，不会跟着 provider 重建，所以改键成功后在这份本地副本上更新，
  /// 界面当场显示新键位（工作区那边的生效靠偏好流推回去）。
  late Map<String, String> _overrides;
  TodoShortcutKind? _capturing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _overrides = Map<String, String>.of(widget.overrides);
  }

  bool get _editable => widget.onSave != null;

  void _startCapture(TodoShortcutKind kind) {
    setState(() {
      _capturing = kind;
      _error = null;
    });
  }

  void _cancelCapture() {
    setState(() {
      _capturing = null;
      _error = null;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final kind = _capturing;
    if (kind == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelCapture();
      return KeyEventResult.handled;
    }
    final combo = TodoShortcutCombo.fromEvent(event);
    if (combo == null) {
      // 只按住了修饰键：组合还没成形，继续等下一个键，别报"认不出来"。
      return KeyEventResult.ignored;
    }
    final reason = validateShortcutOverride(
      kind: kind,
      combo: combo,
      overrides: _overrides,
    );
    if (reason != null) {
      setState(() => _error = reason);
      return KeyEventResult.handled;
    }
    unawaited(_commit(kind, combo));
    return KeyEventResult.handled;
  }

  Future<void> _commit(TodoShortcutKind kind, TodoShortcutCombo combo) async {
    final onSave = widget.onSave;
    if (onSave == null) return;
    try {
      await onSave(kind.name, combo.spec);
    } on Object catch (e) {
      if (mounted) {
        // 落库失败与"这把键不让绑"是两回事：键位本身合法，问题出在存储，
        // 所以退出捕获、把旧键位原样留着，别让用户以为再按一次就能补救。
        setState(() {
          _capturing = null;
          _error = '保存失败：${describeError(e)}';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _overrides[kind.name] = combo.spec;
      _capturing = null;
      _error = null;
    });
  }

  Future<void> _reset(TodoShortcutKind kind) async {
    final onSave = widget.onSave;
    if (onSave == null) return;
    try {
      await onSave(kind.name, null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '重置失败：${describeError(e)}');
      return;
    }
    if (!mounted) return;
    setState(() {
      _overrides.remove(kind.name);
      _capturing = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = todoShortcutRowsFor(_overrides);
    return AlertDialog(
      title: const Text('键盘快捷键'),
      // 宽度自适应：写死 360 会让 320px 视口整块溢出（既有那条「320px + 1.3 倍字体不溢出」
      // 的用例量的就是这块），而改键控件需要比原来 240 更宽的横向空间。
      content: SizedBox(
        width: math.min(360, MediaQuery.sizeOf(context).width - 64),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, row) in rows.indexed)
                Padding(
                  key: Key('keyboard-shortcuts-row-$index'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      // 两侧都给 Flexible：只把动作名放成 Expanded 时，键位列按自身
                      // 宽度参与布局，320px + 1.3 倍字体实测溢出 13px。
                      Flexible(flex: 3, child: Text(row.label)),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 2,
                        child: _capturing == row.kind
                            ? Focus(
                                // 捕获态：这一格不再是文案，而是"等你按下新组合键"。
                                key: Key(
                                  'keyboard-shortcuts-capture-${row.kind.name}',
                                ),
                                autofocus: true,
                                onKeyEvent: _onKey,
                                child: const Text('请按下新的组合键（Esc 取消）'),
                              )
                            : Text(
                                row.displays.join(' / '),
                                key: Key(
                                  'keyboard-shortcuts-display-${row.kind.name}',
                                ),
                                textAlign: TextAlign.end,
                              ),
                      ),
                      if (_editable && _capturing != row.kind) ...[
                        IconButton(
                          key: Key('keyboard-shortcuts-edit-${row.kind.name}'),
                          icon: const Icon(Icons.edit),
                          tooltip: '修改「${row.label}」',
                          onPressed: () => _startCapture(row.kind),
                        ),
                        IconButton(
                          key: Key('keyboard-shortcuts-reset-${row.kind.name}'),
                          icon: const Icon(Icons.restore),
                          tooltip: '重置「${row.label}」为默认键位',
                          onPressed: () => unawaited(_reset(row.kind)),
                        ),
                      ],
                    ],
                  ),
                ),
              if (!_editable)
                const Text(
                  '本地数据库尚未就绪，快捷键暂时改不了。',
                  key: Key('keyboard-shortcuts-readonly'),
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const Key('keyboard-shortcuts-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('keyboard-shortcuts-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
