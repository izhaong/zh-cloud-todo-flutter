import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/time/week_start.dart';

/// 嘀嗒《01-欢迎/03-常见问题.md:134》「点击「设置」-「日期与时间」-「星期开始于」，
/// 你可以选择“周日”、“周一”、或”周六“任意一天为一周的开始。」
void main() {
  group('startOf', () {
    test('默认档 = 周一：与本仓 develop 既有行为一致（9 张黄金基线不重录的前提）', () {
      expect(WeekStart.defaultFirstDay, DateTime.monday);
      // 2026-09-25 是周五
      expect(WeekStart.startOf(DateTime(2026, 9, 25)), DateTime(2026, 9, 21));
      // 周一自己就是起点
      expect(WeekStart.startOf(DateTime(2026, 9, 21)), DateTime(2026, 9, 21));
      // 周日是一周的最后一天，回退 6 天
      expect(WeekStart.startOf(DateTime(2026, 9, 27)), DateTime(2026, 9, 21));
    });

    test('周日档：周日自身是起点，周一往后退一天', () {
      expect(
        WeekStart.startOf(DateTime(2026, 9, 27), firstDay: DateTime.sunday),
        DateTime(2026, 9, 27),
      );
      expect(
        WeekStart.startOf(DateTime(2026, 9, 28), firstDay: DateTime.sunday),
        DateTime(2026, 9, 27),
      );
      expect(
        WeekStart.startOf(DateTime(2026, 9, 25), firstDay: DateTime.sunday),
        DateTime(2026, 9, 20),
      );
    });

    test('周六档：周六是起点，周五还在上一周', () {
      expect(
        WeekStart.startOf(DateTime(2026, 9, 26), firstDay: DateTime.saturday),
        DateTime(2026, 9, 26),
      );
      expect(
        WeekStart.startOf(DateTime(2026, 9, 25), firstDay: DateTime.saturday),
        DateTime(2026, 9, 19),
      );
      expect(
        WeekStart.startOf(DateTime(2026, 9, 27), firstDay: DateTime.saturday),
        DateTime(2026, 9, 26),
      );
    });

    test('startOf 把时分秒抹平（周界不能带当天时刻，否则时间线分桶会漏当天晚些时候的任务）', () {
      expect(
        WeekStart.startOf(DateTime(2026, 9, 25, 23, 59, 59)),
        DateTime(2026, 9, 21),
      );
    });
  });

  group('columnOrder', () {
    test('周一档就是 develop 现在的表头顺序 一…日', () {
      expect(WeekStart.columnOrder(), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('周日档把日挪到最前，其余相对顺序不变', () {
      expect(WeekStart.columnOrder(firstDay: DateTime.sunday), [
        7,
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('周六档把六日挪到最前', () {
      expect(WeekStart.columnOrder(firstDay: DateTime.saturday), [
        6,
        7,
        1,
        2,
        3,
        4,
        5,
      ]);
    });

    test('三档的排列都必须正好覆盖 1..7 一次（表头与网格错位是这里最容易漏的一半）', () {
      for (final firstDay in WeekStart.allowedFirstDays) {
        final order = WeekStart.columnOrder(firstDay: firstDay);
        expect(order.length, 7, reason: 'firstDay=$firstDay 的列数不是 7');
        expect(order.toSet(), {
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        }, reason: 'firstDay=$firstDay 的列里有重复或缺日');
        expect(order.first, firstDay, reason: 'firstDay=$firstDay 时第一列必须是它自己');
      }
    });
  });

  group('档位与文案', () {
    test('只有嘀嗒给的三档：周日 / 周一 / 周六', () {
      expect(WeekStart.allowedFirstDays, [
        DateTime.sunday,
        DateTime.monday,
        DateTime.saturday,
      ]);
    });

    test('labelOf 逐字用嘀嗒的档位名', () {
      expect(WeekStart.labelOf(DateTime.sunday), '周日');
      expect(WeekStart.labelOf(DateTime.monday), '周一');
      expect(WeekStart.labelOf(DateTime.saturday), '周六');
    });

    test('默认档必须是三档之一（否则首屏会拿到一个界面上选不回来的值）', () {
      expect(WeekStart.allowedFirstDays, contains(WeekStart.defaultFirstDay));
    });
  });

  group('offsetOf', () {
    test('给出某天距本周起点要回退的天数，且永不为负', () {
      for (final firstDay in WeekStart.allowedFirstDays) {
        for (var weekday = 1; weekday <= 7; weekday++) {
          final offset = WeekStart.offsetOf(weekday, firstDay: firstDay);
          expect(
            offset,
            inInclusiveRange(0, 6),
            reason: 'firstDay=$firstDay weekday=$weekday 的偏移越界',
          );
          // 往**回**退 offset 天后必须正好落在周首
          final landed = ((weekday - 1 - offset) % 7 + 7) % 7 + 1;
          expect(
            landed,
            firstDay,
            reason: 'firstDay=$firstDay weekday=$weekday 回退后不是周首',
          );
        }
      }
    });

    test('周一档下偏移就是 develop 原先的 weekday - 1', () {
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(WeekStart.offsetOf(weekday), weekday - 1);
      }
    });
  });
}
