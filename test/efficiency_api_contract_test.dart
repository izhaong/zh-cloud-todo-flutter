import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';

void main() {
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
              if (path.endsWith('/pomodoro/start')) {
                return handler.resolve(_response(options, 41));
              }
              if (path.endsWith('/pomodoro/stats')) {
                return handler.resolve(
                  _response(options, {
                    'totalSessions': 3,
                    'totalMinutes': 75,
                    'bestHour': '09:00',
                    'trend': [],
                    'minutesTrend': [],
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
                        'status': 'RUNNING',
                        'startedAt': '2026-07-30T09:00:00',
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
              return handler.resolve(_response(options, true));
            },
          ),
        );

      final pomodoro = PomodoroApi(dio);
      final started = await pomodoro.start(
        mode: 'MODE_25_5',
        plannedMinutes: 25,
      );
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

      expect(started.id, 41);
      expect(pomodoroStats['totalMinutes'], 75);
      expect(activePomodoro?.id, 42);
      expect(activePomodoro?.pausedSeconds, 60);
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
    },
  );
}

Response<Map<String, dynamic>> _response(RequestOptions options, Object? data) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    data: {'code': 0, 'data': data, 'msg': ''},
  );
}
