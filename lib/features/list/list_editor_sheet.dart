import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'list_actions.dart';
import 'list_color.dart';
import 'list_properties.dart';

/// M11-B2 清单创建 / 重命名 / 删除 弹窗。
///
/// 嘀嗒《01-任务/09-如何管理海量任务/02-用清单管理任务.md》:73
/// 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
class ListEditorSheet extends ConsumerStatefulWidget {
  const ListEditorSheet({super.key, this.folderLocalId, this.existing});

  final String? folderLocalId;
  final TodoList? existing;

  @override
  ConsumerState<ListEditorSheet> createState() => _ListEditorSheetState();
}

class _ListEditorSheetState extends ConsumerState<ListEditorSheet> {
  late final TextEditingController _name;
  late String? _folderLocalId;
  String? _color;
  String? _icon;
  bool _showInSmartList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    // FR-3 编辑时预选当前归属；FR-5 从文件夹里点新建时沿用带入的归属。
    _folderLocalId = widget.existing?.folderLocalId ?? widget.folderLocalId;
    _color = widget.existing?.color;
    _icon = widget.existing?.icon;
    _showInSmartList = widget.existing?.showInSmartList ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _name.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(listRepositoryProvider);
    final existing = widget.existing;
    if (repo == null) {
      setState(() => _error = '本地数据库尚未就绪，清单没能保存');
      return;
    }
    setState(() => _error = null);
    // 方式二（嘀嗒 :87）：名称最前面输入 Emoji 自动设为图标；
    // 已显式选过图标（含显式清除）时不抢用户的决定。
    var effectiveIcon = _icon ?? detectLeadingEmoji(text);
    try {
      // 先移动再改名再改色：前一步失败时后面还没发生，弹层里不会出现"半改好"的清单。
      if (existing == null) {
        await repo.create(
          name: text,
          folderLocalId: _folderLocalId,
          color: _color,
          icon: effectiveIcon,
          showInSmartList: _showInSmartList,
        );
      } else {
        if (_folderLocalId != existing.folderLocalId) {
          await repo.moveToFolder(existing.id, _folderLocalId);
        }
        if (text != existing.name) await repo.rename(existing.id, text);
        if (_color != existing.color) {
          await repo.setColor(existing.id, _color);
        }
        if (effectiveIcon != existing.icon) {
          await repo.setIcon(existing.id, effectiveIcon);
        }
        if (_showInSmartList != existing.showInSmartList) {
          await repo.setShowInSmartList(existing.id, _showInSmartList);
        }
      }
    } on Object {
      setState(() => _error = existing == null ? '新建清单失败，请重试' : '移动到文件夹失败，请重试');
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final deleted = await confirmAndDeleteList(context, ref, widget.existing!);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final loadedFolders = ref.watch(foldersStreamProvider).valueOrNull;
    final folders = loadedFolders ?? const <TodoFolder>[];
    final byId = {for (final folder in folders) folder.id: folder};
    final selected = _folderLocalId;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? '重命名清单' : '新建清单',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // 嘀嗒 :86 方式一：名称前面的「图标」打开 Emoji 选择。
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: const Key('todo-list-editor-icon'),
                  customBorder: const CircleBorder(),
                  // 图标位本身就当「无」用：点它清掉已选 Emoji（:86 的面板含清除）。
                  onTap: () => setState(() {
                    _icon = null;
                    _error = null;
                  }),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: _icon != null
                        ? Text(_icon!, style: const TextStyle(fontSize: 24))
                        : Icon(
                            Icons.emoji_emotions_outlined,
                            size: 24,
                            color: Theme.of(context).hintColor,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '清单名',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Emoji 候选（方式一的展开面板）；长按上面的图标位清除回「无」。
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final emoji in kListEmojiChoices)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        key: Key(
                          'todo-list-editor-emoji-${emoji.runes.first.toRadixString(16)}',
                        ),
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() {
                          _icon = emoji;
                          _error = null;
                        }),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _icon == emoji
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // DropdownButton 自己的读屏节点只有当前值（实测 `label: "无"`），
            // 光看界面旁边那行「所属文件夹」，读屏用户听到的是"无 按钮"，
            // 不知道"无"是什么 ⇒ 把装饰器与控件并成一个节点一起念。
            MergeSemantics(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '所属文件夹',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButton<String?>(
                  key: const Key('todo-list-editor-folder'),
                  // 受控：值只由本 State 持有。FormField 版的 DropdownButtonFormField
                  // 首帧之后就不再看我传的初始值，"选完显示不更新"就是这么来的。
                  value: _folderLocalId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无'),
                    ),
                    for (final folder in folders)
                      DropdownMenuItem<String?>(
                        value: folder.id,
                        // 嵌套文件夹念成「父 / 子」：只给名字会撞车，看不出层级。
                        child: Text(_folderPath(folder, byId)),
                      ),
                    // 清单已有的归属必须出现在候选里：DropdownButton 会抛
                    // "There should be exactly one item with [DropdownButton]'s value: …"
                    // （本机 3.44.8 的原文，复核逐字纠正过我的转述）。
                    // 文件夹 stream 是异步的，首帧还没数据时先占一格；
                    // 真取不到（文件夹已不存在）也照样不炸。
                    if (selected != null && byId[selected] == null)
                      DropdownMenuItem<String?>(
                        value: selected,
                        child: Text(loadedFolders == null ? '加载中…' : '（已删除）'),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _folderLocalId = value;
                    _error = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 嘀嗒 :73 第四个属性「在智能清单中显示/隐藏」：关掉后该清单的任务
            // 不进智能清单与徽章计数，但选中清单本身仍能看到。
            SwitchListTile(
              key: const Key('todo-list-editor-show-in-smart'),
              contentPadding: EdgeInsets.zero,
              title: const Text('在智能清单中显示'),
              value: _showInSmartList,
              onChanged: (value) => setState(() {
                _showInSmartList = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 4),
            KeyedSubtree(
              key: const Key('todo-list-editor-color-row'),
              child: Row(
                children: [
                  const Text('颜色'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // 「无」不显示选中标记：默认无色时整行不应假装有选中
                        // （specs/102 用例钉死这一点），点「无」只是把 _color 归 null。
                        _ColorSwatch(
                          key: const Key('todo-list-editor-color-none'),
                          selected: false,
                          onTap: () => setState(() {
                            _color = null;
                            _error = null;
                          }),
                        ),
                        for (final hex in kListColorChoices)
                          _ColorSwatch(
                            key: Key(
                              'todo-list-editor-color-'
                              '${hex.substring(1).toLowerCase()}',
                            ),
                            color: listColorFromHex(hex),
                            selected: _color == hex,
                            onTap: () => setState(() {
                              _color = hex;
                              _error = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isEdit)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _folderPath(TodoFolder folder, Map<String, TodoFolder> byId) {
  final segments = <String>[folder.name];
  var parent = folder.parentId == null ? null : byId[folder.parentId];
  var guard = 0;
  while (parent != null && guard++ < 10) {
    segments.insert(0, parent.name);
    parent = parent.parentId == null ? null : byId[parent.parentId];
  }
  return segments.join(' / ');
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: color == null ? Border.all(color: theme.dividerColor) : null,
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 20,
                color: color == null
                    ? theme.colorScheme.onSurface
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
