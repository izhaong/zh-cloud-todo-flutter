import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/state/nlp_date.dart';

/// 矩阵 #83「智能识别」的**带日期词 + 分钟**一面（FL Issue #390）。
///
/// 判据源逐字：嘀嗒《03-特色功能/05-智能识别.md》:13
/// 「当你在清单中输入的是模糊日期时，滴答清单会统一识别成最近有效的**日期和时间**」
/// —— 「30 分」是「时间」的一部分。`明天9:30` 这条一直是对的（冒号形有分钟段），
/// 坏的是 `明天9点30分` / `今天9点30分`：那两条旧正则的分钟段只认 `[:：.]`，
/// 「点」后面的分钟没人收 ⇒ 给出一个看起来成功的**整点**，属自信错值。
void main() {
  NlpDateParser at(DateTime now) => NlpDateParser(nowProvider: () => now);
  final morning = DateTime(2026, 9, 28, 8, 0);

  group('带日期词的「N点M分」要吃进分钟（#390）', () {
    test('「明天9点30分」→ 次日 09:30，不是 09:00', () {
      final r = at(morning).parse('明天9点30分');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 30));
    });

    test('「今天9点30分」→ 当天 09:30，不是 09:00', () {
      final r = at(morning).parse('今天9点30分');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 28, 9, 30));
    });

    test('「后天9点30分」→ 第三天 09:30（偏移档位不吃分）', () {
      final r = at(morning).parse('后天9点30分');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 30, 9, 30));
    });

    test('识别出来的短语要覆盖整串「明天9点30分」，不能只框到「明天9点」', () {
      final r = at(morning).parse('明天9点30分');
      expect(r, isNotNull);
      expect(r!.matchedText, '明天9点30分');
    });
  });

  group('改分钟段时不能碰坏的三形（回归）', () {
    test('冒号形「明天9:30」照旧 → 次日 09:30', () {
      final r = at(morning).parse('明天9:30');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 30));
    });

    test('整点形「明天9点」照旧 → 次日 09:00', () {
      final r = at(morning).parse('明天9点');
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 9, 29, 9, 0));
    });

    test('「明天9点半」仍整条不识别（#387 的取舍，不许被分钟段顺手吃掉）', () {
      expect(at(morning).parse('明天9点半'), isNull);
    });

    test('「今天9点半」同样不识别', () {
      expect(at(morning).parse('今天9点半'), isNull);
    });
  });

  group('新收进来的分钟必须是有效分钟（不吞自信错值）', () {
    test('「明天9点75分」→ 不识别，而不是 DateTime(9,75) 滚成 10:15', () {
      expect(at(morning).parse('明天9点75分'), isNull);
    });

    test('「今天9点75分」→ 不识别（两条分支同一条守卫）', () {
      expect(at(morning).parse('今天9点75分'), isNull);
    });

    test('冒号形「明天9:75」也不识别：守卫按同一处判断，不分新旧形', () {
      expect(at(morning).parse('明天9:75'), isNull);
    });
  });
}
