import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// sync_queue 写入辅助（outbox 模式）。
///
/// 任何对 sync 白名单实体（list/task/reminder/repeat_rule/repeat_skip/
/// view_preference/tag/task_tag/filter）的本地写操作，都应通过
/// [SyncChangeQueue] 记录一条 [TodoSyncChange]，由 [SyncCoordinator.push]
/// 批量上推到 `/app-api/todo/sync/push`。
///
/// - [localId]：本地 UUID（离线实体真相源）。
/// - [serverId]：已同步实体的后端整数 ID（首次创建时为 null）。
/// - [clientMutationId]：幂等键（UUID-v4），由本类生成。
///
/// `folder` 不在后端 sync 白名单内，走 REST 直连，仍复用本队列做离线重试。
/// 本辅助只负责入队；optimistic update 与远端响应回写由 [SyncCoordinator] 负责。
class SyncChangeQueue {
  SyncChangeQueue(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<void> enqueue({
    required String entity,
    required String op,
    String? localId,
    int? serverId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.todoSyncChanges).insert(
      TodoSyncChangesCompanion.insert(
        clientMutationId: _uuid.v4(),
        entity: entity,
        op: op,
        entityLocalId: Value(localId),
        entityServerId: Value(serverId),
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      ),
    );
  }
}
