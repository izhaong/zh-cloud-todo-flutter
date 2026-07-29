import 'package:dio/dio.dart';

import '../../core/api/api_config.dart';

/// 习惯数据访问 — M11-B4：纯后端驱动，不依赖本地 Drift 表
/// （schema 暂未包含 habits/habit_logs，列表与打卡均走 `/app-api/todo/habit/**`）。
class HabitDto {
  final int id;
  final String name;
  final String? color;
  final int period;
  final int targetCount;
  final bool archived;

  HabitDto({
    required this.id,
    required this.name,
    this.color,
    this.period = 1,
    this.targetCount = 1,
    this.archived = false,
  });

  factory HabitDto.fromJson(Map<String, dynamic> j) {
    return HabitDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      color: j['color']?.toString(),
      period: (j['period'] as num?)?.toInt() ?? 1,
      targetCount:
          (j['targetCount'] as num?)?.toInt() ??
          (j['targetPerWeek'] as num?)?.toInt() ??
          1,
      archived: j['archived'] == true,
    );
  }
}

class HabitRepository {
  HabitRepository(this._dio);
  final Dio _dio;

  /// 列出我的习惯。
  Future<List<HabitDto>> listMine({int pageNo = 1, int pageSize = 50}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/page',
      queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
    );
    final data = _unwrapHabitData(r.data);
    final raw =
        (data is Map ? data['list'] as List? : null) ??
        (r.data?['list'] as List?) ??
        [];
    return raw
        .map((e) => HabitDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> create({
    required String name,
    int period = 1,
    int targetCount = 1,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/create',
      data: {'name': name, 'period': period, 'targetCount': targetCount},
    );
    return _unwrapInt(response.data);
  }

  /// 打卡：返回当日累计打卡次数（后端计算）。
  Future<int> checkIn(int habitId, {DateTime? date}) async {
    final d = date ?? DateTime.now();
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/check-in',
      data: {'habitId': habitId, 'checkedAt': '${key}T${_timeOnly(d)}'},
    );
    return _unwrapInt(r.data);
  }

  /// 统计：连续打卡天数 / 本周完成。
  Future<Map<String, dynamic>> stats(
    int habitId, {
    String period = 'WEEK',
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/stats',
      queryParameters: {'habitId': habitId, 'period': period},
    );
    return Map<String, dynamic>.from(_unwrapHabitData(r.data) as Map? ?? {});
  }

  Future<Map<String, dynamic>> overviewStats() async {
    final habits = await listMine();
    if (habits.isEmpty) {
      return const {'currentStreak': 0, 'weeklyDone': 0, 'totalCheckIns': 0};
    }
    var bestStreak = 0;
    var weeklyDone = 0;
    var totalCheckIns = 0;
    for (final habit in habits) {
      final value = await stats(habit.id);
      final streak = (value['continuousDays'] as num?)?.toInt() ?? 0;
      if (streak > bestStreak) bestStreak = streak;
      totalCheckIns += (value['totalCheckIns'] as num?)?.toInt() ?? 0;
      final dailyCounts = value['dailyCounts'];
      if (dailyCounts is List) {
        for (final entry in dailyCounts) {
          if (entry is Map) {
            weeklyDone += (entry['count'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }
    return {
      'currentStreak': bestStreak,
      'weeklyDone': weeklyDone,
      'totalCheckIns': totalCheckIns,
    };
  }
}

int _unwrapInt(Map<String, dynamic>? body) {
  if (body == null) return 0;
  if (body.containsKey('code') && body['code'] != 0) {
    throw DioException(
      requestOptions: RequestOptions(path: ApiConfig.todoPrefix),
      error: body['msg'] ?? '请求失败',
    );
  }
  final data = body.containsKey('code') ? body['data'] : body;
  if (data is num) return data.toInt();
  if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
  return int.tryParse('$data') ?? 0;
}

dynamic _unwrapHabitData(Map<String, dynamic>? body) {
  if (body == null) return null;
  if (body.containsKey('code') && body['code'] != 0) {
    throw DioException(
      requestOptions: RequestOptions(path: ApiConfig.todoPrefix),
      error: body['msg'] ?? '请求失败',
    );
  }
  return body.containsKey('code') ? body['data'] : body;
}

String _timeOnly(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  String three(int number) => number.toString().padLeft(3, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.'
      '${three(value.millisecond)}';
}
