// M11-B4 效率域 API client（番茄专注 / 习惯 / 倒数日）
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_config.dart';

dynamic _unwrapData(Map<String, dynamic>? body) {
  if (body == null) return null;
  if (!body.containsKey('code')) return body;
  if (body['code'] != 0) {
    throw DioException(
      requestOptions: RequestOptions(path: ApiConfig.todoPrefix),
      error: body['msg'] ?? '请求失败',
    );
  }
  return body['data'];
}

class PomodoroSessionDto {
  final int id;
  final int? taskId;
  final String mode;
  final int? plannedMinutes;
  final int? actualMinutes;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int pausedSeconds;

  PomodoroSessionDto({
    required this.id,
    this.taskId,
    required this.mode,
    this.plannedMinutes,
    this.actualMinutes,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.pausedSeconds = 0,
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
      pausedSeconds: (j['pausedSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class CountdownDto {
  final int id;
  final String title;
  final DateTime targetDate;
  final int daysRemaining;
  final int style;
  final bool showAge;
  final String? backgroundImage;

  CountdownDto({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.daysRemaining,
    this.style = 1,
    this.showAge = false,
    this.backgroundImage,
  });

  factory CountdownDto.fromJson(Map<String, dynamic> j) {
    final targetDate = _parseDate(j['targetDate']) ?? DateTime.now();
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    return CountdownDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: j['name']?.toString() ?? j['title']?.toString() ?? '',
      targetDate: targetDate,
      daysRemaining:
          (j['daysRemaining'] as num?)?.toInt() ??
          DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
          ).difference(localToday).inDays,
      style: (j['style'] as num?)?.toInt() ?? 1,
      showAge: j['showAge'] == true,
      backgroundImage: j['backgroundImage']?.toString(),
    );
  }

  bool get isCountUp => daysRemaining < 0;
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
  return null;
}

enum QuadrantRuleType { priorityTime, priorityOnly, custom }

extension QuadrantRuleTypeX on QuadrantRuleType {
  String get wireName => switch (this) {
    QuadrantRuleType.priorityTime => 'PRIORITY_TIME',
    QuadrantRuleType.priorityOnly => 'PRIORITY_ONLY',
    QuadrantRuleType.custom => 'CUSTOM',
  };

  String get label => switch (this) {
    QuadrantRuleType.priorityTime => '优先级 + 截止时间',
    QuadrantRuleType.priorityOnly => '仅按优先级',
    QuadrantRuleType.custom => '自定义条件',
  };

  static QuadrantRuleType parse(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'PRIORITY_ONLY' => QuadrantRuleType.priorityOnly,
      'CUSTOM' => QuadrantRuleType.custom,
      _ => QuadrantRuleType.priorityTime,
    };
  }
}

class QuadrantDefinitionDto {
  const QuadrantDefinitionDto({required this.key, required this.condition});

  final String key;
  final String condition;

  factory QuadrantDefinitionDto.fromJson(Map<String, dynamic> json) {
    return QuadrantDefinitionDto(
      key: json['key']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
    );
  }
}

class QuadrantRuleDto {
  const QuadrantRuleDto({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    this.quadrantsJson,
  });

  final int id;
  final String name;
  final QuadrantRuleType type;
  final bool isDefault;
  final String? quadrantsJson;

  factory QuadrantRuleDto.fromJson(Map<String, dynamic> json) {
    return QuadrantRuleDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      type: QuadrantRuleTypeX.parse(json['ruleType']),
      isDefault: json['isDefault'] == true,
      quadrantsJson: json['quadrantsJson']?.toString(),
    );
  }

  List<QuadrantDefinitionDto> get definitions {
    final source = quadrantsJson;
    if (source == null || source.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                QuadrantDefinitionDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (definition) =>
                definition.key.isNotEmpty && definition.condition.isNotEmpty,
          )
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}

/// 四象限规则与服务端分组。
class QuadrantApi {
  QuadrantApi(this._dio);

  final Dio _dio;

