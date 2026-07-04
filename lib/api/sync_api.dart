import 'package:dio/dio.dart';

/// `/app-api/todo/sync/{pull,push}` 请求/响应 DTO。
///
/// 字段命名严格对齐后端 `AppTodoSync*VO`（Jackson `@JsonProperty` 已注明的
/// 用下划线，其余用后端 Java 字段本身的驼峰命名）。
class SyncChangeDto {
  SyncChangeDto({
    this.changeId,
    required this.entityType,
    this.entityId,
    required this.operation,
    this.baseRevision,
    this.revision,
    this.tombstone,
    this.payload,
    this.clientMutationId,
    this.clientUpdatedAt,
  });

  final int? changeId;
  final String entityType;
  final int? entityId;
  final String operation; // upsert / delete
  final int? baseRevision;
  final int? revision;
  final bool? tombstone;
  final Map<String, dynamic>? payload;
  final String? clientMutationId;
  final String? clientUpdatedAt;

  Map<String, dynamic> toJson() => {
    if (changeId != null) 'changeId': changeId,
    'entityType': entityType,
    if (entityId != null) 'entityId': entityId,
    'operation': operation,
    if (baseRevision != null) 'baseRevision': baseRevision,
    if (revision != null) 'revision': revision,
    if (tombstone != null) 'tombstone': tombstone,
    if (payload != null) 'payload': payload,
    if (clientMutationId != null) 'clientMutationId': clientMutationId,
    if (clientUpdatedAt != null) 'clientUpdatedAt': clientUpdatedAt,
  };

  factory SyncChangeDto.fromJson(Map<String, dynamic> json) => SyncChangeDto(
    changeId: (json['changeId'] as num?)?.toInt(),
    entityType: json['entityType']?.toString() ?? '',
    entityId: (json['entityId'] as num?)?.toInt(),
    operation: json['operation']?.toString() ?? 'upsert',
    baseRevision: (json['baseRevision'] as num?)?.toInt(),
    revision: (json['revision'] as num?)?.toInt(),
    tombstone: json['tombstone'] as bool?,
    payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
    clientMutationId: json['clientMutationId']?.toString(),
    clientUpdatedAt: json['clientUpdatedAt']?.toString(),
  );
}

class SyncTombstoneDto {
  SyncTombstoneDto({
    required this.entityType,
    required this.entityId,
    this.revision,
    this.deletedTime,
  });

  final String entityType;
  final int entityId;
  final int? revision;
  final int? deletedTime;

  factory SyncTombstoneDto.fromJson(Map<String, dynamic> json) =>
      SyncTombstoneDto(
        entityType: json['entityType']?.toString() ?? '',
        entityId: (json['entityId'] as num?)?.toInt() ?? 0,
        revision: (json['revision'] as num?)?.toInt(),
        deletedTime: (json['deletedTime'] as num?)?.toInt(),
      );
}

class SyncConflictDto {
  SyncConflictDto({
    this.clientMutationId,
    this.entityType,
    this.entityId,
    this.reason,
    this.serverValue,
  });

  final String? clientMutationId;
  final String? entityType;
  final int? entityId;
  final String? reason;
  final Map<String, dynamic>? serverValue;

  factory SyncConflictDto.fromJson(Map<String, dynamic> json) =>
      SyncConflictDto(
        clientMutationId: json['clientMutationId']?.toString(),
        entityType: json['entityType']?.toString(),
        entityId: (json['entityId'] as num?)?.toInt(),
        reason: json['reason']?.toString(),
        serverValue: (json['serverValue'] as Map?)?.cast<String, dynamic>(),
      );
}

class SyncPullResult {
  SyncPullResult({
    required this.changes,
    required this.tombstones,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<SyncChangeDto> changes;
  final List<SyncTombstoneDto> tombstones;
  final String? nextCursor;
  final bool hasMore;
}

class SyncPushResult {
  SyncPushResult({
    required this.ok,
    required this.accepted,
    required this.conflicts,
    required this.nextCursor,
  });

  final bool ok;
  final List<SyncChangeDto> accepted;
  final List<SyncConflictDto> conflicts;
  final String? nextCursor;
}

/// `/app-api/todo/sync/{pull,push}` 客户端；直接用业务 API 的 dio 实例
/// （已由 [TodoApiClient] 注入 Bearer/tenant-id）。
class SyncApi {
  SyncApi(this._dio, {required this.clientId, required this.deviceId});

  final Dio _dio;
  final String clientId;
  final String deviceId;

  static const _prefix = '/app-api/todo/sync';

  Future<SyncPullResult> pull({
    String? cursor,
    int limit = 200,
    List<String>? entityTypes,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$_prefix/pull',
      data: {
        'client_id': clientId,
        'device_id': deviceId,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (entityTypes != null) 'entityTypes': entityTypes,
      },
    );
    final data = _unwrap(resp.data);
    final changes = (data['changes'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SyncChangeDto.fromJson)
        .toList();
    final tombstones = (data['tombstones'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SyncTombstoneDto.fromJson)
        .toList();
    return SyncPullResult(
      changes: changes,
      tombstones: tombstones,
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$_prefix/push',
      data: {
        'client_id': clientId,
        'device_id': deviceId,
        'idempotency_key': idempotencyKey,
        'changes': changes.map((c) => c.toJson()).toList(),
      },
    );
    final data = _unwrap(resp.data);
    final accepted = (data['accepted'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SyncChangeDto.fromJson)
        .toList();
    final conflicts = (data['conflicts'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SyncConflictDto.fromJson)
        .toList();
    return SyncPushResult(
      ok: data['ok'] as bool? ?? true,
      accepted: accepted,
      conflicts: conflicts,
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  /// 统一响应信封 `{code, msg, data}`，`code != 0` 视为业务错误（由 dio 400+ 状态码
  /// 或此处对 `code` 的判断共同兜底）。
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};
    if (body.containsKey('code')) {
      final code = body['code'];
      if (code != 0) {
        throw DioException(
          requestOptions: RequestOptions(path: _prefix),
          error: body['msg'] ?? '同步请求失败',
        );
      }
      return (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    }
    return body;
  }
}
