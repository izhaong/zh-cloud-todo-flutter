import 'package:dio/dio.dart';

import '../../core/api/api_config.dart';
import '../../core/api/envelope.dart';

/// 习惯数据访问 — M11-B4：纯后端驱动，不依赖本地 Drift 表
/// （schema 暂未包含 habits/habit_logs，列表与打卡均走 `/app-api/todo/habit/**`）。
class HabitDto {
  final int id;
  final String name;
  final String? icon;
  final String? color;
  final int period;
  final int targetCount;
  final DateTime? reminderAt;
  final int sortOrder;
  final bool archived;

  /// 打卡方式：1-自动记录、2-手动记录、3-完成全部（service !347 契约，嘀嗒
  /// 《02-更好地完成习惯.md》打卡方式三档；存量/缺省按自动记录）。
  final int recordType;

  /// 习惯级「打卡日志」开关（specs/132，矩阵 #45 面 ④ 收尾；嘀嗒
  /// 《02-更好地完成习惯.md》:60-:62「编辑习惯中底部，可以将打卡日志关闭」；
  /// 缺省 true——存量行/旧数据无键按开启）。
  final bool journalEnabled;

  /// 习惯提醒时间段列表（specs/134，矩阵 #45 面 ②；嘀嗒
  /// 《02-更好地完成习惯.md》:40「提示时间可分在各个时间段」）。
  /// null = 未设置（沿用单值 reminderAt）。
  final List<String>? reminderTimes;

  HabitDto({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.period = 1,
    this.targetCount = 1,
    this.reminderAt,
    this.sortOrder = 0,
    this.archived = false,
    this.recordType = 1,
    this.journalEnabled = true,
    this.reminderTimes,
  });

  factory HabitDto.fromJson(Map<String, dynamic> j) {
    return HabitDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      icon: j['icon']?.toString(),
      color: j['color']?.toString(),
      period: (j['period'] as num?)?.toInt() ?? 1,
      targetCount:
          (j['targetCount'] as num?)?.toInt() ??
          (j['targetPerWeek'] as num?)?.toInt() ??
          1,
      reminderAt: _epochMillisToDateTime(j['reminderAt']),
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      archived: j['archived'] == true,
      recordType: (j['recordType'] as num?)?.toInt() ?? 1,
      journalEnabled: j['journalEnabled'] != false,
      reminderTimes: j['reminderTimes'] != null
          ? (j['reminderTimes'] as List).map((v) => v.toString()).toList()
          : null,
    );
  }
}

