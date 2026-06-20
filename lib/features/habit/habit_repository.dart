import 'package:dio/dio.dart';

import '../../api/api_config.dart';

/// 习惯数据访问 — M11-B4：纯后端驱动，不依赖本地 Drift 表
/// （schema 暂未包含 habits/habit_logs，列表与打卡均走 `/app-api/todo/habit/**`）。
class HabitDto {
  final int id;
  final String name;
  final String? color;
  final int targetPerWeek;
  final bool archived;

  HabitDto({
    required this.id,
    required this.name,
    this.color,
    this.targetPerWeek = 7,
    this.archived = false,
  });

  factory HabitDto.fromJson(Map<String, dynamic> j) {
    return HabitDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      color: j['color']?.toString(),
      targetPerWeek: (j['targetPerWeek'] as num?)?.toInt() ?? 7,
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
    final raw = (r.data?['data']?['list'] as List?) ?? (r.data?['list'] as List?) ?? [];
    return raw
        .map((e) => HabitDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 打卡：返回当日累计打卡次数（后端计算）。
  Future<int> checkIn(int habitId, {DateTime? date}) async {
    final d = date ?? DateTime.now();
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final r = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/check-in',
      data: {'habitId': habitId, 'date': key},
    );
    return (r.data?['data']?['count'] as num?)?.toInt() ?? 1;
  }

  /// 统计：连续打卡天数 / 本周完成。
  Future<Map<String, dynamic>> stats() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '${ApiConfig.todoPrefix}/habit/stats',
    );
    return Map<String, dynamic>.from(r.data?['data'] as Map? ?? {});
  }
}