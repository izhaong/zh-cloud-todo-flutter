import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';

void main() {
  test('pomodoro stats accept empty trends and null best hour', () {
    final stats = PomodoroStatsDto.fromJson({
      'totalSessions': 0,
      'totalMinutes': 0,
      'bestHour': null,
      'trend': [],
      'minutesTrend': [],
    });

    expect(stats.totalSessions, 0);
    expect(stats.totalMinutes, 0);
    expect(stats.bestHour, isNull);
    expect(stats.sessionTrend, isEmpty);
    expect(stats.minutesTrend, isEmpty);
    expect(stats.averageMinutesPerDay, 0);
  });

  test('最高等级成就进度保持为 100% 且不显示负数差额', () {
    const wall = AchievementWallDto(
      totalScore: 15000,
      level: 6,
      nextLevelName: '进阶',
      nextLevelRequired: 100,
      earnedBadges: [],
      lockedBadges: [],
    );

    expect(wall.isMaxLevel, isTrue);
    expect(wall.progress, 1);
  });

  test(
    'efficiency clients follow the service CommonResult contracts',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              final path = options.path;
              if (path.endsWith('/pomodoro/presets')) {
                return handler.resolve(
                  _response(options, [
                    {
                      'mode': 'MODE_25_5',
                      'focusMinutes': 25,
                      'breakMinutes': 5,
                      'label': '经典 25/5',
                    },
                    {
                      'mode': 'FREE',
                      'focusMinutes': null,
                      'breakMinutes': null,
                      'label': '正计时',
                    },
                  ]),
                );
              }
              if (path.endsWith('/pomodoro/start')) {
                return handler.resolve(_response(options, 41));
              }
              if (path.endsWith('/pomodoro/stats')) {
                return handler.resolve(
                  _response(options, {
                    'totalSessions': 3,
                    'totalMinutes': 75,
                    'bestHour': '09:00',
                    'trend': [
                      {'date': '2026-07-29', 'count': 1},
                      {'date': '2026-07-30', 'count': 2},
                    ],
                    'minutesTrend': [
                      {'date': '2026-07-29', 'count': 25},
                      {'date': '2026-07-30', 'count': 50},
                    ],
                  }),
                );
              }
              if (path.endsWith('/pomodoro/page')) {
                return handler.resolve(
                  _response(options, {
                    'list': [
                      {
                        'id': 42,
                        'mode': 'MODE_50_10',
                        'plannedMinutes': 50,
                        'status': 'PAUSED',
                        'startedAt': '2026-07-30T09:00:00',
                        'pausedAt': '2026-07-30T09:20:00',
                        'pausedSeconds': 60,
                      },
                    ],
                    'total': 1,
                  }),
                );
              }
              if (path.endsWith('/habit/page')) {
                return handler.resolve(
                  _response(options, {
                    'list': [
                      {
                        'id': 5,
                        'name': '阅读',
                        'period': 1,
                        'targetCount': 1,
                        'archived': false,
                      },
                    ],
                    'total': 1,
                  }),
                );
              }
              if (path.endsWith('/habit/create')) {
                return handler.resolve(_response(options, 6));
              }
              if (path.endsWith('/habit/check-in')) {
                return handler.resolve(_response(options, 9));
              }
              if (path.endsWith('/habit/stats')) {
                return handler.resolve(
                  _response(options, {
                    'totalCheckIns': 9,
                    'continuousDays': 3,
                    'longestContinuous': 4,
                    'completionRate': 0.75,
                    'dailyCounts': [
                      {'date': '2026-07-30', 'count': 1},
                    ],
                  }),
                );
              }
              if (path.endsWith('/countdown/list')) {
                return handler.resolve(
                  _response(options, [
                    {
                      'id': 7,
                      'name': '发布日',
                      'targetDate': '2026-08-10',
                      'daysRemaining': 11,
                      'style': 2,
                      'showAge': false,
                    },
                  ]),
                );
              }
              if (path.endsWith('/countdown/create')) {
                return handler.resolve(_response(options, 8));
              }
              if (path.endsWith('/achievement/wall')) {
                return handler.resolve(
                  _response(options, {
                    'totalScore': 250,
                    'level': 2,
                    'nextLevelName': 'Lv3',
                    'nextLevelRequired': 500,
                    'earnedBadges': [
                      {
                        'badgeType': 1,
                        'name': '新手',
                        'description': '完成首个任务',
                        'icon': 'starter',
                        'earned': true,
                      },
                    ],
                    'lockedBadges': [
                      {
                        'badgeType': 2,
                        'name': '连续打卡',
                        'description': '连续打卡 7 天',
                        'earned': false,
                      },
                    ],
                  }),
                );
              }
              return handler.resolve(_response(options, true));
            },
          ),
        );

      final pomodoro = PomodoroApi(dio);
      final started = await pomodoro.start(
        mode: 'MODE_25_5',
        plannedMinutes: 25,
      );
      final presets = await pomodoro.presets();
      final clientEndAt = DateTime(2026, 7, 30, 9, 25);
      await pomodoro.complete(41, remark: '  完成初稿  ', clientEndAt: clientEndAt);
      final pomodoroStats = await pomodoro.stats(period: 'week');
      final activePomodoro = await pomodoro.active();

      final habits = HabitRepository(dio);
      final habitList = await habits.listMine();
      final createdHabit = await habits.create(name: '跑步');
      final checkInCount = await habits.checkIn(
        5,
        date: DateTime(2026, 7, 30, 8),
      );
      final habitStats = await habits.stats(5);

      final countdowns = CountdownApi(dio);
      final countdownList = await countdowns.list();
      final createdCountdown = await countdowns.create(
        title: '下次发布',
        targetDate: DateTime(2026, 9, 1),
      );

      final achievement = await AchievementApi(dio).wall();

      expect(started.id, 41);
      expect(presets.first.mode, 'MODE_25_5');
      expect(presets.first.focusMinutes, 25);
      expect(presets.first.breakMinutes, 5);
      expect(presets.first.label, '经典 25/5');
      expect(presets.last.focusMinutes, isNull);
      expect(
        requests
            .firstWhere(
              (request) => request.path.endsWith('/pomodoro/41/complete'),
            )
            .data,
        {'remark': '完成初稿', 'clientEndAt': '2026-07-30T09:25:00.000'},
      );
      expect(pomodoroStats.totalSessions, 3);
      expect(pomodoroStats.totalMinutes, 75);
      expect(pomodoroStats.bestHour, '09:00');
      expect(pomodoroStats.sessionTrend.first.date, '2026-07-29');
      expect(pomodoroStats.sessionTrend.last.count, 2);
      expect(pomodoroStats.minutesTrend.last.count, 50);
      expect(pomodoroStats.averageMinutesPerDay, 37.5);
      expect(activePomodoro?.id, 42);
      expect(activePomodoro?.pausedSeconds, 60);
      expect(activePomodoro?.pausedAt, DateTime(2026, 7, 30, 9, 20));
      expect(
        requests
            .firstWhere((request) => request.path.endsWith('/pomodoro/stats'))
            .queryParameters,
        {'period': 'week'},
      );

      expect(habitList.single.targetCount, 1);
      expect(createdHabit, 6);
      expect(checkInCount, 9);
      expect(habitStats['continuousDays'], 3);
      expect(
        requests
            .firstWhere((request) => request.path.endsWith('/habit/create'))
            .data,
        {'name': '跑步', 'period': 1, 'targetCount': 1},
      );
      expect(
        requests
            .firstWhere((request) => request.path.endsWith('/habit/check-in'))
            .data,
        {'habitId': 5, 'checkedAt': '2026-07-30T08:00:00.000'},
      );
      expect(
        requests
            .firstWhere((request) => request.path.endsWith('/habit/stats'))
            .queryParameters,
        {'habitId': 5, 'period': 'WEEK'},
      );

      expect(countdownList.single.title, '发布日');
      expect(countdownList.single.daysRemaining, 11);
      expect(createdCountdown, 8);
      expect(
        requests
            .firstWhere((request) => request.path.endsWith('/countdown/create'))
            .data,
        {
          'name': '下次发布',
          'targetDate': '2026-09-01',
          'style': 1,
          'showAge': false,
        },
      );

      expect(achievement.totalScore, 250);
      expect(achievement.level, 2);
      expect(achievement.nextLevelName, 'Lv3');
      expect(achievement.nextLevelRequired, 500);
      expect(achievement.progress, 0.5);
      expect(achievement.isMaxLevel, isFalse);
      expect(achievement.earnedBadges.single.name, '新手');
      expect(achievement.earnedBadges.single.icon, 'starter');
      expect(achievement.lockedBadges.single.earned, isFalse);
      expect(
        requests
            .where((request) => request.path.endsWith('/achievement/wall'))
            .single
            .method,
        'GET',
      );
    },
  );

  test('pomodoro record management follows service contracts', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.path.endsWith('/pomodoro/41/adjust')) {
              return handler.resolve(_response(options, 30));
            }
            if (options.path.endsWith('/pomodoro/backfill')) {
              return handler.resolve(_response(options, 43));
            }
            if (options.path.endsWith('/pomodoro/page')) {
              return handler.resolve(
                _response(options, {
                  'list': [
                    {
                      'id': 43,
                      'taskId': 81,
                      'mode': 'CUSTOM',
                      'plannedMinutes': 40,
                      'actualMinutes': 40,
                      'status': 'COMPLETED',
                      'startedAt': '2026-08-02T09:00:00',
                      'endedAt': '2026-08-02T09:40:00',
                      'remark': '完成评审',
                    },
                  ],
                  'total': 1,
                }),
              );
            }
            return handler.resolve(_response(options, true));
          },
        ),
      );
    final api = PomodoroApi(dio);
    final startedAt = DateTime(2026, 8, 2, 9);
    final endedAt = DateTime(2026, 8, 2, 9, 40);

    final adjusted = await api.adjust(41, deltaMinutes: 5);
    final backfilled = await api.backfill(
      taskId: 81,
      mode: 'CUSTOM',
      actualMinutes: 40,
      startedAt: startedAt,
      endedAt: endedAt,
      remark: '  完成评审  ',
    );
    final records = await api.page(
      status: 'COMPLETED',
      pageNo: 1,
      pageSize: 20,
    );
    await api.updateDuration(43, actualMinutes: 45);
    await api.deleteRecord(43);

    expect(adjusted, 30);
    expect(backfilled, 43);
    expect(records.single.id, 43);
    expect(records.single.remark, '完成评审');
    expect(
      requests
          .singleWhere((request) => request.path.endsWith('/41/adjust'))
          .data,
      {'deltaMinutes': 5},
    );
    expect(
      requests
          .singleWhere((request) => request.path.endsWith('/backfill'))
          .data,
      {
        'taskId': 81,
        'mode': 'CUSTOM',
        'actualMinutes': 40,
        'startedAt': '2026-08-02T09:00:00.000',
        'endedAt': '2026-08-02T09:40:00.000',
        'remark': '完成评审',
      },
    );
    expect(
      requests
          .singleWhere((request) => request.path.endsWith('/pomodoro/page'))
          .queryParameters,
      {'status': 'COMPLETED', 'pageNo': 1, 'pageSize': 20},
    );
    final update = requests.singleWhere(
      (request) => request.path.endsWith('/43/duration'),
    );
    expect(update.method, 'PUT');
    expect(update.data, {'actualMinutes': 45});
    expect(
      requests
          .singleWhere((request) => request.path.endsWith('/pomodoro/43'))
          .method,
      'DELETE',
    );
  });
}

Response<Map<String, dynamic>> _response(RequestOptions options, Object? data) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    data: {'code': 0, 'data': data, 'msg': ''},
  );
}
