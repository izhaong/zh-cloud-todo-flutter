import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/state/nlp_date.dart';

void main() {
  group('NlpDateParser', () {
    final now = DateTime(2026, 6, 15, 9, 0);
    final parser = NlpDateParser(nowProvider: () => now);

    test('识别"明天 8 点"', () {
      final r = parser.parse('明天早上 8 点开会');
      expect(r, isNotNull);
      expect(r!.matchedText, contains('明天'));
      expect(r.date, DateTime(2026, 6, 16, 8));
    });

    test('识别"后天 14:30"', () {
      final r = parser.parse('后天 14:30');
      expect(r?.date, DateTime(2026, 6, 17, 14, 30));
    });

    test('识别绝对日期', () {
      final r = parser.parse('2026-08-15 交付');
      expect(r?.date.year, 2026);
      expect(r?.date.month, 8);
      expect(r?.date.day, 15);
    });

    test('识别"今天 18 点"', () {
      final r = parser.parse('今天 18 点');
      expect(r?.date, DateTime(2026, 6, 15, 18));
    });

    test('纯文本无日期返回 null', () {
      expect(parser.parse('普通备忘'), isNull);
    });
  });
}
