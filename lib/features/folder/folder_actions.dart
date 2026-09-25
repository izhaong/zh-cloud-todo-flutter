import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// M11-B2 文件夹的「解散」动作。
///
/// 嘀嗒《01-任务/09-如何管理海量任务/01-用文件夹管理任务.md》
/// `:28`「# 解散文件夹」、`:30`「在移动端可通过左滑、长按的方式，解散文件夹。」
/// ⇒ 用词是**解散**（不是"删除"）。
///
/// 确认口径原先只有 `FolderPage` 一份，而那一页没有任何入口能走到
/// （其宿主 `ListPage` 全仓零挂载）⇒ 本文件把它抽成侧栏与 `FolderPage` 共用的一个函数，
/// 与 specs/026 对清单「编辑/删除」做的收口同形。

/// 弹出「解散文件夹」确认框。返回 true = 已解散。
///
/// 失败时**框不关**：错误写在框里、可以直接重试 ⇒ 不会出现"框关了、文件夹还在、
/// 用户以为解散好了"的静默失败。
Future<bool> confirmAndDisbandFolder(
  BuildContext context,
  TodoFolder folder,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DisbandFolderDialog(folder: folder),
  );
  return ok == true;
}

class _DisbandFolderDialog extends ConsumerStatefulWidget {
  const _DisbandFolderDialog({required this.folder});

  final TodoFolder folder;

  @override
  ConsumerState<_DisbandFolderDialog> createState() =>
      _DisbandFolderDialogState();
}

class _DisbandFolderDialogState extends ConsumerState<_DisbandFolderDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _confirm() async {
    // 同步闸门：禁用态要到下一次 build 才生效，同一帧连点两下会真的解散两次
    // ⇒ 第二次会把已经空掉的归属再清一遍、多打一条 outbox。
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(folderRepositoryProvider);
    if (repo == null) {
      setState(() {
        _busy = false;
        _error = '本地数据库尚未就绪，文件夹没有解散';
      });
      return;
    }
    try {
      await repo.delete(widget.folder.id);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '解散失败，请重试';
      });
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('解散文件夹'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确认解散"${widget.folder.name}"？\n'
            '其下清单将移至"未分组"，直接子文件夹将提升为顶层。',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const Key('todo-folder-disband-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('todo-folder-disband-confirm'),
          onPressed: _confirm,
          child: const Text('解散'),
        ),
      ],
    );
  }
}
