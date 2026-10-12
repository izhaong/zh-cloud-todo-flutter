import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';

/// specs/108 / FL #576：`GET /app-api/todo/pomodoro/stats` 新透出的两个键
/// （service PR !356 develop `a06f24635c1a`）——`hourlyTrend` 与 `dailyMinutesTrend`。
///
/// 解析层的口径：**缺键一律回空列表**，不猜默认值。老服务端还没有这两个键时，
/// 消费侧要能靠"空"退回今天的样子，而不是画一张只有半截的图。
void main() {
  test('两个新键都缺席时解析成空列表（老服务端兼容）', () {
    final dto = PomodoroStatsDto.fromJson(const {
      'totalSessions': 2,
      'totalMinutes': 50,
      'bestHour': '09:00',
      'trend': [
        {'date': '2026-08-02', 'count': 2},
      ],
      'minutesTrend': [
        {'date': '2026-08-02', 'count': 50},
      ],
    });

    expect(dto.hourlyTrend, isEmpty);
    expect(dto.yearlyDailyMinutes, isEmpty);
  });

  test('带键时按服务端形状解析：小时 + 分钟、按天 date + count', () {
    final dto = PomodoroStatsDto.fromJson(const {
      'totalSessions': 2,
      'totalMinutes': 50,
      'trend': [],
      'minutesTrend': [],
      'hourlyTrend': [
        {'hour': 8, 'minutes': 0},
        {'hour': 9, 'minutes': 50},
      ],
      'dailyMinutesTrend': [
        {'date': '2026-07-01', 'count': 20},
        {'date': '2026-07-02', 'count': 30},
      ],
    });

    expect(dto.hourlyTrend, hasLength(2));
    expect(dto.hourlyTrend.first.hour, 8);
    expect(dto.hourlyTrend.first.minutes, 0);
    expect(dto.hourlyTrend.last.hour, 9);
    expect(dto.hourlyTrend.last.minutes, 50);
    expect(dto.yearlyDailyMinutes, hasLength(2));
    expect(dto.yearlyDailyMinutes.first.date, '2026-07-01');
    expect(dto.yearlyDailyMinutes.last.count, 30);
  });

  test('键存在但形状不对（不是数组）也只当没有，不抛', () {
    final dto = PomodoroStatsDto.fromJson(const {
      'totalSessions': 0,
      'totalMinutes': 0,
      'trend': [],
      'minutesTrend': [],
      'hourlyTrend': {'hour': 9},
      'dailyMinutesTrend': 'oops',
    });

    expect(dto.hourlyTrend, isEmpty);
    expect(dto.yearlyDailyMinutes, isEmpty);
  });
}