  Future<List<QuadrantRuleDto>> listRules() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/quadrant/list',
    );
    final data = _unwrapData(response.data);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => QuadrantRuleDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<int> createRule({
    required String name,
    required QuadrantRuleType ruleType,
    String? quadrantsJson,
    required bool isDefault,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/quadrant/create',
      data: _rulePayload(
        name: name,
        ruleType: ruleType,
        quadrantsJson: quadrantsJson,
        isDefault: isDefault,
      ),
    );
    final data = _unwrapData(response.data);
    return data is num ? data.toInt() : int.parse(data.toString());
  }

  Future<void> updateRule({
    required int id,
    required String name,
    required QuadrantRuleType ruleType,
    String? quadrantsJson,
    required bool isDefault,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/quadrant/update',
      data: {
        'id': id,
        ..._rulePayload(
          name: name,
          ruleType: ruleType,
          quadrantsJson: quadrantsJson,
          isDefault: isDefault,
        ),
      },
    );
    _unwrapData(response.data);
  }

  Future<void> deleteRule(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/quadrant/delete',
      queryParameters: {'id': id},
    );
    _unwrapData(response.data);
  }

  Future<Map<String, Set<int>>> board({
    required int ruleId,
    int? listId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/quadrant/board',
      data: {'ruleId': ruleId, 'listId': listId, 'pageNo': 1, 'pageSize': 200},
    );
    final data = _unwrapData(response.data);
    if (data is! Map) return const {};
    return {
      for (final entry in data.entries)
        entry.key.toString(): {
          for (final item
              in entry.value is List ? entry.value as List : const <dynamic>[])
            if (item is Map && item['id'] is num) (item['id'] as num).toInt(),
        },
    };
  }

  static Map<String, dynamic> _rulePayload({
    required String name,
    required QuadrantRuleType ruleType,
    required String? quadrantsJson,
    required bool isDefault,
  }) {
    return {
      'name': name,
      'ruleType': ruleType.wireName,
      'quadrantsJson': ruleType == QuadrantRuleType.custom
          ? quadrantsJson
          : null,
      'isDefault': isDefault,
    };
  }
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
      data: {'taskId': taskId, 'mode': mode, 'plannedMinutes': ?plannedMinutes},
    );
    final data = _unwrapData(r.data);
    if (data is Map) {
      return PomodoroSessionDto.fromJson(Map<String, dynamic>.from(data));
    }
    final id = data is num ? data.toInt() : int.tryParse('$data') ?? 0;
    return PomodoroSessionDto(
      id: id,
      taskId: taskId,
      mode: mode,
      plannedMinutes: plannedMinutes,
      status: 'RUNNING',
      startedAt: DateTime.now(),
    );
  }

  Future<void> pause(int id) => _action('/pomodoro/$id/pause');
  Future<void> resume(int id) => _action('/pomodoro/$id/resume');
  Future<void> complete(int id, {String? remark}) =>
      _action('/pomodoro/$id/complete', data: {'remark': remark});
  Future<void> cancel(int id) => _action('/pomodoro/$id/cancel');

  Future<void> _action(String path, {Object? data}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}$path',
      data: data,
    );
    _unwrapData(response.data);
  }

  Future<PomodoroSessionDto?> active() async {
    for (final status in const ['RUNNING', 'PAUSED']) {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiConfig.todoPrefix}/pomodoro/page',
        queryParameters: {'status': status, 'pageNo': 1, 'pageSize': 1},
      );
      final data = _unwrapData(response.data);
      final list = data is Map ? data['list'] : null;
      if (list is List && list.isNotEmpty) {
        return PomodoroSessionDto.fromJson(
          Map<String, dynamic>.from(list.first as Map),
        );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> stats({String period = 'week'}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/stats',
      queryParameters: {'period': period},
    );
    return Map<String, dynamic>.from(_unwrapData(r.data) as Map? ?? {});
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
    final data = _unwrapData(r.data);
    final raw = data is List
        ? data
        : (data is Map ? (data['list'] as List? ?? const []) : const []);
    return raw
        .map((e) => CountdownDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> create({
    required String title,
    required DateTime targetDate,
    bool isCountUp = false,
    int style = 1,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/create',
      data: {
        'name': title,
        'targetDate': _dateOnly(targetDate),
        'style': style,
        'showAge': isCountUp,
      },
    );
    final data = _unwrapData(r.data);
    if (data is num) return data.toInt();
    if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
    return int.tryParse('$data') ?? 0;
  }
}

String _dateOnly(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
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
