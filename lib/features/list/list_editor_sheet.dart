import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'list_actions.dart';

/// M11-B2 清单创建 / 重命名 / 删除 弹窗。
///
/// 嘀嗒《01-任务/09-如何管理海量任务/02-用清单管理任务.md》:73
/// 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
/// 本轮补的是「所属文件夹」（颜色与图标要新增列，见 specs/049 的范围说明）。
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    // FR-3 编辑时预选当前归属；FR-5 从文件夹里点新建时沿用带入的归属。
    _folderLocalId = widget.existing?.folderLocalId ?? widget.folderLocalId;
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
    try {
      // 先移动再改名：移动失败时改名还没发生，弹层里不会出现"半改好"的清单。
      if (existing == null) {
        await repo.create(name: text, folderLocalId: _folderLocalId);
      } else {
        if (_folderLocalId != existing.folderLocalId) {
          await repo.moveToFolder(existing.id, _folderLocalId);
        }
        if (text != existing.name) await repo.rename(existing.id, text);
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
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '清单名',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
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
                    // 清单已有的归属必须出现在候选里，否则 DropdownButton 会断言
                    // "exactly one item with the value"。文件夹 stream 是异步的，
                    // 首帧还没数据时先占一格；真取不到（文件夹已不存在）也照样不炸。
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