/// 服务端 `LocalDateTime` 全局走 epoch 毫秒（`TimestampLocalDateTimeSerializer`）。
DateTime? _epochMillisToDateTime(Object? value) {
  final millis = (value as num?)?.toInt();
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

Map<String, Object?> _habitBody({
  required String name,
  String? icon,
  String? color,
  required int period,
  required int targetCount,
  DateTime? reminderAt,
  int sortOrder = 0,
  int recordType = 1,
  bool journalEnabled = true,
}) {
  return {
    'name': name,
    'icon': icon,
    'color': color,
    'period': period,
    'targetCount': targetCount,
    'reminderAt': reminderAt?.millisecondsSinceEpoch,
    'sortOrder': sortOrder,
    'recordType': recordType,
    // 习惯级「打卡日志」开关（specs/132，矩阵 #45 面 ④ 收尾）。
    'journalEnabled': journalEnabled,
  };
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
    String? icon,
    String? color,
    int period = 1,
    int targetCount = 1,
    DateTime? reminderAt,
    int recordType = 1,
    bool journalEnabled = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/create',
      data: _habitBody(
        name: name,
        icon: icon,
        color: color,
        period: period,
        targetCount: targetCount,
        reminderAt: reminderAt,
        recordType: recordType,
        journalEnabled: journalEnabled,
      ),
    );
    return _unwrapInt(response.data);
  }

  /// 更新习惯。`reminderAt` / `icon` 等传 null 表示「不改动」而非「清除」：
  /// 服务端 `updateHabit` 走整行 `updateById`，而 MyBatis-Plus 默认
  /// `NOT_NULL` 更新策略不会把 null 写进 SET 子句（见 specs/037 spec FR-3 边界②）。
  Future<void> update({
    required int id,
    required String name,
    String? icon,
    String? color,
    required int period,
    required int targetCount,
    DateTime? reminderAt,
    int sortOrder = 0,
    int recordType = 1,
    bool journalEnabled = true,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/update',
      data: {
        ..._habitBody(
          name: name,
          icon: icon,
          color: color,
          period: period,
          targetCount: targetCount,
          reminderAt: reminderAt,
          sortOrder: sortOrder,
          recordType: recordType,
          journalEnabled: journalEnabled,
        ),
        'id': id,
      },
    );
    _unwrapBool(response.data);
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/delete',
      queryParameters: {'id': id},
    );
    _unwrapBool(response.data);
  }

  /// 打卡：返回当日累计打卡次数（后端计算）。
  /// `amount` 只在手动记录档（recordType=2）传入：本次完成量（嘀嗒打卡时可输入）。
  /// `note` 携带心情/日志（specs/131，矩阵 #45 面 ④）：首行五档 emoji 或空，
  /// 其余为日志正文——服务端透传，拆分约定在客户端。
  Future<int> checkIn(
    int habitId, {
    DateTime? date,
    int? amount,
    String? note,
  }) async {
    final d = date ?? DateTime.now();
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/check-in',
      data: {
        'habitId': habitId,
        'checkedAt': d.millisecondsSinceEpoch,
        'amount': ?amount,
        'note': ?note,
      },
    );
    return _unwrapInt(r.data);
  }

  /// 打卡日志（specs/131，矩阵 #45 面 ④）：最近 N 条（checkedAt 倒序）。
  Future<List<HabitCheckInEntry>> listCheckIns(
    int habitId, {
    int limit = 30,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/check-in/list',
      queryParameters: {'habitId': habitId, 'limit': limit},
    );
    final data = _unwrapHabitData(r.data);
    final rows = data is List ? data : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((e) => HabitCheckInEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
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
    throw envelopeFailure(body, path: ApiConfig.todoPrefix);
  }
  final data = body.containsKey('code') ? body['data'] : body;
  if (data is num) return data.toInt();
  if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
  return int.tryParse('$data') ?? 0;
}

dynamic _unwrapHabitData(Map<String, dynamic>? body) {
  if (body == null) return null;
  if (body.containsKey('code') && body['code'] != 0) {
    throw envelopeFailure(body, path: ApiConfig.todoPrefix);
  }
  return body.containsKey('code') ? body['data'] : body;
}

void _unwrapBool(Map<String, dynamic>? body) {
  if (body == null) return;
  if (body.containsKey('code') && body['code'] != 0) {
    throw envelopeFailure(body, path: ApiConfig.todoPrefix);
  }
}

/// 打卡日志条目（`AppTodoHabitCheckInListRespVO`；specs/131）。
class HabitCheckInEntry {
  const HabitCheckInEntry({
    required this.id,
    required this.checkedAt,
    this.note,
    this.amount,
  });

  final int id;
  final DateTime checkedAt;

  /// 首行可能是心情 emoji（五档之一），其余为日志正文。
  final String? note;
  final int? amount;

  factory HabitCheckInEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['checkedAt'];
    DateTime parseDate() {
      final v = rawDate;
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      final parts = v?.toString().split('-') ?? const <String>[];
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return HabitCheckInEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      checkedAt: parseDate(),
      note: json['note']?.toString(),
      amount: (json['amount'] as num?)?.toInt(),
    );
  }

  /// (心情 emoji, 日志正文)；note 空时返回 null。
  /// 心情约定：首行命中五档 emoji 之一时拆出，其余为正文；无心情但有日志
  /// 时 mood 为 null；纯 emoji 时 journal 为 null。
  (String?, String?)? get moodAndJournal {
    final text = note ?? '';
    if (text.isEmpty) return null;
    final lines = text.split('\n');
    const moods = ['😊', '😐', '😞', '🤩', '😤'];
    if (moods.contains(lines.first.trim())) {
      final journal = lines.length > 1 ? lines.sublist(1).join('\n') : null;
      return (lines.first.trim(), journal);
    }
    return (null, text);
  }
}
