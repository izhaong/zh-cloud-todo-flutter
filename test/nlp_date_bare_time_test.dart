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

  // 判据源《05-智能识别》只给了「最近有效的日期和时间」那一条规则，全页没有「半」这个写法。
  // 静默把「9点半」读成 9:00 是**自信错值**（比"没识别"更坏）⇒ 宁可整串拒识，也不给半个时间。
  group('原文未定义的「半」→ 拒识，不给静默错值', () {
    test('裸钟点「9点半」→ null', () {
      expect(at(DateTime(2026, 9, 28, 9, 0)).parse('9点半'), isNull);
    });

    test('「明天9点半」→ null（旧「明天」分支同样只吃「9点」，一并拒识而不是留不一致）', () {
      expect(at(DateTime(2026, 9, 28, 9, 0)).parse('明天9点半'), isNull);
    });

    test('「今天9点半」→ null', () {
      expect(at(DateTime(2026, 9, 28, 9, 0)).parse('今天9点半'), isNull);
    });

    test('带分钟的正常写法不受影响：「9点30分」仍解析为 09:30', () {
      final r = at(DateTime(2026, 9, 28, 8, 0)).parse('9点30分');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 9, 30));
    });
  });

  // AM 与 PM 提示词同时出现时原文没有任何规则 ⇒ 行为**未定义**。
  // 这条用例不是认领语义，是把现状钉住：现在 `_hourReadings` 的 PM 分支在前，先命中即返回。
  group('AM/PM 提示词同现（未定义，仅钉现状）', () {
    test('「早上晚上9点」按现状走 PM ⇒ 当天 21:00', () {
      final r = at(DateTime(2026, 9, 28, 9, 0)).parse('早上晚上9点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 21, 0));
    });
  });
}
