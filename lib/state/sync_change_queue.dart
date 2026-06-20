import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// M11-B2 sync_queue 写入辅助。
///
/// 任何对 LIST/TASK/FOLDER/TAG/TASK_TAG 的本地写操作，都应通过 [SyncChangeQueue]
/// 记录一条 [TodoSyncChange]，由后续 [SyncEngine.pushPending] 上推。
///
/// 该辅助只负责入队；不负责 optimistic update 和远端响应回写。
class SyncChangeQueue {
  SyncChangeQueue(this._db);

  final AppDatabase _db;

  /// entity=LIST/TASK/FOLDER/TAG/TASK_TAG
  /// op=CREATE/UPDATE/DELETE
  Future<void> enqueue({
    required String entity,
    required String op,
    int? localId,
    int? serverId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.todoSyncChanges).insert(
      TodoSyncChangesCompanion.insert(
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

/// 同步实体常量，避免散落字符串。
class SyncEntities {
  static const list = 'LIST';
  static const task = 'TASK';
  static const folder = 'FOLDER';
  static const tag = 'TAG';
  static const taskTag = 'TASK_TAG';
}

class SyncOps {
  static const create = 'CREATE';
  static const update = 'UPDATE';
  static const delete = 'DELETE';
}