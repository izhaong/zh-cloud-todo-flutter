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

    // 「N点半」在判据源《05-智能识别》里没有任何规则，而三条分支的正则都只吃到「N点」，
    // 会把「半」静默丢掉、给出 9:00 这种**自信的错值**。原文没写就不认领：整串拒识，
    // 让快速添加不显示「已识别截止时间」，用户自己把时间填对。
    if (RegExp(r'\d\s*[点时]\s*半').hasMatch(lower)) return null;

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
    final tomorrowRe = RegExp(
      r'(明天|后天|tomorrow)(?:\s*)?(\d{1,2})(?:[:：.](\d{1,2}))?(?:[\s]*([点时])|[\s]*(am|pm))?',
    );
    final tm = tomorrowRe.firstMatch(lower);
    if (tm != null) {
      final offset = lower.contains('后天') || lower.contains('day after')
          ? 2
          : 1;
      final hour = int.parse(tm.group(2)!);
      final minute = int.tryParse(tm.group(3) ?? '') ?? 0;
      final base = _todayAtMidnight(now).add(Duration(days: offset));
      return ResolvedDate(
        DateTime(
          base.year,
          base.month,
          base.day,
          _adjustHour(hour, tm.group(5) ?? tm.group(4)),
          minute,
        ),
        tm.group(0)!,
      );
    }

    // "今天 14:30" / "今天下午 3 点"
    final todayRe = RegExp(
      r'(今天|今日|today)(?:\s*)?(\d{1,2})(?:[:：.](\d{1,2}))?',
    );
    final tdm = todayRe.firstMatch(lower);
    if (tdm != null) {
      final base = _todayAtMidnight(now);
      final hour = int.parse(tdm.group(2)!);
      final minute = int.tryParse(tdm.group(3) ?? '') ?? 0;
      return ResolvedDate(
        DateTime(base.year, base.month, base.day, hour, minute),
        tdm.group(0)!,
      );
    }

    return _parseBareTime(lower, input, now);
  }

  /// 裸时间点：嘀嗒《03-特色功能/05-智能识别.md》:13 的例子「9点提醒我」不带日期词。
  ///
  /// 同一条原文给的是「统一识别成**最近有效**的日期和时间」，所以不猜上午下午：
  /// 把 {h, h+12}（h<12 时）× {今天, 明天} 都当候选，取**严格晚于当前时刻**的最早一个。
  /// 钟点提示只从**原文输入**里读——上面的预处理会把「上午 / 早上 / 晚上 」整段删掉。
  ResolvedDate? _parseBareTime(String lowered, String raw, DateTime now) {
    final bare = RegExp(
      r'(\d{1,2})\s*[点时](?:(\d{1,2})分?)?',
    ).firstMatch(lowered);
    if (bare == null) return null;
    final hour = int.parse(bare.group(1)!);
    final minute = int.tryParse(bare.group(2) ?? '') ?? 0;
    if (hour > 23 || minute > 59) return null;
    final midnight = _todayAtMidnight(now);
    final candidates = <DateTime>[];
    for (final h in _hourReadings(hour, raw)) {
      for (final offset in const [0, 1]) {
        final base = midnight.add(Duration(days: offset));
        candidates.add(DateTime(base.year, base.month, base.day, h, minute));
      }
    }
    candidates.sort();
    for (final dt in candidates) {
      if (dt.isAfter(now)) return ResolvedDate(dt, bare.group(0)!);
    }
    return null;
  }

  /// 中文 12 小时制提示：有提示就只留对应读法，没提示就两种都留给「最近有效」去挑。
  List<int> _hourReadings(int hour, String raw) {
    final pm = RegExp(r'下午|晚上|傍晚|夜里|半夜').hasMatch(raw);
    final am = RegExp(r'早上|上午|中午|凌晨').hasMatch(raw);
    if (pm && hour < 12) return [hour + 12];
    if (am && hour == 12) return [0, 12];
    if (am || pm) return [hour];
    if (hour == 0 || hour > 12) return [hour];
    return hour == 12 ? [12] : [hour, hour + 12];
  }

  DateTime _todayAtMidnight(DateTime now) =>
      DateTime(now.year, now.month, now.day);
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
