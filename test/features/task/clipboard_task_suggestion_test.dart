import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/clipboard_task_suggestion.dart';
import 'package:zh_cloud_todo_flutter/state/nlp_date.dart';

/// FL #343：冷启动读剪贴板该不该问。判据源是嘀嗒《01-任务/01-添加任务.md》的四句话，
/// 每一条判据都对着其中一句（引在下面），**不自己发明规则**。
void main() {
  NlpDateParser parser() =>
      NlpDateParser(nowProvider: () => DateTime(2026, 10, 17, 9));

  test(':269「无内容」⇒ 不问', () {
    expect(suggestTasksFromClipboard(null, parser: parser()), isNull);
    expect(suggestTasksFromClipboard('', parser: parser()), isNull);
    // 只有空白/空行也属于"无内容"，不是"有两条空任务"
    expect(suggestTasksFromClipboard('   \n\n  ', parser: parser()), isNull);
  });

  test(':264「内容含时间信息」⇒ 单条，并把命中的那段回显出来', () {
    final suggestion = suggestTasksFromClipboard(
      '明天下午3点 交周报',
      parser: parser(),
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, ClipboardTaskPromptKind.single);
    expect(suggestion.tasks, ['明天下午3点 交周报']);
    expect(
      suggestion.matchedTimeText,
      isNotNull,
      reason: '提示里要回显"识别到的时间"，否则用户不知道它为什么问',
    );
  });

  test(':269「无可被识别的信息」⇒ 不问', () {
    // 这句是这一档的关键：**不是"有没有内容"，是"能不能认出信息"**。
    expect(
      suggestTasksFromClipboard('把这句话粘进去但它没有时间', parser: parser()),
      isNull,
      reason: '认不出时间还弹"你可能想添加任务…"= 每次复制任何东西都弹，用户会关掉它',
    );
  });

  test(':273「多个换行文本」⇒ 多条，每行一条', () {
    final suggestion = suggestTasksFromClipboard(
      '买牛奶\n\n写周报\n给妈妈打电话\n',
      parser: parser(),
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, ClipboardTaskPromptKind.multiple);
    expect(suggestion.tasks, [
      '买牛奶',
      '写周报',
      '给妈妈打电话',
    ], reason: '空行不算一条（否则会建出空任务）；首尾空行同理');
  });

  test(':273 多行那一支**不要求**时间信息', () {
    // 原文把"多行"当成独立的一条路，没提时间。两行都没有时间也必须问 ——
    // 否则"复制三行待办"这种最典型的用法反而不弹。
    final suggestion = suggestTasksFromClipboard('买牛奶\n写周报', parser: parser());

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, ClipboardTaskPromptKind.multiple);
  });
}
