/// M11-B4 效率域 API client（番茄专注 / 习惯 / 倒数日）
import 'package:dio/dio.dart';

import 'api_config.dart';

class PomodoroSessionDto {
  final int id;
  final int? taskId;
  final String mode;
  final int? plannedMinutes;
  final int? actualMinutes;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  PomodoroSessionDto({
    required this.id,
    this.taskId,
    required this.mode,
    this.plannedMinutes,
    this.actualMinutes,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  factory PomodoroSessionDto.fromJson(Map<String, dynamic> j) {
    return PomodoroSessionDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      taskId: (j['taskId'] as num?)?.toInt(),
      mode: j['mode']?.toString() ?? 'MODE_25_5',
      plannedMinutes: (j['plannedMinutes'] as num?)?.toInt(),
      actualMinutes: (j['actualMinutes'] as num?)?.toInt(),
      status: j['status']?.toString() ?? 'RUNNING',
      startedAt: _parseDate(j['startedAt']),
      endedAt: _parseDate(j['endedAt']),
    );
  }
}

class CountdownDto {
  final int id;
  final String title;
  final DateTime targetDate;
  final bool isCountUp;
  final String? color;

  CountdownDto({
    required this.id,
    required this.title,
    required this.targetDate,
    this.isCountUp = false,
    this.color,
  });

  factory CountdownDto.fromJson(Map<String, dynamic> j) {
    return CountdownDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: j['title']?.toString() ?? '',
      targetDate:
          _parseDate(j['targetDate']) ?? DateTime.now(),
      isCountUp: j['isCountUp'] == true,
      color: j['color']?.toString(),
    );
  }
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
  return null;
}

/// 番茄专注：start / pause / resume / complete / cancel / backfill / page / stats
class PomodoroApi {
  PomodoroApi(this._dio);
  final Dio _dio;

  Future<PomodoroSessionDto> start({
    int? taskId,
    String mode = 'MODE_25_5',
    int? plannedMinutes,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/start',
      data: {
        'taskId': taskId,
        'mode': mode,
        if (plannedMinutes != null) 'plannedMinutes': plannedMinutes,
      },
    );
    return PomodoroSessionDto.fromJson(r.data ?? {});
  }

  Future<void> pause(int id) =>
      _dio.post('${ApiConfig.todoPrefix}/pomodoro/$id/pause');
  Future<void> resume(int id) =>
      _dio.post('${ApiConfig.todoPrefix}/pomodoro/$id/resume');
  Future<void> complete(int id, {String? remark}) =>
      _dio.post('${ApiConfig.todoPrefix}/pomodoro/$id/complete',
          data: {'remark': remark});
  Future<void> cancel(int id) =>
      _dio.post('${ApiConfig.todoPrefix}/pomodoro/$id/cancel');

  Future<Map<String, dynamic>> stats({int days = 7}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/stats',
      queryParameters: {'days': days},
    );
    return r.data ?? {};
  }
}

/// 倒数日：list / get / create
class CountdownApi {
  CountdownApi(this._dio);
  final Dio _dio;

  Future<List<CountdownDto>> list() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/list',
    );
    final raw = (r.data?['data'] as List?) ?? (r.data?['list'] as List?) ?? [];
    return raw
        .map((e) => CountdownDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> create({
    required String title,
    required DateTime targetDate,
    bool isCountUp = false,
    String? color,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/create',
      data: {
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'isCountUp': isCountUp,
        if (color != null) 'color': color,
      },
    );
    return (r.data?['data']?['id'] as num?)?.toInt() ?? 0;
  }
}

/// 提醒动作：dismiss / snooze
class ReminderActionApi {
  ReminderActionApi(this._dio);
  final Dio _dio;

  Future<void> dismiss(int reminderId) => _dio.post(
        '${ApiConfig.todoPrefix}/reminder-action/dismiss',
        data: {'reminderId': reminderId},
      );

  Future<void> snooze(int reminderId, {int minutes = 10}) => _dio.post(
        '${ApiConfig.todoPrefix}/reminder-action/snooze',
        data: {'reminderId': reminderId, 'minutes': minutes},
      );
}