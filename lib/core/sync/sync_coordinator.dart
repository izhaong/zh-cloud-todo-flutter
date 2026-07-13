import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/attachment_upload_api.dart';
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
    AttachmentUploadApi? attachmentApi,
    Uuid? uuid,
  }) : _attachmentApi = attachmentApi ?? DioAttachmentUploadApi(todoApi),
       _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final SyncApi api;
  final ApiClient todoApi;
  final AttachmentUploadApi _attachmentApi;
  final Uuid _uuid;

  int _tempIdSeq = 0;
  final Map<String, int> _tempEntityIdsByLocalId = {};

  static const _inboxListId = 'inbox';
  static const _inboxListName = '收集箱';

  /// 单轮同步：先 push 本地变更，再 pull 远端增量。
  Future<SyncOutcome> syncOnce() async {
    final pushed = await push();
    final pulled = await pull();
    return SyncOutcome(pushed: pushed, pulled: pulled);
  }

  // --- Push ------------------------------------------------------------

  Future<int> push() async {
    await _prepareInboxChangesForPush();
    final pending = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.status.equals('queued'))).get();
    if (pending.isEmpty) return 0;

    final folderChanges = pending
        .where((c) => c.entity == SyncEntities.folder)
        .toList();
    final attachmentChanges = pending
        .where((c) => c.entity == SyncEntities.attachment)
        .toList();
    final templateChanges = pending
        .where((c) => c.entity == SyncEntities.template)
        .toList();
    final syncableChanges =
        pending.where((c) => SyncEntities.syncable.contains(c.entity)).toList()
          ..sort(_compareSyncChanges);

    var succeeded = 0;
    succeeded += await _pushFolderChanges(folderChanges);
    // 附件登记依赖任务刚回写的 serverId，必须在 task/list 等同步实体
    // 成功映射后执行，避免网络恢复后的首轮同步遗留 queued 附件。
    succeeded += await _pushSyncableChanges(syncableChanges);
    succeeded += await _pushAttachmentChanges(attachmentChanges);
    succeeded += await _pushTemplateChanges(templateChanges);
    return succeeded;
  }

  /// 兼容旧版本已经在本地使用 `inbox` 但没有真实 list outbox 的任务。
  ///
  /// 这类创建变更曾被错误地转换为孤立临时 list ID。升级后补齐收集箱 list
  /// 变更并仅重排尚未拥有服务端 ID 的失败任务，使下一次同步可恢复。
  Future<void> _prepareInboxChangesForPush() async {
    final changes = await db.select(db.todoSyncChanges).get();
    final inboxTaskChanges = <TodoSyncChange>[];
    for (final change in changes) {
      if (change.entity != SyncEntities.task ||
          change.op != SyncOps.upsert ||
          (change.status != 'queued' && change.status != 'failed')) {
        continue;
      }
      try {
        final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
        if (payload['listId'] == _inboxListId) {
          inboxTaskChanges.add(change);
        }
      } on FormatException {
        // 损坏 outbox 仍由既有失败处理保留，不能阻塞其它可恢复任务。
      }
    }
    if (inboxTaskChanges.isEmpty) return;

    await db.transaction(() async {
      var inbox = await db.listByLocalId(_inboxListId);
      if (inbox == null) {
        final now = DateTime.now();
        await db
            .into(db.todoLists)
            .insert(
              TodoListsCompanion.insert(
                id: _inboxListId,
                name: _inboxListName,
                sortOrder: const Value(0),
                updatedAt: now,
                createdAt: now,
              ),
            );
        inbox = await db.listByLocalId(_inboxListId);
      }
      TodoSyncChange? existingInboxChange;
      for (final change in changes) {
        if (change.entity == SyncEntities.list &&
            change.entityLocalId == _inboxListId &&
            (change.status == 'queued' || change.status == 'failed')) {
          existingInboxChange = change;
          break;
        }
      }
      if (inbox!.serverId == null) {
        if (existingInboxChange == null) {
          await db
              .into(db.todoSyncChanges)
              .insert(
                TodoSyncChangesCompanion.insert(
                  clientMutationId: _uuid.v4(),
                  entity: SyncEntities.list,
                  op: SyncOps.upsert,
                  entityLocalId: const Value(_inboxListId),
                  payloadJson: jsonEncode(inbox.toJson()),
                  createdAt: DateTime.now(),
                ),
              );
        } else if (existingInboxChange.status == 'failed') {
          await (db.update(db.todoSyncChanges)
                ..where((row) => row.id.equals(existingInboxChange!.id)))
              .write(const TodoSyncChangesCompanion(status: Value('queued')));
        }
      }
      for (final change in inboxTaskChanges) {
        if (change.status == 'failed' && change.entityServerId == null) {
          await (db.update(db.todoSyncChanges)
                ..where((row) => row.id.equals(change.id)))
              .write(const TodoSyncChangesCompanion(status: Value('queued')));
        }
      }
    });
  }

  int _compareSyncChanges(TodoSyncChange left, TodoSyncChange right) {
    final priority = {
      SyncEntities.list: 0,
      SyncEntities.tag: 1,
      SyncEntities.task: 2,
      SyncEntities.reminder: 3,
      SyncEntities.repeatRule: 3,
      SyncEntities.repeatSkip: 4,
    };
    final byEntity = (priority[left.entity] ?? 9).compareTo(
      priority[right.entity] ?? 9,
    );
    return byEntity != 0 ? byEntity : left.createdAt.compareTo(right.createdAt);
  }

  Future<int> _pushAttachmentChanges(List<TodoSyncChange> changes) async {
    var succeeded = 0;
    for (final change in changes) {
      final localId = change.entityLocalId;
      if (change.op == SyncOps.delete) {
        final serverId = change.entityServerId;
        if (serverId == null) {
          await (db.update(db.todoSyncChanges)
                ..where((row) => row.id.equals(change.id)))
              .write(const TodoSyncChangesCompanion(status: Value('synced')));
          succeeded++;
          continue;
        }
        try {
          await _attachmentApi.deleteTaskAttachment(serverId: serverId);
          await (db.update(db.todoSyncChanges)
                ..where((row) => row.id.equals(change.id)))
              .write(const TodoSyncChangesCompanion(status: Value('synced')));
          succeeded++;
        } catch (_) {
          await (db.update(
            db.todoSyncChanges,
          )..where((row) => row.id.equals(change.id))).write(
            TodoSyncChangesCompanion(
              status: const Value('failed'),
              attemptCount: Value(change.attemptCount + 1),
            ),
          );
        }
        continue;
      }
      if (localId == null) continue;
      final attachment = await (db.select(
        db.todoAttachments,
      )..where((row) => row.id.equals(localId))).getSingleOrNull();
      if (attachment == null || attachment.localPath == null) continue;
      final task = await (db.select(
        db.todoTasks,
      )..where((row) => row.id.equals(attachment.taskId))).getSingleOrNull();
      if (task?.serverId == null) continue;
      try {
        await (db.update(
          db.todoAttachments,
        )..where((row) => row.id.equals(localId))).write(
          TodoAttachmentsCompanion(
            status: const Value('uploading'),
            error: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final url = await _attachmentApi.uploadFile(
          localPath: attachment.localPath!,
          name: attachment.name,
        );
        final serverId = await _attachmentApi.registerTaskAttachment(
          taskServerId: task!.serverId!,
          name: attachment.name,
          url: url,
          size: attachment.size,
          mimeType: attachment.mimeType,
          clientMutationId: change.clientMutationId,
        );
        await (db.update(
          db.todoAttachments,
        )..where((row) => row.id.equals(localId))).write(
          TodoAttachmentsCompanion(
            serverId: Value(serverId),
            remoteUrl: Value(url),
            status: const Value('uploaded'),
            error: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (db.update(db.todoSyncChanges)
              ..where((row) => row.id.equals(change.id)))
            .write(const TodoSyncChangesCompanion(status: Value('synced')));
        succeeded++;
      } catch (error) {
        await (db.update(
          db.todoAttachments,
        )..where((row) => row.id.equals(localId))).write(
          TodoAttachmentsCompanion(
            status: const Value('failed'),
            error: Value(error.toString()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (db.update(
          db.todoSyncChanges,
        )..where((row) => row.id.equals(change.id))).write(
          TodoSyncChangesCompanion(
            status: const Value('failed'),
            attemptCount: Value(change.attemptCount + 1),
          ),
        );
      }
    }
    return succeeded;
  }

  Future<int> _pushTemplateChanges(List<TodoSyncChange> changes) async {
    var succeeded = 0;
    for (final change in changes) {
      if (change.op == SyncOps.delete || change.entityLocalId == null) continue;
      final localId = change.entityLocalId!;
      final template = await (db.select(
        db.todoTemplates,
      )..where((row) => row.id.equals(localId))).getSingleOrNull();
      if (template == null || template.serverId != null) continue;
      try {
        final response = await todoApi.post<Map<String, dynamic>>(
          '/template/create',
          data: {
            'name': template.name,
            'templateType': 1,
            'content': template.contentJson,
            'clientMutationId': change.clientMutationId,
          },
        );
        final body = response.data ?? const <String, dynamic>{};
        if (body['code'] != null && body['code'] != 0) {
          throw StateError(body['msg']?.toString() ?? '模板登记失败');
        }
        final serverId = (body['data'] as num?)?.toInt();
        if (serverId == null) throw StateError('模板登记未返回 ID');
        await (db.update(
          db.todoTemplates,
        )..where((row) => row.id.equals(localId))).write(
          TodoTemplatesCompanion(
            serverId: Value(serverId),
            status: const Value('synced'),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (db.update(db.todoSyncChanges)
              ..where((row) => row.id.equals(change.id)))
            .write(const TodoSyncChangesCompanion(status: Value('synced')));
        succeeded++;
      } catch (_) {
        await (db.update(
          db.todoSyncChanges,
        )..where((row) => row.id.equals(change.id))).write(
          TodoSyncChangesCompanion(
            status: const Value('failed'),
            attemptCount: Value(change.attemptCount + 1),
          ),
        );
      }
    }
    return succeeded;
  }

  Future<int> _pushSyncableChanges(List<TodoSyncChange> changes) async {
    if (changes.isEmpty) return 0;
    _tempIdSeq = 0;
    _tempEntityIdsByLocalId.clear();
    for (final change in changes) {
      if (change.entityServerId == null && change.entityLocalId != null) {
        _temporaryIdFor(change.entityLocalId!);
      }
    }
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
          final isConflict = result.conflicts.any(
            (c) => c.clientMutationId == change.clientMutationId,
          );
          await (db.update(
            db.todoSyncChanges,
          )..where((t) => t.id.equals(change.id))).write(
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
    } else if (change.entityLocalId != null) {
      entityId = _temporaryIdFor(change.entityLocalId!);
    } else {
      entityId = -(++_tempIdSeq);
    }

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
        resolved['listId'] = list?.serverId ?? _temporaryIdFor(localListId);
      }
    }
    if (entity == SyncEntities.task && resolved.containsKey('parentTaskId')) {
      final localParentId = resolved['parentTaskId']?.toString();
      if (localParentId != null && localParentId.isNotEmpty) {
        final parent = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localParentId))).getSingleOrNull();
        resolved['parentTaskId'] =
            parent?.serverId ?? _temporaryIdFor(localParentId);
      }
    }
    if (entity == SyncEntities.taskTag) {
      final localTaskId = resolved['taskId']?.toString();
      if (localTaskId != null && localTaskId.isNotEmpty) {
        final task = await (db.select(
          db.todoTasks,
        )..where((t) => t.id.equals(localTaskId))).getSingleOrNull();
        resolved['taskId'] = task?.serverId ?? _temporaryIdFor(localTaskId);
      }
      final localTagId = resolved['tagId']?.toString();
      if (localTagId != null && localTagId.isNotEmpty) {
        final tag = await (db.select(
          db.todoTags,
        )..where((t) => t.id.equals(localTagId))).getSingleOrNull();
        resolved['tagId'] = tag?.serverId ?? _temporaryIdFor(localTagId);
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
        resolved['taskId'] = task?.serverId ?? _temporaryIdFor(localTaskId);
      }
    }
    if (entity == SyncEntities.repeatSkip &&
        resolved.containsKey('repeatRuleId')) {
      final localRuleId = resolved['repeatRuleId']?.toString();
      if (localRuleId != null && localRuleId.isNotEmpty) {
        final rule = await (db.select(
          db.todoRepeatRules,
        )..where((t) => t.id.equals(localRuleId))).getSingleOrNull();
        resolved['repeatRuleId'] =
            rule?.serverId ?? _temporaryIdFor(localRuleId);
      }
    }
    if (entity == SyncEntities.viewPreference &&
        resolved['sourceType'] == 'TASK_CAPTURE' &&
        resolved['sourceKey'] == 'defaults') {
      final valueJson = resolved['valueJson'];
      if (valueJson is String) {
        try {
          final value = jsonDecode(valueJson);
          if (value is Map<String, dynamic>) {
            final localListId = value['defaultListId']?.toString();
            if (localListId != null && localListId != 'inbox') {
              // 本地 UUID 对另一台设备没有意义；服务端只保存可解析的
              // Todo list serverId。若列表尚未同步，远端安全降级为收集箱。
              value.remove('defaultListId');
              final list = await (db.select(
                db.todoLists,
              )..where((row) => row.id.equals(localListId))).getSingleOrNull();
              if (list?.serverId != null) {
                value['defaultListServerId'] = list!.serverId;
              }
            }
            resolved['valueJson'] = jsonEncode(value);
          }
        } on FormatException {
          // Repository 会以安全默认值处理损坏的本地偏好；同步不阻塞其他变更。
        }
      }
    }
    // 移除仅本地使用的字段，避免污染服务端 payload。
    resolved.remove('id');
    resolved.remove('serverId');
    return resolved;
  }

  int _temporaryIdFor(String localId) =>
      _tempEntityIdsByLocalId.putIfAbsent(localId, () => -(++_tempIdSeq));

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
        if (await _isChecklistMutation(accepted.clientMutationId)) {
          await _bindServerId(
            db.todoChecklistItems,
            db.todoChecklistItems.serverId,
            accepted.clientMutationId,
            accepted.entityId!,
          );
        } else {
          await _bindServerId(
            db.todoTasks,
            db.todoTasks.serverId,
            accepted.clientMutationId,
            accepted.entityId!,
          );
        }
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
    final change =
        await (db.select(db.todoSyncChanges)
              ..where((t) => t.clientMutationId.equals(clientMutationId)))
            .getSingleOrNull();
    final localId = change?.entityLocalId;
    if (localId == null) return;
    await (db.update(table)..where((t) => (t as dynamic).id.equals(localId)))
        .write(RawValuesInsertable({serverIdColumn.name: Variable(entityId)}));
  }

  Future<bool> _isChecklistMutation(String? clientMutationId) async {
    if (clientMutationId == null) return false;
    final change =
        await (db.select(db.todoSyncChanges)
              ..where((t) => t.clientMutationId.equals(clientMutationId)))
            .getSingleOrNull();
    if (change == null) return false;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    return payload['isChecklistItem'] == true;
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
      for (final change in _orderPulledChanges(result.changes)) {
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

  /// 服务端变更流不承诺父子实体的返回顺序。先应用清单和普通父任务，
  /// 再应用依赖父任务 ID 的子任务、提醒和检查事项，避免首次第二设备拉取
  /// 因本地映射尚未建立而静默丢弃子实体。
  List<SyncChangeDto> _orderPulledChanges(List<SyncChangeDto> changes) {
    final indexed = changes.indexed.toList()
      ..sort((left, right) {
        final byPriority = _pulledChangePriority(
          left.$2,
        ).compareTo(_pulledChangePriority(right.$2));
        return byPriority != 0 ? byPriority : left.$1.compareTo(right.$1);
      });
    return indexed.map((entry) => entry.$2).toList();
  }

  int _pulledChangePriority(SyncChangeDto change) {
    if (change.entityType == SyncEntities.list) return 0;
    if (change.entityType == SyncEntities.task) {
      if (change.payload?['isChecklistItem'] == true) return 5;
      return change.payload?['parentTaskId'] == null ? 1 : 2;
    }
    if (change.entityType == SyncEntities.tag) return 3;
    if (change.entityType == SyncEntities.taskTag) return 6;
    return 4;
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
        await (db.delete(
          db.todoChecklistItems,
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
    final isInbox = payload['name']?.toString() == _inboxListName;
    final existing =
        await db.listByServerId(serverId) ??
        (isInbox ? await db.listByLocalId(_inboxListId) : null);
    final now = DateTime.now();
    final companion = TodoListsCompanion(
      id: Value(existing?.id ?? (isInbox ? _inboxListId : _uuid.v4())),
      serverId: Value(serverId),
      name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
      folderId: Value(
        (payload['folderId'] as num?)?.toInt() ?? existing?.folderId,
      ),
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
    if (payload['isChecklistItem'] == true) {
      await _upsertLocalChecklistItem(serverId, payload);
      return;
    }
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
      completed: Value(
        status == 'DONE' || status == 'COMPLETED' || status == 'done',
      ),
      cancelled: Value(status == 'CANCELLED' || status == 'cancelled'),
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

  Future<void> _upsertLocalChecklistItem(
    int serverId,
    Map<String, dynamic> payload,
  ) async {
    final localTaskId = await _localTaskIdForServerId(
      (payload['parentTaskId'] as num?)?.toInt(),
    );
    if (localTaskId == null) return;
    final existing = await (db.select(
      db.todoChecklistItems,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    final now = DateTime.now();
    final status = payload['status']?.toString();
    final companion = TodoChecklistItemsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(serverId),
      taskId: Value(localTaskId),
      title: Value(payload['title']?.toString() ?? existing?.title ?? ''),
      completed: Value(status == 'DONE' || status == 'COMPLETED'),
      sortOrder: Value((payload['sortOrder'] as num?)?.toInt() ?? 0),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await db.into(db.todoChecklistItems).insert(companion);
    } else {
      await (db.update(
        db.todoChecklistItems,
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
      freq: Value(
        payload['frequency']?.toString() ??
            payload['freq']?.toString() ??
            'DAILY',
      ),
      interval: Value(
        (payload['intervalValue'] as num?)?.toInt() ??
            (payload['interval'] as num?)?.toInt() ??
            1,
      ),
      byDay: Value(
        payload['weekdays']?.toString() ?? payload['byDay']?.toString(),
      ),
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
    final localPayload = Map<String, dynamic>.from(payload);
    final nestedValue = localPayload['valueJson'];
    if (sourceType == 'TASK_CAPTURE' &&
        sourceKey == 'defaults' &&
        nestedValue is String) {
      try {
        final value = jsonDecode(nestedValue);
        if (value is Map<String, dynamic>) {
          final listServerId = (value['defaultListServerId'] as num?)?.toInt();
          if (listServerId != null) {
            final list =
                await (db.select(db.todoLists)
                      ..where((row) => row.serverId.equals(listServerId)))
                    .getSingleOrNull();
            if (list != null) value['defaultListId'] = list.id;
          }
          value.remove('defaultListServerId');
          localPayload['valueJson'] = jsonEncode(value);
        }
      } on FormatException {
        // 与本地 defaults repository 一致：保留原文，由读取侧降级为空默认值。
      }
    }
    final now = DateTime.now();
    await db
        .into(db.todoViewPreferences)
        .insertOnConflictUpdate(
          TodoViewPreferencesCompanion.insert(
            id: _uuid.v4(),
            serverId: Value(serverId),
            sourceType: sourceType,
            sourceKey: sourceKey,
            valueJson: jsonEncode(localPayload),
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
      conditionJson: Value(
        jsonEncode(
          payload['conditionsJson'] ?? payload['conditions'] ?? payload,
        ),
      ),
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
    final existing =
        await (db.select(db.todoTaskTags)..where(
              (t) => t.taskId.equals(localTaskId) & t.tagId.equals(localTagId),
            ))
            .getSingleOrNull();
    if (existing != null) return; // 复合键已存在，跳过
    await db
        .into(db.todoTaskTags)
        .insert(
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
