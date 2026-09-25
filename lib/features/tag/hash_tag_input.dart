import '../../state/repositories/tag_repository.dart';

/// 「#标签」词法与落地（嘀嗒《01-任务/08-如何管理海量任务/04-用标签管理任务.md》:48/:61）。
///
/// 拆成"纯词法 + 一次仓储解析"两步是有意的：词法可以在不启动 Flutter、不碰数据库的前提下
/// 逐条证伪；而"已有同名就用它、没有才建"必须对着真表跑，两者混在一个函数里就各半边都测不动。
class HashTagDraft {
  const HashTagDraft({required this.title, required this.tagNames});

  /// 剥掉 `#token` 后剩下的正文（保留换行，`TaskRepository.createBatch` 靠它切多条任务）。
  final String title;

  /// 出现顺序去重后的标签名（未 trim 的原样已在此处清理）。
  final List<String> tagNames;
}

bool _isSpaceAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  return unit == 0x20 || unit == 0x09;
}

/// 把输入里的 `#名称` 剥成标签名，正文里不留井号原文。
///
/// 词边界规则（spec.md 取舍 1、2）：`#` 必须在行首或空白之后，`#` 后紧跟空白或 `#` 都不算标签
/// ⇒ `进度 50#`、`##草稿`、`C#` 都按普通文字处理。名字到下一个空白为止，
/// 所以带空格的标签名走标签弹层里的「新建标签」那一行，不走 `#`。
HashTagDraft parseHashTagInput(String input) {
  final tagNames = <String>[];
  final seen = <String>{};
  final keptLines = <String>[];

  for (final line in input.split(RegExp(r'\r?\n'))) {
    final buffer = StringBuffer();
    var removedToken = false;
    var index = 0;
    while (index < line.length) {
      final atBoundary = index == 0 || _isSpaceAt(line, index - 1);
      final next = index + 1 < line.length ? line[index + 1] : null;
      final isToken =
          line[index] == '#' &&
          atBoundary &&
          next != null &&
          next != '#' &&
          !_isSpaceAt(line, index + 1);
      if (!isToken) {
        buffer.write(line[index]);
        index += 1;
        continue;
      }
      var end = index + 1;
      while (end < line.length && !_isSpaceAt(line, end)) {
        end += 1;
      }
      final name = line.substring(index + 1, end).trim();
      if (name.isNotEmpty && seen.add(name)) tagNames.add(name);
      index = end;
      removedToken = true;
    }
    // 只有真剥掉过 token 的行才收拢空白：没井号的行一个字都不该被改动。
    keptLines.add(
      removedToken
          ? buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim()
          : line.trim(),
    );
  }

  return HashTagDraft(title: keptLines.join('\n'), tagNames: tagNames);
}

/// 名字 → 标签 id：已有同名就用它，没有就建。
///
/// 匹配是 `trim()` 后**逐字**相等，不做大小写折叠（spec.md 取舍 2）。
/// `todoTags` 没有 name 唯一索引，库里可能已有重名行 ⇒ 取 `getAll()`（`createdAt` 升序）
/// 的第一条，与标签页看到的先后一致；同一次调用里重复出现的名字复用刚建的那条。
Future<List<String>> resolveTagIdsByName({
  required TagRepository repo,
  required List<String> names,
}) async {
  if (names.isEmpty) return const [];
  final known = await repo.getAll();
  final ids = <String>[];
  for (final raw in names) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final existing = known.where((tag) => tag.name == name).firstOrNull;
    if (existing != null) {
      ids.add(existing.id);
      continue;
    }
    final created = await repo.create(name: name);
    known.add(created);
    ids.add(created.id);
  }
  return ids;
}
