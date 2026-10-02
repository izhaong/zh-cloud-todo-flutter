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
  final int? timerId;
  final int? taskId;
  final int? habitId;
  final String mode;
  final int? plannedMinutes;
  final int? actualMinutes;
  final String status;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int pausedSeconds;
  final String? remark;

  PomodoroSessionDto({
    required this.id,
    this.timerId,
    this.taskId,
    this.habitId,
    required this.mode,
    this.plannedMinutes,
    this.actualMinutes,
    required this.status,
    this.startedAt,
    this.pausedAt,
    this.endedAt,
    this.pausedSeconds = 0,
    this.remark,
  });

  factory PomodoroSessionDto.fromJson(Map<String, dynamic> j) {
    return PomodoroSessionDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      timerId: (j['timerId'] as num?)?.toInt(),
      taskId: (j['taskId'] as num?)?.toInt(),
      habitId: (j['habitId'] as num?)?.toInt(),
      mode: j['mode']?.toString() ?? 'MODE_25_5',
      plannedMinutes: (j['plannedMinutes'] as num?)?.toInt(),
      actualMinutes: (j['actualMinutes'] as num?)?.toInt(),
      status: j['status']?.toString() ?? 'RUNNING',
      startedAt: _parseDate(j['startedAt']),
      pausedAt: _parseDate(j['pausedAt']),
      endedAt: _parseDate(j['endedAt']),
      pausedSeconds: (j['pausedSeconds'] as num?)?.toInt() ?? 0,
      remark: j['remark']?.toString(),
    );
  }

  PomodoroSessionDto copyWith({int? plannedMinutes, int? actualMinutes}) {
    return PomodoroSessionDto(
      id: id,
      timerId: timerId,
      taskId: taskId,
      habitId: habitId,
      mode: mode,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      status: status,
      startedAt: startedAt,
      pausedAt: pausedAt,
      endedAt: endedAt,
      pausedSeconds: pausedSeconds,
      remark: remark,
    );
  }
}

class PomodoroTimerDto {
  const PomodoroTimerDto({
    required this.id,
    required this.name,
    required this.mode,
    this.focusMinutes,
    this.taskId,
    this.habitId,
    this.sortOrder = 0,
    this.archived = false,
  });

  final int id;
  final String name;
  final String mode;
  final int? focusMinutes;
  final int? taskId;
  final int? habitId;
  final int sortOrder;
  final bool archived;

  factory PomodoroTimerDto.fromJson(Map<String, dynamic> json) {
    return PomodoroTimerDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      focusMinutes: (json['focusMinutes'] as num?)?.toInt(),
      taskId: (json['taskId'] as num?)?.toInt(),
      habitId: (json['habitId'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      archived: json['archived'] == true,
    );
  }
}

class PomodoroPresetDto {
  const PomodoroPresetDto({
    required this.mode,
    required this.label,
    this.focusMinutes,
    this.breakMinutes,
  });

  final String mode;
  final String label;
  final int? focusMinutes;
  final int? breakMinutes;

  factory PomodoroPresetDto.fromJson(Map<String, dynamic> json) {
    return PomodoroPresetDto(
      mode: json['mode']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      focusMinutes: (json['focusMinutes'] as num?)?.toInt(),
      breakMinutes: (json['breakMinutes'] as num?)?.toInt(),
    );
  }
}

class PomodoroDailyStatsDto {
  const PomodoroDailyStatsDto({required this.date, required this.count});

  final String date;
  final int count;

