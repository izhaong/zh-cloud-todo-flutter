import 'package:flutter/material.dart';

/// 嘀嗒《03-特色功能/08-桌面快捷键.md》:9「使用 ⌘+K 或者 Ctrl+K 打开「指令菜单」，
/// 输入名称，轻松前往应用内各大功能模块。」本端标题与文案都用「指令菜单」这个词。
///
/// 命令表由调用方给（`TodoWorkspace` 收 HomeShell 的导航回调，才拼得出这些条目）；
/// 面板自己不碰 provider 与路由，这样它能被单独测。
class TodoPaletteCommand {
  const TodoPaletteCommand({
    required this.label,
    required this.run,
    this.hint,
    this.enabled = true,
    this.disabledHint,
    this.group,
  });

  final String label;
  final VoidCallback run;
  final String? hint;
  final bool enabled;

  /// 分组名（null = 不分组）。嘀嗒《08-桌面快捷键.md》`:28` 给的路径是
  /// 「指令菜单」-「帮助」-「显示键盘快捷键」，即面板里除了"前往各模块"还有一层
  /// 叫得出名字的归类；平铺着列就只剩"有一条同名命令"，路径本身对不上。
  final String? group;

  /// 灰掉时要说为什么灰着（嘀嗒在快捷键列表里对不可改项就是"灰色 + 有原因"）。
  final String? disabledHint;
}

/// [searchPlaceholder] 那行提示写的是"输入名称"，不是"输入命令"——源页 `:9` 就这么说的。
Future<void> showCommandPalette(
  BuildContext context, {
  required List<TodoPaletteCommand> commands,
  String searchPlaceholder = '输入名称前往各模块',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => CommandPalette(
      commands: commands,
      searchPlaceholder: searchPlaceholder,
    ),
  );
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.commands,
    required this.searchPlaceholder,
  });

  final List<TodoPaletteCommand> commands;
  final String searchPlaceholder;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// 灰掉的命令必须把「为什么灰」讲出来，hint 有没有都得讲——
  /// 只按 hint 拼的话，无 hint 的禁用项就变成一条点了不动又没理由的假控件。
  String? _subtitleFor(TodoPaletteCommand command) {
    if (command.enabled) return command.hint;
    final reason = command.disabledHint ?? '当前不可用';
    return command.hint == null ? reason : '${command.hint}（$reason）';
  }

  List<TodoPaletteCommand> get _matches {
    final text = _query.text.trim().toLowerCase();
    if (text.isEmpty) return widget.commands;
    return widget.commands
        .where(
          (command) =>
              command.label.toLowerCase().contains(text) ||
              (command.hint?.toLowerCase().contains(text) ?? false),
        )
        .toList(growable: false);
  }

  void _run(TodoPaletteCommand command) {
    // 禁用项在这儿拦不住：点击那条路径由 `ListTile.enabled` 让 onTap 失效，
    // 回车那条路径由 `_runFirstMatch` 的 `where(enabled)` 跳过。
    Navigator.of(context).pop();
    command.run();
  }

  void _runFirstMatch() {
    final first = _matches.where((command) => command.enabled).firstOrNull;
    if (first != null) _run(first);
  }

  /// 按组渲染：未分组的命令保持原顺序排在最前，其后每个分组按"首次出现"的顺序出现，
  /// 组内保持调用方给的顺序。组标题只在组内**至少有一条命中**时出现——
  /// 输入把整组筛空了还顶一个标题，就是"看着有这一层、点进去什么都没有"。
  List<Widget> _rowsWithHeaders(List<TodoPaletteCommand> matches) {
    final ungrouped = matches
        .where((command) => command.group == null)
        .toList(growable: false);
    final groupNames = <String?>[];
    for (final command in matches) {
      if (command.group != null && !groupNames.contains(command.group)) {
        groupNames.add(command.group);
      }
    }
    final rows = <Widget>[for (final command in ungrouped) _row(command)];
    for (final group in groupNames) {
      final inGroup = matches
          .where((command) => command.group == group)
          .toList(growable: false);
      rows.add(
        Padding(
          key: Key('todo-command-palette-group-$group'),
          padding: const EdgeInsets.only(top: 8, bottom: 2, left: 4),
          child: Text(
            group!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      rows.addAll(inGroup.map(_row));
    }
    return rows;
  }

  Widget _row(TodoPaletteCommand command) {
    return ListTile(
      key: Key('todo-command-palette-item-${command.label}'),
      enabled: command.enabled,
      title: Text(command.label),
      subtitle: _subtitleFor(command) == null
          ? null
          : Text(
              _subtitleFor(command)!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: () => _run(command),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return AlertDialog(
      title: const Text('指令菜单'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('todo-command-palette-field'),
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchPlaceholder,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runFirstMatch(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (matches.isEmpty)
              const Text('没有匹配的模块或命令', key: Key('todo-command-palette-empty'))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _rowsWithHeaders(matches),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('todo-command-palette-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
