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
/// `folder` 不在后端 sync 白名单内，走 REST 直连（见 [SyncEntities.folder]
/// 的特殊路由说明），仍复用本队列做离线重试。
///
/// 该辅助只负责入队；不负责 optimistic update 和远端响应回写（由
/// [SyncCoordinator] 负责）。
class SyncChangeQueue {
  SyncChangeQueue(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<void> enqueue({
    required String entity,
    required String op,
    int? localId,
    int? serverId,
    required Map<String, dynamic> payload,
  }) async {
    await _db
        .into(_db.todoSyncChanges)
        .insert(
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

/// 同步实体常量：与后端 `TodoSyncServiceImpl.normalizeEntityType` 白名单
/// 保持一致的小写下划线命名（`folder` 例外，见类注释）。
class SyncEntities {
  static const list = 'list';
  static const task = 'task';
  static const reminder = 'reminder';
  static const repeatRule = 'repeat_rule';
  static const repeatSkip = 'repeat_skip';
  static const viewPreference = 'view_preference';
  static const tag = 'tag';
  static const taskTag = 'task_tag';
  static const filter = 'filter';

  /// 不在后端 `/sync` 白名单内、由 [SyncCoordinator] 路由到普通 REST 的实体。
  static const folder = 'folder';

  static const syncable = {
    list,
    task,
    reminder,
    repeatRule,
    repeatSkip,
    viewPreference,
    tag,
    taskTag,
    filter,
  };
}

class SyncOps {
  static const upsert = 'upsert';
  static const delete = 'delete';
}
