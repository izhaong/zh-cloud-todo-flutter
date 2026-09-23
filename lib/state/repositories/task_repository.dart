import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// M11-B2 任务仓库。
///
/// - 写操作入 drift（UI 真相源）+ sync_queue
/// - 子任务通过 [parentTaskId] 维护
/// - ID：本地 UUID（真相源），写入即生成；serverId 由 sync 层回写。
class TaskRepository {
  TaskRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  static const _inboxListId = 'inbox';
  static const _inboxListName = '收集箱';

  /// 顶层任务（无 parent）的 stream，按 listId 过滤。[listId] 本地 UUID。
  Stream<List<TodoTask>> watchTopLevelByList(String listId) {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.listId.equals(listId) & t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Stream<List<TodoTask>> watchChildrenOf(String parentTaskId) {
    return _db.watchChildrenOf(parentTaskId);
  }

  Stream<List<TodoTask>> watchAll() {
    return (_db.select(_db.todoTasks)
          ..where((t) => t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<TodoTask?> getById(String id) {
    return (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<TodoTask?> watchById(String id) {
    return (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<TodoChecklistItem>> watchChecklistItems(String taskId) {
    return (_db.select(_db.todoChecklistItems)
          ..where((item) => item.taskId.equals(taskId))
          ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
        .watch();
  }

  Stream<List<TodoAttachment>> watchAttachments(String taskId) {
    return (_db.select(_db.todoAttachments)
          ..where((attachment) => attachment.taskId.equals(taskId))
          ..orderBy([
            (attachment) => OrderingTerm(expression: attachment.createdAt),
          ]))
        .watch();
  }

  Future<TodoTask> create({
    required String listId,
    required String title,
    String? sectionId,
    String? description,
    int priority = 0,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    bool allDay = false,
    String? timeZone,
    bool fixedTimezone = false,
    String? parentTaskId,
    bool isPinned = false,
  }) async {
    if (startAt != null && endAt != null && !endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', '结束时间必须晚于开始时间');
    }
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '任务标题不能为空');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    late TodoTask row;
    await _db.transaction(() async {
      await _ensureInboxList(listId, now);
      await _requireWritableList(listId);
      await _requireSectionInList(listId, sectionId);
      await _assertParentChainDoesNotContain(null, listId, parentTaskId);
      await _db
          .into(_db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: id,
              listId: listId,
              sectionId: Value(sectionId),
              parentTaskId: Value(parentTaskId),
              title: normalizedTitle,
              description: Value(description),
              priority: Value(priority),
              isPinned: Value(isPinned),
              startAt: Value(startAt),
              endAt: Value(endAt),
              dueAt: Value(dueAt),
              allDay: Value(allDay),
              timeZone: Value(timeZone),
              fixedTimezone: Value(fixedTimezone),
              updatedAt: now,
              createdAt: now,
            ),
          );
      row = await (_db.select(
        _db.todoTasks,
      )..where((t) => t.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: id,
        payload: _taskPayload(row),
      );
    });
    return row;
  }

  /// 收集箱在 UI 中是固定入口，但同步协议需要真实的可写清单。
  ///
  /// 首次离线创建时先把保留的收集箱作为 list outbox 变更写入，再写任务，
  /// 使 [SyncCoordinator] 能在同一个批次内先创建服务端清单、再解析任务引用。
  Future<void> _ensureInboxList(String listId, DateTime now) async {
    if (listId != _inboxListId) return;
    final existing = await _db.listByLocalId(_inboxListId);
    if (existing != null) return;
    await _db
        .into(_db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: _inboxListId,
            name: _inboxListName,
            sortOrder: const Value(0),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final inbox = await _db.listByLocalId(_inboxListId);
    await _queue.enqueue(
      entity: SyncEntities.list,
      op: SyncOps.upsert,
      localId: _inboxListId,
      payload: inbox!.toJson(),
    );
  }

  Future<List<TodoTask>> createBatch({
    required String listId,
    required String input,
    int priority = 0,
    DateTime? Function(String title)? dueAtResolver,
  }) async {
    final tasks = <TodoTask>[];
    for (final line in input.split(RegExp(r'\r?\n'))) {
      final title = line.trim();
      if (title.isEmpty) continue;
      tasks.add(
        await create(
          listId: listId,
          title: title,
          priority: priority,
          dueAt: dueAtResolver?.call(title),
        ),
      );
    }
    return tasks;
  }

  /// 复制任务主体为新的离线任务；检查事项、附件及服务端活动不随副本复制。
  Future<TodoTask> copy(String taskId) async {
    final original = await (_db.select(
      _db.todoTasks,
    )..where((task) => task.id.equals(taskId))).getSingle();
    return create(
      listId: original.listId,
      sectionId: original.sectionId,
      parentTaskId: original.parentTaskId,
      title: '${original.title}（副本）',
      description: original.description,
      priority: original.priority,
      startAt: original.startAt,
      endAt: original.endAt,
      dueAt: original.dueAt,
      allDay: original.allDay,
      timeZone: original.timeZone,
      fixedTimezone: original.fixedTimezone,
    );
  }

  /// 将服务端优先冲突前的任务 payload 保存为一个新的可同步任务。
  ///
  /// 原冲突项只在副本及其 outbox 已落库后标记为 `resolved`，因此重复点击
  /// 不会生成重复副本，也不会丢失仍需用户处理的 failed 项。
  Future<int> createConflictCopies(Iterable<TodoSyncChange> changes) async {
    var restored = 0;
    for (final change in changes) {
      restored += await _db.transaction(() async {
        final current = await (_db.select(
          _db.todoSyncChanges,
        )..where((row) => row.id.equals(change.id))).getSingleOrNull();
        if (current == null ||
            current.status != 'failed' ||
            current.failureReason == null ||
            current.entity != SyncEntities.task ||
            current.op != SyncOps.upsert) {
          return 0;
        }

        final payload = jsonDecode(current.payloadJson) as Map<String, dynamic>;
        final snapshot = TodoTask.fromJson(payload);
        final now = DateTime.now();
        final id = _uuid.v4();
        await _db
            .into(_db.todoTasks)
            .insert(
              TodoTasksCompanion.insert(
                id: id,
                listId: snapshot.listId,
                parentTaskId: const Value(null),
                title: '${snapshot.title}（本地副本）',
                description: Value(snapshot.description),
                completed: Value(snapshot.completed),
                priority: Value(snapshot.priority),
                isPinned: Value(snapshot.isPinned),
                sortOrder: Value(snapshot.sortOrder),
                startAt: Value(snapshot.startAt),
                endAt: Value(snapshot.endAt),
                dueAt: Value(snapshot.dueAt),
                updatedAt: now,
                createdAt: now,
              ),
            );
        final copy = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(id))).getSingle();
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: id,
          payload: copy.toJson(),
        );
        await (_db.update(
          _db.todoSyncChanges,
        )..where((row) => row.id.equals(current.id))).write(
          const TodoSyncChangesCompanion(
            status: Value('resolved'),
            nextAttemptAt: Value(null),
          ),
        );
        return 1;
      });
    }
    return restored;
  }

  Future<TodoTask> update(
    String taskId, {
    String? title,
    String? description,
    int? priority,
    DateTime? startAt,
    DateTime? endAt,
    bool clearStartAt = false,
    bool clearEndAt = false,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? allDay,
    String? timeZone,
    bool? fixedTimezone,
    String? listId,
    String? sectionId,
    bool clearSectionId = false,
    bool? isPinned,
  }) async {
    final now = DateTime.now();
    late TodoTask row;
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.todoTasks,
      )..where((t) => t.id.equals(taskId))).getSingle();
      final nextStartAt = clearStartAt ? null : startAt ?? current.startAt;
      final nextEndAt = clearEndAt ? null : endAt ?? current.endAt;
      if (nextStartAt != null &&
          nextEndAt != null &&
          !nextEndAt.isAfter(nextStartAt)) {
        throw ArgumentError.value(nextEndAt, 'endAt', '结束时间必须晚于开始时间');
      }
      if (listId != null) await _ensureInboxList(listId, now);
      final targetListId = listId ?? current.listId;
      final targetSectionId = clearSectionId
          ? null
          : sectionId ?? current.sectionId;
      await _requireSectionInList(targetListId, targetSectionId);
      await (_db.update(
        _db.todoTasks,
      )..where((t) => t.id.equals(taskId))).write(
        TodoTasksCompanion(
          title: title == null ? const Value.absent() : Value(title),
          description: description == null
              ? const Value.absent()
              : Value(description),
          priority: priority == null ? const Value.absent() : Value(priority),
          isPinned: isPinned == null ? const Value.absent() : Value(isPinned),
          startAt: clearStartAt
              ? const Value(null)
              : startAt == null
              ? const Value.absent()
              : Value(startAt),
          endAt: clearEndAt
              ? const Value(null)
              : endAt == null
              ? const Value.absent()
              : Value(endAt),
          dueAt: clearDueAt
              ? const Value(null)
              : dueAt == null
              ? const Value.absent()
              : Value(dueAt),
          allDay: allDay == null ? const Value.absent() : Value(allDay),
          timeZone: timeZone == null ? const Value.absent() : Value(timeZone),
          fixedTimezone: fixedTimezone == null
              ? const Value.absent()
              : Value(fixedTimezone),
          listId: listId == null ? const Value.absent() : Value(listId),
          sectionId: clearSectionId
              ? const Value(null)
              : sectionId == null
              ? const Value.absent()
              : Value(sectionId),
          updatedAt: Value(now),
        ),
      );
      row = await (_db.select(
        _db.todoTasks,
      )..where((t) => t.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: taskId,
        serverId: row.serverId,
        payload: _taskPayload(row),
      );
    });
    return row;
  }

  /// 离线创建检查事项。服务端将其作为带 `isChecklistItem` 的 task 同步。
  Future<TodoChecklistItem> createChecklistItem({
    required String taskId,
    required String title,
    int? sortOrder,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '检查事项标题不能为空');
    }
    if (sortOrder != null && sortOrder < 0) {
      throw ArgumentError.value(sortOrder, 'sortOrder', '检查事项顺序不能为负数');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.transaction(() async {
      final parent = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(taskId))).getSingleOrNull();
      if (parent == null) {
        throw StateError('检查事项所属任务不存在');
      }
      final lastItem =
          await (_db.select(_db.todoChecklistItems)
                ..where((item) => item.taskId.equals(taskId))
                ..orderBy([
                  (item) => OrderingTerm(
                    expression: item.sortOrder,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();
      final effectiveSortOrder =
          sortOrder ?? (lastItem == null ? 0 : lastItem.sortOrder + 1);
      await _db
          .into(_db.todoChecklistItems)
          .insert(
            TodoChecklistItemsCompanion.insert(
              id: id,
              taskId: taskId,
              title: normalizedTitle,
              sortOrder: Value(effectiveSortOrder),
              updatedAt: now,
              createdAt: now,
            ),
          );
      final row = await (_db.select(
        _db.todoChecklistItems,
      )..where((item) => item.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: id,
        payload: {
          'listId': parent.listId,
          'parentTaskId': taskId,
          'title': row.title,
          'isChecklistItem': true,
          'status': 'TODO',
          'priority': 0,
          'sortOrder': row.sortOrder,
          'completedAt': null,
        },
      );
    });
    return (_db.select(
      _db.todoChecklistItems,
    )..where((item) => item.id.equals(id))).getSingle();
  }

  Future<TodoChecklistItem> toggleChecklistItem(String itemId) async {
    late TodoChecklistItem next;
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.todoChecklistItems,
      )..where((item) => item.id.equals(itemId))).getSingle();
      final parent = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(current.taskId))).getSingle();
      next = current.copyWith(
        completed: !current.completed,
        updatedAt: DateTime.now(),
      );
      await (_db.update(
        _db.todoChecklistItems,
      )..where((item) => item.id.equals(itemId))).write(next);
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: next.id,
        serverId: next.serverId,
        payload: {
          'listId': parent.listId,
          'parentTaskId': next.taskId,
          'title': next.title,
          'isChecklistItem': true,
          'status': next.completed ? 'DONE' : 'TODO',
          'priority': 0,
          'sortOrder': next.sortOrder,
          'completedAt': next.completed
              ? next.updatedAt.toIso8601String()
              : null,
        },
      );
    });
    return next;
  }

  /// 离线更新检查事项文本或顺序；变更复用 checklist task 的同步载荷。
  Future<TodoChecklistItem> updateChecklistItem(
    String itemId, {
    String? title,
    int? sortOrder,
  }) async {
    final normalizedTitle = title?.trim();
    if (title != null && normalizedTitle!.isEmpty) {
      throw ArgumentError.value(title, 'title', '检查事项标题不能为空');
    }
    if (sortOrder != null && sortOrder < 0) {
      throw ArgumentError.value(sortOrder, 'sortOrder', '检查事项顺序不能为负数');
    }
    late TodoChecklistItem next;
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.todoChecklistItems,
      )..where((item) => item.id.equals(itemId))).getSingle();
      final parent = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(current.taskId))).getSingle();
      if (title == null && sortOrder == null) {
        next = current;
        return;
      }
      next = current.copyWith(
        title: normalizedTitle ?? current.title,
        sortOrder: sortOrder ?? current.sortOrder,
        updatedAt: DateTime.now(),
      );
      await (_db.update(
        _db.todoChecklistItems,
      )..where((item) => item.id.equals(itemId))).write(next);
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: next.id,
        serverId: next.serverId,
        payload: {
          'listId': parent.listId,
          'parentTaskId': next.taskId,
          'title': next.title,
          'isChecklistItem': true,
          'status': next.completed ? 'DONE' : 'TODO',
          'priority': 0,
          'sortOrder': next.sortOrder,
          'completedAt': next.completed
              ? next.updatedAt.toIso8601String()
              : null,
        },
      );
    });
    return next;
  }

  /// 原子重排同一任务的全部检查事项，并逐项写入 task outbox。
  Future<void> reorderChecklistItems(
    String taskId,
    List<String> orderedItemIds,
  ) async {
    if (orderedItemIds.toSet().length != orderedItemIds.length) {
      throw ArgumentError.value(orderedItemIds, 'orderedItemIds', '不能包含重复检查事项');
    }

    await _db.transaction(() async {
      final parent = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(taskId))).getSingleOrNull();
      if (parent == null) {
        throw StateError('检查事项所属任务不存在');
      }
      await _requireWritableList(parent.listId);

      final items = await (_db.select(
        _db.todoChecklistItems,
      )..where((item) => item.taskId.equals(taskId))).get();
      final currentIds = items.map((item) => item.id).toSet();
      if (orderedItemIds.length != items.length ||
          !currentIds.containsAll(orderedItemIds)) {
        throw ArgumentError.value(
          orderedItemIds,
          'orderedItemIds',
          '必须包含任务的全部检查事项',
        );
      }
      final itemById = {for (final item in items) item.id: item};
      final now = DateTime.now();
      for (final entry in orderedItemIds.indexed) {
        final item = itemById[entry.$2]!;
        await (_db.update(
          _db.todoChecklistItems,
        )..where((row) => row.id.equals(item.id))).write(
          TodoChecklistItemsCompanion(
            sortOrder: Value(entry.$1),
            updatedAt: Value(now),
          ),
        );
        final updated = item.copyWith(sortOrder: entry.$1, updatedAt: now);
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: updated.id,
          serverId: updated.serverId,
          payload: {
            'listId': parent.listId,
            'parentTaskId': updated.taskId,
            'title': updated.title,
            'isChecklistItem': true,
            'status': updated.completed ? 'DONE' : 'TODO',
            'priority': 0,
            'sortOrder': updated.sortOrder,
            'completedAt': updated.completed
                ? updated.updatedAt.toIso8601String()
                : null,
          },
        );
      }
    });
  }

  Future<void> _requireWritableList(String listId) async {
    final list = await (_db.select(
      _db.todoLists,
    )..where((row) => row.id.equals(listId))).getSingleOrNull();
    if (list == null && listId == _inboxListId) return;
    if (list == null) {
      throw StateError('清单不存在');
    }
    if (!list.writable) {
      throw StateError('当前清单为只读，无法修改任务');
    }
  }

  Future<TodoAttachment> queueAttachment({
    required String taskId,
    required String name,
    required String localPath,
    required String mimeType,
    required int size,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    late TodoAttachment attachment;
    await _db.transaction(() async {
      await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(taskId))).getSingle();
      await _db
          .into(_db.todoAttachments)
          .insert(
            TodoAttachmentsCompanion.insert(
              id: id,
              taskId: taskId,
              name: name,
              localPath: Value(localPath),
              mimeType: mimeType,
              size: size,
              updatedAt: now,
              createdAt: now,
            ),
          );
      attachment = await (_db.select(
        _db.todoAttachments,
      )..where((row) => row.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.attachment,
        op: SyncOps.upsert,
        localId: id,
        payload: {
          'taskId': taskId,
          'name': name,
          'localPath': localPath,
          'mimeType': mimeType,
          'size': size,
        },
      );
    });
    return attachment;
  }

  Future<void> markAttachmentFailed(String attachmentId, String error) {
    return (_db.update(
      _db.todoAttachments,
    )..where((row) => row.id.equals(attachmentId))).write(
      TodoAttachmentsCompanion(
        status: const Value('failed'),
        error: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retryAttachment(String attachmentId) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.todoAttachments,
      )..where((row) => row.id.equals(attachmentId))).write(
        TodoAttachmentsCompanion(
          status: const Value('queued'),
          error: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.update(_db.todoSyncChanges)..where(
            (change) =>
                change.entity.equals(SyncEntities.attachment) &
                change.entityLocalId.equals(attachmentId),
          ))
          .write(const TodoSyncChangesCompanion(status: Value('queued')));
    });
  }

  Future<void> deleteAttachment(String attachmentId) async {
    await _db.transaction(() async {
      final attachment = await (_db.select(
        _db.todoAttachments,
      )..where((row) => row.id.equals(attachmentId))).getSingle();
      await (_db.delete(
        _db.todoAttachments,
      )..where((row) => row.id.equals(attachmentId))).go();
      if (attachment.serverId == null) {
        await (_db.delete(_db.todoSyncChanges)..where(
              (change) =>
                  change.entity.equals(SyncEntities.attachment) &
                  change.entityLocalId.equals(attachmentId),
            ))
            .go();
        return;
      }
      await _queue.enqueue(
        entity: SyncEntities.attachment,
        op: SyncOps.delete,
        localId: attachmentId,
        serverId: attachment.serverId,
        payload: const {},
      );
    });
  }

  Future<void> deleteChecklistItem(String itemId) async {
    await _db.transaction(() async {
      final item = await (_db.select(
        _db.todoChecklistItems,
      )..where((row) => row.id.equals(itemId))).getSingle();
      await (_db.delete(
        _db.todoChecklistItems,
      )..where((row) => row.id.equals(itemId))).go();
      if (item.serverId == null) {
        await (_db.delete(_db.todoSyncChanges)..where(
              (change) =>
                  change.entity.equals(SyncEntities.task) &
                  change.entityLocalId.equals(itemId),
            ))
            .go();
        return;
      }
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.delete,
        localId: itemId,
        serverId: item.serverId,
        payload: const {},
      );
    });
  }

  /// 切换置顶状态 + sync_queue。
  Future<TodoTask> togglePin(String taskId) => _db.transaction(() async {
    final current = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    final next = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );
    await (_db.update(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).write(next);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: next.serverId,
      payload: _taskPayload(next),
    );
    return next;
  });

  /// 切换完成状态 + sync_queue。
  Future<TodoTask> toggleComplete(String taskId) => _db.transaction(() async {
    final next = await _db.toggleTaskComplete(taskId);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: next.serverId,
      payload: _taskPayload(next),
    );
    return next;
  });

  Future<TodoTask> abandon(String taskId) => _db.transaction(() async {
    final current = await (_db.select(
      _db.todoTasks,
    )..where((task) => task.id.equals(taskId))).getSingleOrNull();
    if (current == null) throw StateError('任务不存在');
    final next = current.copyWith(
      cancelled: true,
      completed: false,
      updatedAt: DateTime.now(),
    );
    await (_db.update(
      _db.todoTasks,
    )..where((task) => task.id.equals(taskId))).write(next);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: next.serverId,
      payload: _taskPayload(next),
    );
    return next;
  });

  Future<void> delete(String taskId) => _db.transaction(() async {
    final row = await (_db.select(
      _db.todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    final descendants = await _collectDescendants(taskId);
    for (final d in descendants.reversed) {
      await (_db.delete(
        _db.todoTaskTags,
      )..where((t) => t.taskId.equals(d.id))).go();
      await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(d.id))).go();
      if (d.serverId != null) {
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.delete,
          localId: d.id,
          serverId: d.serverId,
          payload: {'id': d.id, 'serverId': d.serverId},
        );
      }
    }
    await (_db.delete(
      _db.todoTaskTags,
    )..where((t) => t.taskId.equals(taskId))).go();
    await (_db.delete(_db.todoTasks)..where((t) => t.id.equals(taskId))).go();
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.delete,
      localId: taskId,
      serverId: row?.serverId,
      payload: {'id': taskId, 'serverId': row?.serverId},
    );
  });

  /// 计算任务在父子链中的深度（自身为 0，即顶层任务 = 0）。
  ///
  /// 用于 §2.2 子任务深度 ≤5 的抽屉：在 [parentTaskId] 下新增子任务前校验
  /// `depthOf(parentTaskId) < 5`，避免超过服务端嵌套上限。
  Future<int> depthOf(String taskId) async {
    var depth = 0;
    var current = taskId;
    while (true) {
      final row = await (_db.select(
        _db.todoTasks,
      )..where((t) => t.id.equals(current))).getSingleOrNull();
      final parent = row?.parentTaskId;
      if (parent == null) return depth;
      depth += 1;
      current = parent;
    }
  }

  /// 任务的全部后代 id。「关联主任务」候选列表用它排除自己与后代，避免成环。
  Future<Set<String>> descendantIds(String taskId) async {
    final descendants = await _collectDescendants(taskId);
    return {for (final task in descendants) task.id};
  }

  Future<List<TodoTask>> _collectDescendants(String parentId) async {
    final result = <TodoTask>[];
    final queue = [parentId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = await _db.childrenOf(current);
      for (final c in children) {
        result.add(c);
        queue.add(c.id);
      }
    }
    return result;
  }

  Future<void> reparent(String taskId, String? newParentId) =>
      _db.transaction(() => _reparentWithinTransaction(taskId, newParentId));

  /// 将任务缩进为同层前序任务的直接子任务。
  Future<void> indent(String taskId, String previousSiblingId) =>
      _db.transaction(() async {
        final task = await _taskOrThrow(taskId);
        final previousSibling = await _taskOrThrow(previousSiblingId);
        if (task.listId != previousSibling.listId ||
            task.parentTaskId != previousSibling.parentTaskId) {
          throw StateError('缩进目标必须是同层任务');
        }
        await _reparentWithinTransaction(taskId, previousSiblingId);
      });

  /// 将任务提升一级，成为原父任务的同层任务。
  Future<void> outdent(String taskId) => _db.transaction(() async {
    final task = await _taskOrThrow(taskId);
    final parentId = task.parentTaskId;
    if (parentId == null) {
      throw StateError('顶层任务不能反缩进');
    }
    final parent = await _taskOrThrow(parentId);
    await _reparentWithinTransaction(taskId, parent.parentTaskId);
  });

  /// 解除任务与父任务的关联；顶层任务调用时保持无副作用。
  Future<void> detach(String taskId) => _db.transaction(() async {
    final task = await _taskOrThrow(taskId);
    if (task.parentTaskId == null) return;
    await _reparentWithinTransaction(taskId, null);
  });

  /// 对同一清单、同一父节点下的全部直接子任务做确定性手工排序。
  Future<void> reorderSiblings({
    required String listId,
    required String? parentTaskId,
    required List<String> orderedTaskIds,
  }) async {
    if (orderedTaskIds.toSet().length != orderedTaskIds.length) {
      throw ArgumentError.value(orderedTaskIds, 'orderedTaskIds', '不能包含重复任务');
    }
    await _db.transaction(() async {
      await _requireWritableList(listId);
      if (parentTaskId != null) {
        final parent = await _taskOrThrow(parentTaskId);
        if (parent.listId != listId) {
          throw ArgumentError.value(
            parentTaskId,
            'parentTaskId',
            '父任务必须属于同一清单',
          );
        }
      }
      final query = _db.select(_db.todoTasks)
        ..where((row) {
          final sameList = row.listId.equals(listId);
          final sameParent = parentTaskId == null
              ? row.parentTaskId.isNull()
              : row.parentTaskId.equals(parentTaskId);
          return sameList & sameParent;
        });
      final siblings = await query.get();
      final siblingIds = siblings.map((task) => task.id).toSet();
      if (orderedTaskIds.length != siblings.length ||
          !siblingIds.containsAll(orderedTaskIds)) {
        throw ArgumentError.value(
          orderedTaskIds,
          'orderedTaskIds',
          '必须包含同一父任务下的全部直接子任务',
        );
      }
      final byId = {for (final sibling in siblings) sibling.id: sibling};
      final now = DateTime.now();
      for (final entry in orderedTaskIds.indexed) {
        final task = byId[entry.$2]!;
        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(task.id))).write(
          TodoTasksCompanion(sortOrder: Value(entry.$1), updatedAt: Value(now)),
        );
        final updated = task.copyWith(sortOrder: entry.$1, updatedAt: now);
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: updated.id,
          serverId: updated.serverId,
          payload: _taskPayload(updated),
        );
      }
    });
  }

  Future<TodoTask> _taskOrThrow(String taskId) async {
    final task = await (_db.select(
      _db.todoTasks,
    )..where((row) => row.id.equals(taskId))).getSingleOrNull();
    if (task == null) throw StateError('任务不存在');
    return task;
  }

  Future<void> _requireSectionInList(
    String listId,
    String? sectionId,
  ) async {
    if (sectionId == null) return;
    final section = await (_db.select(
      _db.todoTaskSections,
    )..where((row) => row.id.equals(sectionId))).getSingleOrNull();
    if (section == null || section.listId != listId) {
      throw ArgumentError.value(sectionId, 'sectionId', '分组必须属于任务所在清单');
    }
  }

  Future<void> _reparentWithinTransaction(
    String taskId,
    String? newParentId,
  ) async {
    if (taskId == newParentId) {
      throw ArgumentError.value(newParentId, 'newParentId', '任务不能引用自身');
    }
    final task = await _taskOrThrow(taskId);
    await _requireWritableList(task.listId);
    await _assertParentChainDoesNotContain(taskId, task.listId, newParentId);
    final newTaskDepth = newParentId == null
        ? 0
        : await depthOf(newParentId) + 1;
    final subtreeDepth = await _maxDescendantDepth(taskId);
    if (newTaskDepth + subtreeDepth > 5) {
      throw StateError('任务层级不能超过五级');
    }
    await _db.reparentTask(taskId, newParentId);
    final row = await _taskOrThrow(taskId);
    await _queue.enqueue(
      entity: SyncEntities.task,
      op: SyncOps.upsert,
      localId: taskId,
      serverId: row.serverId,
      payload: _taskPayload(row),
    );
  }

  Future<int> _maxDescendantDepth(String taskId) async {
    var maximumDepth = 0;
    final pending = <(String, int)>[(taskId, 0)];
    final visited = <String>{};
    var nextIndex = 0;
    while (nextIndex < pending.length) {
      final current = pending[nextIndex++];
      if (!visited.add(current.$1)) {
        throw StateError('任务父子关系形成循环');
      }
      if (current.$2 > maximumDepth) {
        maximumDepth = current.$2;
      }
      final children = await _db.childrenOf(current.$1);
      pending.addAll(children.map((child) => (child.id, current.$2 + 1)));
    }
    return maximumDepth;
  }

  Future<void> _assertParentChainDoesNotContain(
    String? taskId,
    String taskListId,
    String? newParentId,
  ) async {
    var currentId = newParentId;
    final visited = <String>{};
    var parentChainLength = 0;
    while (currentId != null) {
      final parentId = currentId;
      if (parentId == taskId || !visited.add(parentId)) {
        throw StateError('任务父子关系形成循环');
      }
      if (parentChainLength >= 5) {
        throw StateError('任务层级不能超过五级');
      }
      final current = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.id.equals(parentId))).getSingleOrNull();
      if (current == null) {
        throw StateError('父任务不存在');
      }
      if (current.listId != taskListId) {
        throw StateError('父任务必须属于同一清单');
      }
      currentId = current.parentTaskId;
      parentChainLength += 1;
    }
  }

  Map<String, dynamic> _taskPayload(TodoTask task) {
    final payload = <String, dynamic>{
      ...task.toJson(),
      'status': task.cancelled
          ? 'cancelled'
          : task.completed
          ? 'DONE'
          : 'TODO',
      'completedAt': task.completedAt?.millisecondsSinceEpoch,
    };
    // 名称是本地展示缓存；服务端写契约只使用稳定的用户 ID。
    payload.remove('assigneeUserName');
    return payload;
  }
}
