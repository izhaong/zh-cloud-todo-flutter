import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/sync_api.dart';
import '../api/todo_client.dart';
import '../db/app_database.dart';
import '../state/sync_change_queue.dart';

/// 离线优先双向同步协调器。
///
/// - [push]：批量上推 outbox（`todo_sync_change`，status=queued），
///   创建操作用 `entityId = -localId` 作为临时 ID（与后端
///   `TodoSyncServiceImpl.resolveEntityId` 的 `<=0` 约定一致），
///   接受响应后回写本地 `serverId` / revision；冲突以服务端版本覆盖本地。
/// - [pull]：按游标增量拉取远端变更/墓碑，upsert 或删除本地镜像行。
/// - `folder` 不在后端 `/sync` 白名单内，[push] 时改为直连
///   `/app-api/todo/folder` REST 端点（仍复用 outbox 做离线重试）。
class SyncCoordinator {
  SyncCoordinator({
    required this.db,
    required this.api,
    required this.todoApi,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final SyncApi api;
  final TodoApiClient todoApi;
  final Uuid _uuid;

  Future<SyncOutcome> syncOnce() async {
    final pushed = await push();
    final pulled = await pull();
    return SyncOutcome(pushed: pushed, pulled: pulled);
  }

  // --- Push ------------------------------------------------------------

  Future<int> push() async {
    final pending = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.status.equals('queued'))).get();
    if (pending.isEmpty) return 0;

    final folderChanges = pending
        .where((c) => c.entity == SyncEntities.folder)
        .toList();
    final syncableChanges = pending
        .where((c) => SyncEntities.syncable.contains(c.entity))
        .toList();

    var succeeded = 0;
    succeeded += await _pushFolderChanges(folderChanges);
    succeeded += await _pushSyncableChanges(syncableChanges);
    return succeeded;
  }

  Future<int> _pushSyncableChanges(List<TodoSyncChange> changes) async {
    if (changes.isEmpty) return 0;
    final dtos = <SyncChangeDto>[];
    for (final change in changes) {
      final dto = await _toChangeDto(change);
      if (dto != null) dtos.add(dto);
    }
    if (dtos.isEmpty) return 0;

    try {
      final result = await api.push(idempotencyKey: _uuid.v4(), changes: dtos);
      for (final accepted in result.accepted) {
        await _applyAccepted(accepted);
      }
      for (final conflict in result.conflicts) {
        await _applyConflict(conflict);
      }
      final acceptedIds = {
        for (final a in result.accepted) a.clientMutationId,
        for (final c in result.conflicts) c.clientMutationId,
      };
      var count = 0;
      for (final change in changes) {
        if (acceptedIds.contains(change.clientMutationId)) {
          await (db.update(db.todoSyncChanges)
                ..where((t) => t.id.equals(change.id)))
              .write(const TodoSyncChangesCompanion(status: Value('synced')));
          count++;
        }
      }
      return count;
    } catch (_) {
      for (final change in changes) {
        await (db.update(
          db.todoSyncChanges,
        )..where((t) => t.id.equals(change.id))).write(
          TodoSyncChangesCompanion(
            status: const Value('failed'),
            attemptCount: Value(change.attemptCount + 1),
          ),
        );
      }
      return 0;
    }
  }

  /// `folder` 走普通 REST，不进入 `/sync` 协议。
  Future<int> _pushFolderChanges(List<TodoSyncChange> changes) async {
    var count = 0;
    for (final change in changes) {
      try {
        final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
        if (change.op == SyncOps.delete) {
          if (change.entityServerId != null) {
            await todoApi.delete('/folder/${change.entityServerId}');
          }
        } else if (change.entityServerId == null) {
          final resp = await todoApi.post<Map<String, dynamic>>(
            '/folder/create',
            data: {'name': payload['name']},
          );
          final serverId = (resp.data?['data'] as num?)?.toInt();
          if (serverId != null && change.entityLocalId != null) {
            await (db.update(db.todoFolders)
                  ..where((t) => t.id.equals(change.entityLocalId!)))
                .write(TodoFoldersCompanion(serverId: Value(serverId)));
          }
        } else {
          await todoApi.put(
            '/folder/update',
            data: {'id': change.entityServerId, 'name': payload['name']},
          );
        }
        await (db.update(db.todoSyncChanges)
              ..where((t) => t.id.equals(change.id)))
            .write(const TodoSyncChangesCompanion(status: Value('synced')));
        count++;
      } catch (_) {
        await (db.update(
          db.todoSyncChanges,
        )..where((t) => t.id.equals(change.id))).write(
          TodoSyncChangesCompanion(
            status: const Value('failed'),
            attemptCount: Value(change.attemptCount + 1),
          ),
        );
      }
    }
    return count;
  }

