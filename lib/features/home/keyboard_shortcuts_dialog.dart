import 'package:flutter/material.dart';

import '../../core/shortcuts/todo_shortcut_registry.dart';

Future<void> showKeyboardShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const KeyboardShortcutsDialog(),
  );
}

/// 嘀嗒《08-桌面快捷键.md:18/:26》的「快捷键列表」界面：`?` 与设置页入口共用这一份，
/// 行内容由 [todoShortcutRows] 生成，因此列出来的键位一定是真绑定了的。
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = todoShortcutRows;
    return AlertDialog(
      title: const Text('键盘快捷键'),
      content: SizedBox(
        width: 240,
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
                        child: Text(
                          row.displays.join(' / '),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
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
