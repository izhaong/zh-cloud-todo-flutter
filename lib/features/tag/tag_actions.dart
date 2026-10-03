import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// 侧栏标签行的动作表（左滑或长按唤出）。
///
/// 只放「置顶」一项：嘀嗒《04-用标签管理任务》:79/:94 那三个选项里的
/// 「编辑」「删除」在本端是**点标签行即到**的同一层入口（侧栏标签行的 onTap
/// 走 `_openTags(initialTagId: tag.id)`，落到 `TagPage` 里该标签的
/// `Icons.edit_outlined` / `Icons.delete_outline`），这里再放两个只会跳转的
/// 磁贴就是"菜单里有、点了不做事"的假档。
Future<void> showTagActions(
  BuildContext context,
  WidgetRef ref,
  TodoTag tag,
) async {
  String? pinError;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pinError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  pinError!,
                  key: const Key('sidebar-tag-pin-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ListTile(
              key: const Key('sidebar-tag-action-pin'),
              leading: Icon(
                tag.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(tag.isPinned ? '取消置顶' : '置顶'),
              // 就地处理：失败时表还开着、错误就在眼前，不吞进谁也没看见的 SnackBar。
              onTap: () async {
                final repo = ref.read(tagRepositoryProvider);
                if (repo == null) {
                  if (sheetContext.mounted) {
                    setSheetState(() => pinError = '标签数据还没准备好，稍后再试');
                  }
                  return;
                }
                try {
                  await repo.setPinned(tag.id, !tag.isPinned);
                } on Object catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(
                      () => pinError = '置顶失败：${describeError(e)}，标签列表仍是原来的',
                    );
                  }
                  return;
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