  Future<SyncChangeDto?> _toChangeDto(TodoSyncChange change) async {
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    final isDelete = change.op == SyncOps.delete;
    final entityId =
        change.entityServerId ??
        (change.entityLocalId == null ? null : -change.entityLocalId!);
    if (entityId == null) return null;

    int? baseRevision;
    if (change.entityServerId != null) {
      baseRevision = await db.readRevision(
        change.entity,
        change.entityServerId!,
      );
    }

    final resolvedPayload = isDelete
        ? null
        : await _resolvePayloadRefs(change.entity, payload);

    return SyncChangeDto(
      entityType: change.entity,
      entityId: entityId,
      operation: isDelete ? SyncOps.delete : SyncOps.upsert,
      baseRevision: baseRevision,
      tombstone: isDelete ? true : null,
      payload: resolvedPayload,
      clientMutationId: change.clientMutationId,
      clientUpdatedAt: change.createdAt.toUtc().toIso8601String(),
    );
  }

  /// 把 payload 内引用本地表的外键（如 task.listId）替换为服务端 ID 或
  /// 负数临时 ID（对应尚未同步的本地行），与后端 `resolvePayloadEntityRefs`
  /// 的临时 ID 约定对齐。
  Future<Map<String, dynamic>> _resolvePayloadRefs(
    String entity,
    Map<String, dynamic> payload,
  ) async {
    final resolved = Map<String, dynamic>.from(payload);
    if (entity == SyncEntities.task && resolved.containsKey('listId')) {
      final localListId = (resolved['listId'] as num?)?.toInt();
      if (localListId != null) {
        final list = await (db.select(
          db.todoLists,
        )..where((t) => t.id.equals(localListId))).getSingleOrNull();
        resolved['listId'] = list?.serverId ?? -localListId;
      }
    }
    if (entity == SyncEntities.taskTag && resolved.containsKey('taskId')) {
      final localTaskId = (resolved['taskId'] as num?)?.toInt();
      if (localTaskId != null) {
        final task = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localTaskId))).getSingleOrNull();
        resolved['taskId'] = task?.serverId ?? -localTaskId;
      }
    }
    // 移除仅本地使用的字段，避免污染服务端 payload。
    resolved.remove('id');
    resolved.remove('serverId');
    return resolved;
  }

  Future<void> _applyAccepted(SyncChangeDto accepted) async {
    if (accepted.entityId == null) return;
    if (accepted.revision != null) {
      await db.writeRevision(
        accepted.entityType,
        accepted.entityId!,
        accepted.revision!,
      );
    }
    // 回写本地行的 serverId（创建场景：本地行此前 serverId 为 null）。
    switch (accepted.entityType) {
      case SyncEntities.list:
        await _bindServerId(
          db.todoLists,
          db.todoLists.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.task:
        await _bindServerId(
          db.todoTasks,
          db.todoTasks.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.tag:
        await _bindServerId(
          db.todoTags,
          db.todoTags.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
    }
  }

  Future<void> _bindServerId<T extends Table, D>(
    TableInfo<T, D> table,
    Column<int> serverIdColumn,
    String? clientMutationId,
    int entityId,
  ) async {
    if (clientMutationId == null) return;
    final change =
        await (db.select(db.todoSyncChanges)
              ..where((t) => t.clientMutationId.equals(clientMutationId)))
            .getSingleOrNull();
    final localId = change?.entityLocalId;
    if (localId == null) return;
    await (db.update(table)..where((t) => (t as dynamic).id.equals(localId)))
        .write(RawValuesInsertable({serverIdColumn.name: Variable(entityId)}));
  }

  Future<void> _applyConflict(SyncConflictDto conflict) async {
    // 服务端优先：以 serverValue 覆盖本地对应行（若已知本地映射）。
    if (conflict.entityType == null || conflict.entityId == null) return;
    final serverValue = conflict.serverValue;
    if (serverValue == null) return;
    switch (conflict.entityType) {
      case SyncEntities.task:
        await _upsertLocalTask(conflict.entityId!, serverValue, null);
      case SyncEntities.list:
        await _upsertLocalList(conflict.entityId!, serverValue, null);
      case SyncEntities.tag:
        await _upsertLocalTag(conflict.entityId!, serverValue, null);
    }
  }

  // --- Pull --------------------------------------------------------------

  Future<int> pull({int limit = 200}) async {
    var applied = 0;
    var cursor = (await db.readSyncCursor())?.cursor;
    var hasMore = true;
    while (hasMore) {
      final result = await api.pull(cursor: cursor, limit: limit);
      for (final change in result.changes) {
        await _applyPulledChange(change);
        applied++;
      }
      for (final tombstone in result.tombstones) {
        await _applyTombstone(tombstone);
        applied++;
      }
      cursor = result.nextCursor;
      hasMore = result.hasMore;
      await db.writeSyncCursor(cursor);
      if (result.changes.isEmpty && result.tombstones.isEmpty) break;
    }
    return applied;
  }

  Future<void> _applyPulledChange(SyncChangeDto change) async {
    final entityId = change.entityId;
    final payload = change.payload;
    if (entityId == null || payload == null) return;
    if (change.revision != null) {
      await db.writeRevision(change.entityType, entityId, change.revision!);
    }
    switch (change.entityType) {
      case SyncEntities.list:
        await _upsertLocalList(entityId, payload, change.revision);
      case SyncEntities.task:
        await _upsertLocalTask(entityId, payload, change.revision);
      case SyncEntities.tag:
        await _upsertLocalTag(entityId, payload, change.revision);
      case SyncEntities.reminder:
        await _upsertLocalReminder(entityId, payload);
      case SyncEntities.repeatRule:
        await _upsertLocalRepeatRule(entityId, payload);
      case SyncEntities.viewPreference:
        await _upsertLocalViewPreference(entityId, payload);
      case SyncEntities.filter:
        await _upsertLocalFilter(entityId, payload);
    }
  }

  Future<void> _applyTombstone(SyncTombstoneDto tombstone) async {
    switch (tombstone.entityType) {
      case SyncEntities.list:
        await (db.delete(
          db.todoLists,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.task:
        await (db.delete(
          db.todoTasks,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.tag:
        await (db.delete(
          db.todoTags,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
    }
  }

  Future<void> _upsertLocalList(
    int serverId,
    Map<String, dynamic> payload,
    int? revision,
  ) async {
    final existing = await (db.select(
      db.todoLists,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoListsCompanion(
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      sortOrder: Value((payload['sortOrder'] as num?)?.toInt() ?? 0),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoLists).insert(companion);
    } else {
      await (db.update(
        db.todoLists,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalTask(
    int serverId,
    Map<String, dynamic> payload,
    int? revision,
  ) async {
    final existing = await (db.select(
      db.todoTasks,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final localListId = await _localListIdForServerId(
      (payload['listId'] as num?)?.toInt(),
    );
    final now = DateTime.now();
    final status = payload['status']?.toString();
    final companion = TodoTasksCompanion(
      serverId: Value(serverId),
      listId: Value(localListId ?? existing?.listId ?? 0),
      title: Value(payload['title']?.toString() ?? existing?.title ?? ''),
      description: Value(payload['description']?.toString()),
      completed: Value(status == 'DONE' || status == 'COMPLETED'),
      priority: Value((payload['priority'] as num?)?.toInt() ?? 0),
      isPinned: Value(payload['isPinned'] as bool? ?? false),
      sortOrder: Value((payload['sortOrder'] as num?)?.toInt() ?? 0),
      startAt: Value(_parseDate(payload['startAt'])),
      endAt: Value(_parseDate(payload['endAt'])),
      dueAt: Value(_parseDate(payload['dueAt'])),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoTasks).insert(companion);
    } else {
      await (db.update(
        db.todoTasks,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalTag(
    int serverId,
    Map<String, dynamic> payload,
    int? revision,
  ) async {
    final existing = await (db.select(
      db.todoTags,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoTagsCompanion(
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      color: Value(payload['color']?.toString()),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoTags).insert(companion);
    } else {
      await (db.update(
        db.todoTags,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalReminder(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final localTaskId = await _localTaskIdForServerId(
      (payload['taskId'] as num?)?.toInt(),
    );
    if (localTaskId == null) return;
    final existing = await (db.select(
      db.todoReminders,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoRemindersCompanion(
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      remindAt: Value(_parseDate(payload['remindAt']) ?? now),
      status: Value(payload['status']?.toString() ?? 'PENDING'),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoReminders).insert(companion);
    } else {
      await (db.update(
        db.todoReminders,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalRepeatRule(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final localTaskId = await _localTaskIdForServerId(
      (payload['taskId'] as num?)?.toInt(),
    );
    if (localTaskId == null) return;
    final existing = await (db.select(
      db.todoRepeatRules,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoRepeatRulesCompanion(
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      freq: Value(payload['freq']?.toString() ?? 'DAILY'),
      interval: Value((payload['interval'] as num?)?.toInt() ?? 1),
      byDay: Value(payload['byDay']?.toString()),
      until: Value(_parseDate(payload['until'])),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoRepeatRules).insert(companion);
    } else {
      await (db.update(
        db.todoRepeatRules,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalViewPreference(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final scope = payload['scope']?.toString() ?? 'default';
    final now = DateTime.now();
    await db
        .into(db.todoViewPreferences)
        .insertOnConflictUpdate(
          TodoViewPreferencesCompanion.insert(
            serverId: Value(serverId),
            scope: scope,
            valueJson: jsonEncode(payload),
            updatedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<void> _upsertLocalFilter(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final existing = await (db.select(
      db.todoFilters,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoFiltersCompanion(
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      conditionJson: Value(jsonEncode(payload['condition'] ?? payload)),
      sortOrder: Value((payload['sortOrder'] as num?)?.toInt() ?? 0),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoFilters).insert(companion);
    } else {
      await (db.update(
        db.todoFilters,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<int?> _localListIdForServerId(int? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(
      db.todoLists,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    return row?.id;
  }

  Future<int?> _localTaskIdForServerId(int? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(
      db.todoTasks,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    return row?.id;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse(value.toString());
  }
}

class SyncOutcome {
  SyncOutcome({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