  factory PomodoroDailyStatsDto.fromJson(Map<String, dynamic> json) {
    return PomodoroDailyStatsDto(
      date: json['date']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PomodoroTaskDistributionDto {
  const PomodoroTaskDistributionDto({
    this.taskId,
    required this.taskTitle,
    required this.minutes,
    required this.sessions,
  });

  final int? taskId;
  final String taskTitle;
  final int minutes;
  final int sessions;

  factory PomodoroTaskDistributionDto.fromJson(Map<String, dynamic> json) {
    final minutes = (json['minutes'] as num?)?.toInt() ?? 0;
    final sessions = (json['sessions'] as num?)?.toInt() ?? 0;
    return PomodoroTaskDistributionDto(
      taskId: (json['taskId'] as num?)?.toInt(),
      taskTitle: json['taskTitle']?.toString() ?? '未分类',
      minutes: minutes < 0 ? 0 : minutes,
      sessions: sessions < 0 ? 0 : sessions,
    );
  }
}

class PomodoroTimelineDto {
  const PomodoroTimelineDto({
    required this.id,
    this.taskId,
    required this.taskTitle,
    required this.mode,
    this.startedAt,
    this.endedAt,
    required this.actualMinutes,
    this.remark,
  });

  final int id;
  final int? taskId;
  final String taskTitle;
  final String mode;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int actualMinutes;
  final String? remark;

  factory PomodoroTimelineDto.fromJson(Map<String, dynamic> json) {
    final actualMinutes = (json['actualMinutes'] as num?)?.toInt() ?? 0;
    return PomodoroTimelineDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      taskId: (json['taskId'] as num?)?.toInt(),
      taskTitle: json['taskTitle']?.toString() ?? '未分类',
      mode: json['mode']?.toString() ?? '',
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
      actualMinutes: actualMinutes < 0 ? 0 : actualMinutes,
      remark: json['remark']?.toString(),
    );
  }
}

class PomodoroStatsDto {
  const PomodoroStatsDto({
    required this.totalSessions,
    required this.totalMinutes,
    required this.sessionTrend,
    required this.minutesTrend,
    this.bestHour,
    this.taskDistribution = const [],
  });

  const PomodoroStatsDto.empty()
    : totalSessions = 0,
      totalMinutes = 0,
      bestHour = null,
      sessionTrend = const [],
      minutesTrend = const [],
      taskDistribution = const [];

  final int totalSessions;
  final int totalMinutes;
  final String? bestHour;
  final List<PomodoroDailyStatsDto> sessionTrend;
  final List<PomodoroDailyStatsDto> minutesTrend;
  final List<PomodoroTaskDistributionDto> taskDistribution;

  double get averageMinutesPerDay =>
      minutesTrend.isEmpty ? 0 : totalMinutes / minutesTrend.length;

  factory PomodoroStatsDto.fromJson(Map<String, dynamic> json) {
    List<PomodoroDailyStatsDto> parseTrend(Object? value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) =>
                PomodoroDailyStatsDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    List<PomodoroTaskDistributionDto> parseDistribution(Object? value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => PomodoroTaskDistributionDto.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    return PomodoroStatsDto(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      bestHour: json['bestHour']?.toString(),
      sessionTrend: parseTrend(json['trend']),
      minutesTrend: parseTrend(json['minutesTrend']),
      taskDistribution: parseDistribution(json['taskDistribution']),
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

class AchievementBadgeDto {
  const AchievementBadgeDto({
    required this.badgeType,
    required this.name,
    required this.description,
    required this.earned,
    this.icon,
  });

  final int badgeType;
  final String name;
  final String description;
  final String? icon;
  final bool earned;

  factory AchievementBadgeDto.fromJson(Map<String, dynamic> json) {
    return AchievementBadgeDto(
      badgeType: (json['badgeType'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString(),
      earned: json['earned'] == true,
    );
  }
}

class AchievementWallDto {
  const AchievementWallDto({
    required this.totalScore,
    required this.level,
    required this.nextLevelName,
    required this.nextLevelRequired,
    required this.earnedBadges,
    required this.lockedBadges,
  });

  final int totalScore;
  final int level;
  final String nextLevelName;
  final int nextLevelRequired;
  final List<AchievementBadgeDto> earnedBadges;
  final List<AchievementBadgeDto> lockedBadges;

  bool get isMaxLevel =>
      nextLevelRequired <= 0 || totalScore >= nextLevelRequired;

  double get progress {
    if (isMaxLevel) return 1;
    return (totalScore / nextLevelRequired).clamp(0, 1).toDouble();
  }

  factory AchievementWallDto.fromJson(Map<String, dynamic> json) {
    List<AchievementBadgeDto> badges(Object? value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) =>
                AchievementBadgeDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    return AchievementWallDto(
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      nextLevelName: json['nextLevelName']?.toString() ?? '',
      nextLevelRequired: (json['nextLevelRequired'] as num?)?.toInt() ?? 0,
      earnedBadges: badges(json['earnedBadges']),
      lockedBadges: badges(json['lockedBadges']),
    );
  }
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

  Future<List<PomodoroTimerDto>> timers({bool archived = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers',
      queryParameters: {'archived': archived},
    );
    final data = _unwrapData(response.data);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => PomodoroTimerDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<int> createTimer({
    required String name,
    required String mode,
    int? focusMinutes,
    int? taskId,
    int? habitId,
    int sortOrder = 0,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers',
      data: _timerPayload(
        name: name,
        mode: mode,
        focusMinutes: focusMinutes,
        taskId: taskId,
        habitId: habitId,
        sortOrder: sortOrder,
      ),
    );
    final data = _unwrapData(response.data);
    return data is num ? data.toInt() : int.parse('$data');
  }

  Future<void> updateTimer(
    int id, {
    required String name,
    required String mode,
    int? focusMinutes,
    int? taskId,
    int? habitId,
    int sortOrder = 0,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers/$id',
      data: _timerPayload(
        name: name,
        mode: mode,
        focusMinutes: focusMinutes,
        taskId: taskId,
        habitId: habitId,
        sortOrder: sortOrder,
      ),
    );
    _unwrapData(response.data);
  }

  Future<void> setTimerArchived(int id, bool archived) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers/$id/archived',
      queryParameters: {'value': archived},
    );
    _unwrapData(response.data);
  }

  Future<void> deleteTimer(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers/$id',
    );
    _unwrapData(response.data);
  }

  Future<PomodoroSessionDto> startTimer(int id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timers/$id/start',
    );
    final data = _unwrapData(response.data);
    if (data is! Map) {
      throw StateError('Timer 启动响应缺少完整会话');
    }
    final json = Map<String, dynamic>.from(data);
    if (json['id'] is! num ||
        (json['id'] as num).toInt() <= 0 ||
        json['mode'] is! String ||
        (json['mode'] as String).isEmpty ||
        json['status'] is! String ||
        (json['status'] as String).isEmpty ||
        _parseDate(json['startedAt']) == null) {
      throw StateError('Timer 启动响应缺少完整会话');
    }
    return PomodoroSessionDto.fromJson(json);
  }

  static Map<String, dynamic> _timerPayload({
    required String name,
    required String mode,
    required int? focusMinutes,
    required int? taskId,
    required int? habitId,
    required int sortOrder,
  }) {
    return <String, dynamic>{
      'name': name,
      'mode': mode,
      'focusMinutes': ?focusMinutes,
      'taskId': ?taskId,
      'habitId': ?habitId,
      'sortOrder': sortOrder,
    };
  }

  Future<void> pause(int id) => _action('/pomodoro/$id/pause');
  Future<void> resume(int id) => _action('/pomodoro/$id/resume');
  Future<void> complete(int id, {String? remark, DateTime? clientEndAt}) {
    final normalizedRemark = remark?.trim();
    return _action(
      '/pomodoro/$id/complete',
      data: <String, dynamic>{
        if (normalizedRemark != null && normalizedRemark.isNotEmpty)
          'remark': normalizedRemark,
        if (clientEndAt != null) 'clientEndAt': clientEndAt.toIso8601String(),
      },
    );
  }

  Future<void> cancel(int id) => _action('/pomodoro/$id/cancel');

  Future<int> adjust(int id, {required int deltaMinutes}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/$id/adjust',
      data: {'deltaMinutes': deltaMinutes},
    );
    final data = _unwrapData(response.data);
    return data is num ? data.toInt() : int.parse('$data');
  }

  Future<int> backfill({
    int? taskId,
    required String mode,
    required int actualMinutes,
    required DateTime startedAt,
    required DateTime endedAt,
    String? remark,
  }) async {
    final normalizedRemark = remark?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/backfill',
      data: <String, dynamic>{
        'taskId': ?taskId,
        'mode': mode,
        'actualMinutes': actualMinutes,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        if (normalizedRemark != null && normalizedRemark.isNotEmpty)
          'remark': normalizedRemark,
      },
    );
    final data = _unwrapData(response.data);
    return data is num ? data.toInt() : int.parse('$data');
  }

  Future<List<PomodoroSessionDto>> page({
    String? status,
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/page',
      queryParameters: <String, dynamic>{
        'status': ?status,
        'pageNo': pageNo,
        'pageSize': pageSize,
      },
    );
    final data = _unwrapData(response.data);
    final raw = data is Map ? data['list'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              PomodoroSessionDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> updateDuration(int id, {required int actualMinutes}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/$id/duration',
      data: {'actualMinutes': actualMinutes},
    );
    _unwrapData(response.data);
  }

  Future<void> deleteRecord(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/$id',
    );
    _unwrapData(response.data);
  }

  Future<List<PomodoroPresetDto>> presets() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/presets',
    );
    final data = _unwrapData(response.data);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => PomodoroPresetDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

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

  Future<PomodoroStatsDto> stats({String period = 'week'}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/stats',
      queryParameters: {'period': period},
    );
    final data = _unwrapData(r.data);
    if (data is! Map) return const PomodoroStatsDto.empty();
    return PomodoroStatsDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<PomodoroTimelineDto>> timeline({required DateTime date}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/pomodoro/timeline',
      queryParameters: {'date': _dateOnly(date)},
    );
    final data = _unwrapData(response.data);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) =>
              PomodoroTimelineDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}

/// 倒数日：list / create / update / delete
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
    bool showAge = false,
    int style = 1,
    String? backgroundImage,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/create',
      data: {
        'name': title,
        'targetDate': _dateOnly(targetDate),
        'style': style,
        'showAge': showAge,
        'backgroundImage': ?backgroundImage,
      },
    );
    final data = _unwrapData(r.data);
    if (data is num) return data.toInt();
    if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
    return int.tryParse('$data') ?? 0;
  }

  Future<void> update({
    required int id,
    required String title,
    required DateTime targetDate,
    required int style,
    required bool showAge,
    String? backgroundImage,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/update',
      data: {
        'id': id,
        'name': title,
        'targetDate': _dateOnly(targetDate),
        'style': style,
        'showAge': showAge,
        'backgroundImage': ?backgroundImage,
      },
    );
    _unwrapData(response.data);
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/countdown/delete',
      queryParameters: {'id': id},
    );
    _unwrapData(response.data);
  }
}

/// 会员自己的成就值、等级进度与勋章墙。
class AchievementApi {
  AchievementApi(this._dio);

  final Dio _dio;

  Future<AchievementWallDto> wall() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/achievement/wall',
    );
    final data = _unwrapData(response.data);
    if (data is! Map) {
      throw StateError('成就墙响应无效');
    }
    return AchievementWallDto.fromJson(Map<String, dynamic>.from(data));
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

  Future<void> dismiss(int reminderDispatchId) => _dio.post(
    '${ApiConfig.todoPrefix}/reminder-action/dismiss',
    data: {'reminderDispatchId': reminderDispatchId},
  );

  Future<void> snooze(int reminderDispatchId, {int minutes = 10}) => _dio.post(
    '${ApiConfig.todoPrefix}/reminder-action/snooze',
    data: {'reminderDispatchId': reminderDispatchId, 'minutes': minutes},
  );
}
