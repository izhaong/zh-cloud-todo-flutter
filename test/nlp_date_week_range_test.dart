import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/state/nlp_date.dart';

/// specs/133 · 智能识别「周X / 下周X / N天后 / 大后天 / 月底」本地正则
/// （矩阵 #83 面② 正则覆盖面）。
///
/// 判据源：嘀嗒《03-特色功能/05-智能识别.md》——用户可输入这些时间短语。
void main() {
  DateTime parse(String input, {DateTime? now}) {
    final fixed = now ?? DateTime(2026, 7, 15, 10); // 2026-07-15 是周三
    final parser = NlpDateParser(nowProvider: () => fixed);
    return parser.parse(input)!.date;
  }

  group('周X（本周）', () {
    // 2026-07-15 是周三；周五是本周第 5 天 → delta = 2。
    test('周五 → 本周五', () {
      expect(parse('周五交报告'), DateTime(2026, 7, 17));
    });

    test('周日 → 本周日（delta=4）', () {
      expect(parse('周日开会'), DateTime(2026, 7, 19));
    });

    test('周三（同日）→ 下周三（delta=7，不回看今天）', () {
      expect(parse('周三复盘'), DateTime(2026, 7, 22));
    });
  });

  group('下周X', () {
    test('下周三 → 下周三（本周三 + 7）', () {
      expect(parse('下周三交'), DateTime(2026, 7, 22));
    });

    test('下周一 → 下周一', () {
      // 本周三(3) → 下周一(1) = (1-3)%7 + 7 = 5
      expect(parse('下周一启动'), DateTime(2026, 7, 20));
    });
  });

  group('N天后', () {
    test('3天后', () {
      expect(parse('3天后回访'), DateTime(2026, 7, 18));
    });

    test('30天后', () {
      expect(parse('30天后复盘'), DateTime(2026, 8, 14));
    });

    test('0天后不识别（非法）', () {
      final parser = NlpDateParser(
        nowProvider: () => DateTime(2026, 7, 15, 10),
      );
      expect(parser.parse('0天后'), isNull);
    });
  });

  group('大后天', () {
    test('大后天 = 3 天后', () {
      expect(parse('大后天交'), DateTime(2026, 7, 18));
    });
  });

  group('月底', () {
    test('7 月底 → 7-31', () {
      expect(parse('月底总结'), DateTime(2026, 7, 31));
    });

    test('2 月底 → 2-28（非闰年）', () {
      expect(
        parse('月底交', now: DateTime(2027, 2, 10, 10)),
        DateTime(2027, 2, 28),
      );
    });
  });

  group('既有模式不回归', () {
    test('明天 9 点照常', () {
      expect(parse('明天9点开会'), DateTime(2026, 7, 16, 9));
    });

    test('今天下午 3 点照常', () {
      expect(parse('今天下午3点'), DateTime(2026, 7, 15, 15));
    });

    test('绝对日期照常（时间取当前小时，现状锁）', () {
      expect(parse('2026-08-01'), DateTime(2026, 8, 1, 10));
    });

    test('后天 9 点照常（后天需要带时间数字，现状锁）', () {
      expect(parse('后天9点'), DateTime(2026, 7, 17, 9));
    });
  });

  group('优先级不回归（新模式不吃掉旧模式）', () {
    test('「明天9点」不被周X 模式抢先', () {
      expect(parse('明天9点'), DateTime(2026, 7, 16, 9));
    });

    test('「今天下午3点」不被月底模式抢先', () {
      expect(parse('今天下午3点'), DateTime(2026, 7, 15, 15));
    });
  });
}
