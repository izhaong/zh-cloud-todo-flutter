import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/clipboard_add_task_setting.dart';
import '../../state/providers.dart';
import 'clipboard_task_suggestion.dart';
// 收集箱的本地 id 在页面那侧已有定义（本仓现有两处同名 const）——这里只借用，不再抄第三份。
import 'tasks_by_list_page.dart' show kInboxListId;

/// 「剪贴板添加任务」的落库那一半（FL #343）。
///
/// 判定在 [suggestTasksFromClipboard]（纯函数，判据在那边）；这里只负责
/// **问一句**和**建任务**。两句话逐字照抄原文：
/// - `:264`「你可能想添加任务...」
/// - `:273`「是否将每一行文本添加为独立的任务」
///
/// 默认**关**（`:262` 是"开启"这个动作）：读剪贴板是**这台设备**的行为，
/// 不能让用户没同意就被读。
Future<void> runClipboardAddTaskFlow(
  BuildContext context,
  WidgetRef ref, {
  ClipboardAddTaskSetting? setting,
}) async {
  final enabled = await (setting ?? ClipboardAddTaskSetting()).read();
  if (!enabled || !context.mounted) return;

  final raw = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (!context.mounted) return;
  final suggestion = suggestTasksFromClipboard(raw);
  if (suggestion == null) return; // `:269` 无内容/无可识别信息 ⇒ 不问

  final messenger = ScaffoldMessenger.of(context);
  final isSingle = suggestion.kind == ClipboardTaskPromptKind.single;
  messenger.showSnackBar(
    SnackBar(
      content: Text(isSingle ? '你可能想添加任务…' : '是否将每一行文本添加为独立的任务'),
      action: SnackBarAction(
        label: '添加',
        onPressed: () => _createTasks(ref, suggestion, messenger),
      ),
    ),
  );
}

Future<void> _createTasks(
  WidgetRef ref,
  ClipboardTaskSuggestion suggestion,
  ScaffoldMessengerState messenger,
) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null) {
    messenger.showSnackBar(const SnackBar(content: Text('请先登录')));
    return;
  }
  var created = 0;
  for (final title in suggestion.tasks) {
    // 标题原样落库：时间信息由既有的标题解析（`nlp_date`）在创建后处理，
    // 这里**不改写用户粘进来的原文** —— 改写了用户就不知道自己建的是什么。
    await repository.create(listId: kInboxListId, title: title);
    created++;
  }
  messenger.showSnackBar(SnackBar(content: Text('已添加 $created 条任务')));
}
