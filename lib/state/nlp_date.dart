/// 极简中文/英文日期自然语言识别（任务标题中的"明天下午 3 点"等）。
///
/// 完整版依赖后端 `/app-api/todo/nlp`；这里的前端正则在本地给出常见模式的
/// 解析结果用于即时反馈，落库前可以再交给后端覆盖。
class ResolvedDate {
  const ResolvedDate(this.date, this.matchedText);
  final DateTime date;
  final String matchedText;
}

class NlpDateParser {
  NlpDateParser({DateTime Function()? nowProvider})
      : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;

  /// 解析文本中第一个可识别的相对/绝对日期时间短语；无法识别时返回 null。
  ResolvedDate? parse(String input) {
    if (input.isEmpty) return null;
    // 把"早上/上午/下午/晚上"合并到其后的数字，避免它们占据"数字"槽位。
    var working = input;
    for (final phrase in const ['早上', '上午', '晚上']) {
      working = working.replaceAll('$phrase ', '');
    }
    working = working.replaceAll('下午 ', '下午');
    final lower = working.toLowerCase();
    final now = _nowProvider();

    // 显式绝对日期：YYYY-M-D / YYYY/M/D / YYYY.M.D
    final absolute = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})');
    final m = absolute.firstMatch(lower);
    if (m != null) {
      final dt = DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        _defaultHour(now),
      );
      return ResolvedDate(dt, m.group(0)!);
    }

    // "明天 8 点" / "明天 8:30" / "tomorrow 8am"
    final tomorrowRe = RegExp(r'(明天|后天|tomorrow)(?:\s*)?(\d{1,2})(?:[:：.](\d{1,2}))?(?:[\s]*([点时])|[\s]*(am|pm))?');
    final tm = tomorrowRe.firstMatch(lower);
    if (tm != null) {
      final offset = lower.contains('后天') || lower.contains('day after') ? 2 : 1;
      final hour = int.parse(tm.group(2)!);
      final minute = int.tryParse(tm.group(3) ?? '') ?? 0;
      final base = _todayAtMidnight(now).add(Duration(days: offset));
      return ResolvedDate(
        DateTime(base.year, base.month, base.day, _adjustHour(hour, tm.group(5) ?? tm.group(4)), minute),
        tm.group(0)!,
      );
    }

    // "今天 14:30" / "今天下午 3 点"
    final todayRe = RegExp(r'(今天|今日|today)(?:\s*)?(\d{1,2})(?:[:：.](\d{1,2}))?');
    final tdm = todayRe.firstMatch(lower);
    if (tdm != null) {
      final base = _todayAtMidnight(now);
      final hour = int.parse(tdm.group(2)!);
      final minute = int.tryParse(tdm.group(3) ?? '') ?? 0;
      return ResolvedDate(DateTime(base.year, base.month, base.day, hour, minute), tdm.group(0)!);
    }

    return null;
  }

  DateTime _todayAtMidnight(DateTime now) => DateTime(now.year, now.month, now.day);
  int _defaultHour(DateTime now) => now.hour;

  int _adjustHour(int hour, String? suffix) {
    if (suffix == null) return hour;
    if (suffix.contains('pm') && hour < 12) return hour + 12;
    if (suffix.contains('am') && hour == 12) return 0;
    // 中文 "点" 表示 24h。
    if (hour >= 24) return hour - 24;
    return hour;
  }
}
