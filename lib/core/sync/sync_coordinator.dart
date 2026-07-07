import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/sync_api.dart';
import '../db/app_database.dart';
import 'sync_entities.dart';

/// 离线优先双向同步协调器。
///
/// **ID 模型（对齐计划 P1 / 方案 A）**：
/// - 本地实体主键为 UUID-v4（[TodoTask.id] 等），UI 与 Repository 一律以 UUID 为准。
/// - 与后端 sync 协议（整数 `entityId` 键）的映射收敛在本层：
///   - 已同步实体：`entityId = serverId`，`baseRevision` 取自 [AppDatabase.readRevision]。
///   - 首次创建：`entityId = -<seq>`（负数临时 ID），后端批内解析后回写 `serverId`。
///     临时 ID 序列仅在一次 push 批内有效（用 `_tempIdSeq` 自增）；本批 payload 里的
///     本地 UUID 外键引用由 [_resolvePayloadRefs] 映射为同批临时/服务端 ID。
/// - `folder` 不在 `/sync` 白名单：push 时改走 REST `/app-api/todo/folder`（仍复用 outbox）。
///
/// **冲突策略**：服务端优先——冲突时以 `serverValue` 覆盖本地行，并把该 outbox
/// 项标记 `failed` 供上层提示；复杂合并不在本轮范围。
///
/// **触发时机**：应用启动、切前台、本地 mutation、网络恢复（由
/// [SyncCoordinator.bindConnectivity] 注册；测试可不绑定）。
class SyncCoordinator {
  SyncCoordinator({
    required this.db,
    required this.api,
    required this.todoApi,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final SyncApi api;
  final ApiClient todoApi;
  final Uuid _uuid;

  int _tempIdSeq = 0;

  /// 单轮同步：先 push 本地变更，再 pull 远端增量。
  Future<SyncOutcome> syncOnce() async {
    final pushed = await push();
    final pulled = await pull();
    return SyncOutcome(pushed: pushed, pulled: pulled);
  }

  // --- Push ------------------------------------------------------------

  Future<int> push() async {
    final pending = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.status.equals('queued')))
        .get();
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
      final result = await api.push(
        idempotencyKey: _uuid.v4(),
        changes: dtos,
      );
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
          final isConflict = result.conflicts.any(
            (c) => c.clientMutationId == change.clientMutationId,
          );
          await (db.update(db.todoSyncChanges)
                ..where((t) => t.id.equals(change.id)))
              .write(
            TodoSyncChangesCompanion(
              status: Value(isConflict ? 'failed' : 'synced'),
            ),
          );
          if (!isConflict) count++;
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

  /// 把一条 outbox 变更转为后端 `SyncChangeDto`。
  Future<SyncChangeDto?> _toChangeDto(TodoSyncChange change) async {
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    final isDelete = change.op == SyncOps.delete;

    // entityId：已同步用 serverId；首次创建用本批负数临时 ID。
    int entityId;
    if (change.entityServerId != null) {
      entityId = change.entityServerId!;
    } else {
      entityId = -(++_tempIdSeq);
    }

    int? baseRevision;
    if (change.entityServerId != null) {
      baseRevision = await db.readRevision(change.entity, change.entityServerId!);
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

  /// 把 payload 内引用本地 UUID 的外键（如 task.listId）替换为服务端 ID
  /// 或本批负数临时 ID（对应尚未同步的本地行），与后端
  /// `resolvePayloadEntityRefs` 的临时 ID 约定对齐。
  Future<Map<String, dynamic>> _resolvePayloadRefs(
    String entity,
    Map<String, dynamic> payload,
  ) async {
    final resolved = Map<String, dynamic>.from(payload);
    if (entity == SyncEntities.task && resolved.containsKey('listId')) {
      final localListId = resolved['listId']?.toString();
      if (localListId != null && localListId.isNotEmpty) {
        final list = await (db.select(
          db.todoLists,
        )..where((t) => t.id.equals(localListId))).getSingleOrNull();
        resolved['listId'] = list?.serverId ?? -(++_tempIdSeq);
      }
    }
    if (entity == SyncEntities.task && resolved.containsKey('parentTaskId')) {
      final localParentId = resolved['parentTaskId']?.toString();
      if (localParentId != null && localParentId.isNotEmpty) {
        final parent = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localParentId))).getSingleOrNull();
        resolved['parentTaskId'] = parent?.serverId ?? -(++_tempIdSeq);
      }
    }
    if (entity == SyncEntities.taskTag) {
      final localTaskId = resolved['taskId']?.toString();
      if (localTaskId != null && localTaskId.isNotEmpty) {
        final task = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localTaskId))).getSingleOrNull();
        resolved['taskId'] = task?.serverId ?? -(++_tempIdSeq);
      }
      final localTagId = resolved['tagId']?.toString();
      if (localTagId != null && localTagId.isNotEmpty) {
        final tag = await (db.select(
          db.todoTags,
        )..where((t) => t.id.equals(localTagId))).getSingleOrNull();
        resolved['tagId'] = tag?.serverId ?? -(++_tempIdSeq);
      }
    }
    if (entity == SyncEntities.reminder ||
        entity == SyncEntities.repeatRule ||
        entity == SyncEntities.repeatSkip) {
      final localTaskId = resolved['taskId']?.toString();
      if (localTaskId != null && localTaskId.isNotEmpty) {
        final task = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localTaskId))).getSingleOrNull();
        resolved['taskId'] = task?.serverId ?? -(++_tempIdSeq);
      }
    }
    if (entity == SyncEntities.repeatSkip &&
        resolved.containsKey('repeatRuleId')) {
      final localRuleId = resolved['repeatRuleId']?.toString();
      if (localRuleId != null && localRuleId.isNotEmpty) {
        final rule = await (db.select(
          db.todoRepeatRules,
        )..where((t) => t.id.equals(localRuleId))).getSingleOrNull();
        resolved['repeatRuleId'] = rule?.serverId ?? -(++_tempIdSeq);
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
    // 创建场景：回写本地行的 serverId（按 clientMutationId 找 outbox → entityLocalId）。
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
      case SyncEntities.reminder:
        await _bindServerId(
          db.todoReminders,
          db.todoReminders.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.repeatRule:
        await _bindServerId(
          db.todoRepeatRules,
          db.todoRepeatRules.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.repeatSkip:
        await _bindServerId(
          db.todoRepeatSkips,
          db.todoRepeatSkips.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.viewPreference:
        await _bindServerId(
          db.todoViewPreferences,
          db.todoViewPreferences.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
      case SyncEntities.filter:
        await _bindServerId(
          db.todoFilters,
          db.todoFilters.serverId,
          accepted.clientMutationId,
          accepted.entityId!,
        );
    }
  }

  Future<void> _bindServerId<T extends Table, D>(
    TableInfo<T, D> table,
    GeneratedColumn serverIdColumn,
    String? clientMutationId,
    int entityId,
  ) async {
    if (clientMutationId == null) return;
    final change = await (db.select(db.todoSyncChanges)
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
        await _upsertLocalTask(conflict.entityId!, serverValue);
      case SyncEntities.list:
        await _upsertLocalList(conflict.entityId!, serverValue);
      case SyncEntities.tag:
        await _upsertLocalTag(conflict.entityId!, serverValue);
      case SyncEntities.reminder:
        await _upsertLocalReminder(conflict.entityId!, serverValue);
      case SyncEntities.repeatRule:
        await _upsertLocalRepeatRule(conflict.entityId!, serverValue);
      case SyncEntities.repeatSkip:
        await _upsertLocalRepeatSkip(conflict.entityId!, serverValue);
      case SyncEntities.viewPreference:
        await _upsertLocalViewPreference(conflict.entityId!, serverValue);
      case SyncEntities.filter:
        await _upsertLocalFilter(conflict.entityId!, serverValue);
    }
  }

  // --- Pull ------------------------------------------------------------

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
        await _upsertLocalList(entityId, payload);
      case SyncEntities.task:
        await _upsertLocalTask(entityId, payload);
      case SyncEntities.tag:
        await _upsertLocalTag(entityId, payload);
      case SyncEntities.reminder:
        await _upsertLocalReminder(entityId, payload);
      case SyncEntities.repeatRule:
        await _upsertLocalRepeatRule(entityId, payload);
      case SyncEntities.repeatSkip:
        await _upsertLocalRepeatSkip(entityId, payload);
      case SyncEntities.viewPreference:
        await _upsertLocalViewPreference(entityId, payload);
      case SyncEntities.filter:
        await _upsertLocalFilter(entityId, payload);
      case SyncEntities.taskTag:
        // task_tag 不允许客户端 push；pull 时按 serverId 级联 upsert。
        await _upsertLocalTaskTag(entityId, payload);
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
      case SyncEntities.reminder:
        await (db.delete(
          db.todoReminders,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.repeatRule:
        await (db.delete(
          db.todoRepeatRules,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.repeatSkip:
        await (db.delete(
          db.todoRepeatSkips,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.viewPreference:
        await (db.delete(
          db.todoViewPreferences,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.filter:
        await (db.delete(
          db.todoFilters,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
      case SyncEntities.taskTag:
        await (db.delete(
          db.todoTaskTags,
        )..where((t) => t.serverId.equals(tombstone.entityId))).go();
    }
  }

  // --- 本地 upsert（按 serverId 查行；命中则更新，否则新建本地 UUID 行）-----

  Future<void> _upsertLocalList(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final existing = await db.listByServerId(serverId);
    final now = DateTime.now();
    final companion = TodoListsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      folderId: Value((payload['folderId'] as num?)?.toInt() ?? existing?.folderId),
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
  ) async {
    final existing = await db.taskByServerId(serverId);
    final localListId = await _localListIdForServerId(
      (payload['listId'] as num?)?.toInt(),
    );
    final localParentId = await _localTaskIdForServerId(
      (payload['parentTaskId'] as num?)?.toInt(),
    );
    final now = DateTime.now();
    final status = payload['status']?.toString();
    final companion = TodoTasksCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      listId: Value(localListId ?? existing?.listId ?? ''),
      parentTaskId: Value(localParentId ?? existing?.parentTaskId),
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
  ) async {
    final existing = await db.tagByServerId(serverId);
    final now = DateTime.now();
    final companion = TodoTagsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
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
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      remindAt: Value(
        _parseDate(payload['remindAt'] ?? payload['fireAt']) ?? now,
      ),
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
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      freq: Value(payload['frequency']?.toString() ?? payload['freq']?.toString() ?? 'DAILY'),
      interval: Value((payload['intervalValue'] as num?)?.toInt() ??
          (payload['interval'] as num?)?.toInt() ??
          1),
      byDay: Value(payload['weekdays']?.toString() ?? payload['byDay']?.toString()),
      until: Value(_parseDate(payload['untilAt'] ?? payload['until'])),
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

  Future<void> _upsertLocalRepeatSkip(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final localTaskId = await _localTaskIdForServerId(
      (payload['taskId'] as num?)?.toInt(),
    );
    final localRuleId = await _localRepeatRuleIdForServerId(
      (payload['repeatRuleId'] as num?)?.toInt(),
    );
    if (localTaskId == null || localRuleId == null) return;
    final existing = await (db.select(
      db.todoRepeatSkips,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoRepeatSkipsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      repeatRuleId: Value(localRuleId),
      occurrenceDate: Value(_parseDate(payload['occurrenceAt']) ?? now),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoRepeatSkips).insert(companion);
    } else {
      await (db.update(
        db.todoRepeatSkips,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> _upsertLocalViewPreference(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final sourceType = payload['sourceType']?.toString() ?? 'default';
    final sourceKey = payload['sourceKey']?.toString() ?? 'default';
    final now = DateTime.now();
    await db.into(db.todoViewPreferences).insertOnConflictUpdate(
      TodoViewPreferencesCompanion.insert(
        id: _uuid.v4(),
        serverId: Value(serverId),
        sourceType: sourceType,
        sourceKey: sourceKey,
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
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      conditionJson: Value(jsonEncode(payload['conditionsJson'] ?? payload['conditions'] ?? payload)),
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

  Future<void> _upsertLocalTaskTag(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final localTaskId = await _localTaskIdForServerId(
      (payload['taskId'] as num?)?.toInt(),
    );
    final localTagId = await _localTagIdForServerId(
      (payload['tagId'] as num?)?.toInt(),
    );
    if (localTaskId == null || localTagId == null) return;
    final existing = await (db.select(db.todoTaskTags)
          ..where(
            (t) => t.taskId.equals(localTaskId) & t.tagId.equals(localTagId),
          ))
        .getSingleOrNull();
    if (existing != null) return; // 复合键已存在，跳过
    await db.into(db.todoTaskTags).insert(
      TodoTaskTagsCompanion.insert(
        taskId: localTaskId,
        tagId: localTagId,
        serverId: Value(serverId),
      ),
    );
  }

  // --- serverId → 本地 UUID 映射 ----------------------------------------

  Future<String?> _localListIdForServerId(int? serverId) async {
    if (serverId == null || serverId <= 0) return null;
    return (await db.listByServerId(serverId))?.id;
  }

  Future<String?> _localTaskIdForServerId(int? serverId) async {
    if (serverId == null || serverId <= 0) return null;
    return (await db.taskByServerId(serverId))?.id;
  }

  Future<String?> _localTagIdForServerId(int? serverId) async {
    if (serverId == null || serverId <= 0) return null;
    return (await db.tagByServerId(serverId))?.id;
  }

  Future<String?> _localRepeatRuleIdForServerId(int? serverId) async {
    if (serverId == null || serverId <= 0) return null;
    final row = await (db.select(
      db.todoRepeatRules,
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
