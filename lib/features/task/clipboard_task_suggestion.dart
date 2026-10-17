import '../../state/nlp_date.dart';

/// 冷启动读剪贴板之后，该不该问、问哪一句（FL #343）。
///
/// 判据源：嘀嗒《02-功能指南/01-任务/01-添加任务.md》：
/// - `:260`「如果你复制的内容中带有**时间等特殊信息**，可以通过「剪贴板添加任务」功能…」
/// - `:262`「在「设置」-「高级选项」- 开启「剪贴板添加任务」」
/// - `:264`「如果剪贴板的内容包含"时间信息"时，打开应用后会在下方询问
///   「**你可能想添加任务...**」，点击添加，即可创建成功」
/// - `:269`「如果当前剪贴板中无内容，或者内容中**无可被识别的信息**时，
///   **将不会获得询问**」
/// - `:273`「复制**多个换行文本**，打开 app 后将会询问：
///   「**是否将每一行文本添加为独立的任务**」」
///
/// 三句话对应三种结果，这里只做**判定**（纯函数，便于判据）；提示与落库在别处。
enum ClipboardTaskPromptKind {
  /// 单条：剪贴板里有**可识别的时间信息** ⇒ 问「你可能想添加任务…」。
  single,

  /// 多条：剪贴板是**多行文本** ⇒ 问「是否将每一行文本添加为独立的任务」。
  multiple,
}

class ClipboardTaskSuggestion {
  const ClipboardTaskSuggestion({
    required this.kind,
    required this.tasks,
    this.matchedTimeText,
  });

  final ClipboardTaskPromptKind kind;

  /// 要建的标题：多条时**每行一条**（空行不算，不算成一条空任务）。
  final List<String> tasks;

  /// 单条时命中的那段"时间信息"原文，用来在提示里回显（"你可能想添加任务…"）。
  final String? matchedTimeText;
}

/// 判定"这条剪贴板内容该不该问"。
///
/// - 空 / 只有空白 ⇒ `null`（`:269` 的"无内容"，**不问**）；
/// - **两行及以上** ⇒ `multiple`（`:273`；这一支**不要求**时间信息 ——
///   原文把"多行"当成独立的一条路，没提时间）；
/// - 一行且**能识别出时间** ⇒ `single`（`:264`）；
/// - 一行但**识别不出** ⇒ `null`（`:269` 的"无可被识别的信息"，**不问**）。
ClipboardTaskSuggestion? suggestTasksFromClipboard(
  String? raw, {
  NlpDateParser? parser,
}) {
  if (raw == null) return null;
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) return null;
  if (lines.length >= 2) {
    return ClipboardTaskSuggestion(
      kind: ClipboardTaskPromptKind.multiple,
      tasks: lines,
    );
  }
  final matched = (parser ?? NlpDateParser()).parse(lines.single);
  if (matched == null) return null;
  return ClipboardTaskSuggestion(
    kind: ClipboardTaskPromptKind.single,
    tasks: [lines.single],
    matchedTimeText: matched.matchedText,
  );
}
