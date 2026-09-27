import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/state/nlp_date.dart';

/// 矩阵 #83「智能识别」的裸时间点一面（FL Issue #387）。
///
/// 判据源逐字：嘀嗒《03-特色功能/05-智能识别.md》`:13`
/// 「当你在清单中输入的是模糊日期时，滴答清单会统一识别成**最近有效的日期和时间**。
/// 比如：当前实际时间是下午4点，当输入"9点提醒我"时，会被识别成今天晚上9点)」
void main() {
  NlpDateParser at(DateTime now) => NlpDateParser(nowProvider: () => now);

  group('《05-智能识别》:13 的「最近有效的日期和时间」', () {
    test('原文例子：16:00 输入「9点提醒我」→ 今天晚上 9 点', () {
      final r = at(DateTime(2026, 9, 28, 16, 0)).parse('9点提醒我');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 21, 0));
      expect(r.matchedText, '9点');
    });

    test('当天所有可读钟点都已过 → 滚到次日的最早有效点', () {
      final r = at(DateTime(2026, 9, 28, 22, 30)).parse('9点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 0));
    });

    test('「下午3点」在 09:00 输入 → 当天下午 3 点，不绕到明天', () {
      final r = at(DateTime(2026, 9, 28, 9, 0)).parse('下午3点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 15, 0));
    });

    test('「上午9点」在 22:30 输入 → 只在 09:00 这一读法里取最近有效', () {
      final r = at(DateTime(2026, 9, 28, 22, 30)).parse('上午9点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 0));
    });

    test('带分钟：「10点20分」在 09:00 → 当天 10:20', () {
      final r = at(DateTime(2026, 9, 28, 9, 0)).parse('10点20分');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 10, 20));
    });

    test('正好等于当前时刻不算「有效」→ 取下一个同名钟点', () {
      final r = at(DateTime(2026, 9, 28, 16, 0)).parse('16点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 16, 0));
    });

    test('没有钟点词仍是 null（不顺手扩面）', () {
      final p = at(DateTime(2026, 9, 28, 16, 0));
      expect(p.parse('买牛奶'), isNull);
      expect(p.parse('3天后再说'), isNull);
    });

    test('带日期词的仍走原分支：「明天9点」= 次日 09:00', () {
      final r = at(DateTime(2026, 9, 28, 16, 0)).parse('明天9点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 0));
    });

    test('「今天下午3点」在 09:00 → 当天 15:00（旧「今天」正则要求数字紧跟日期词，这面由裸时间分支兜住）', () {
      final r = at(DateTime(2026, 9, 28, 9, 0)).parse('今天下午3点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 15, 0));
    });
  });
}
