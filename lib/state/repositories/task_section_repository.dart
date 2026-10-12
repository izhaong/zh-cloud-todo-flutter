import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 清单内 Section 的离线优先写链路。
class TaskSectionRepository {
  TaskSectionRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Stream<List<TodoTaskSection>> watchByList(String listId) {
    return (_db.select(_db.todoTaskSections)
          ..where((section) => section.listId.equals(listId))
          ..orderBy([
            (section) => OrderingTerm.asc(section.sortOrder),
            (section) => OrderingTerm.asc(section.id),
          ]))
        .watch();
  }

  Future<TodoTaskSection> create({
    required String listId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '分组名称不能为空');
    }
    if (normalizedName.length > 255) {
      throw ArgumentError.value(name, 'name', '分组名称不能超过 255 个字符');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    late TodoTaskSection section;
    await _db.transaction(() async {
      await _requireWritableList(listId);
      final last =
          await (_db.select(_db.todoTaskSections)
                ..where((row) => row.listId.equals(listId))
                ..orderBy([
                  (row) => OrderingTerm.desc(row.sortOrder),
                  (row) => OrderingTerm.desc(row.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      await _db
          .into(_db.todoTaskSections)
          .insert(
            TodoTaskSectionsCompanion.insert(
              id: id,
              listId: listId,
              name: normalizedName,
              sortOrder: Value((last?.sortOrder ?? -1) + 1),
              updatedAt: now,
              createdAt: now,
            ),
          );
      section = await (_db.select(
        _db.todoTaskSections,
      )..where((row) => row.id.equals(id))).getSingle();
      await _enqueueUpsert(section);
    });
    return section;
  }

  Future<TodoTaskSection> rename(String sectionId, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '分组名称不能为空');
    }
    if (normalizedName.length > 255) {
      throw ArgumentError.value(name, 'name', '分组名称不能超过 255 个字符');
    }
    late TodoTaskSection section;
    await _db.transaction(() async {
      final current = await _sectionOrThrow(sectionId);
      await _requireWritableList(current.listId);
      await (_db.update(
        _db.todoTaskSections,
      )..where((row) => row.id.equals(sectionId))).write(
        TodoTaskSectionsCompanion(
          name: Value(normalizedName),
          updatedAt: Value(DateTime.now()),
        ),
      );
      section = await _sectionOrThrow(sectionId);
      await _enqueueUpsert(section);
    });
    return section;
  }

  Future<void> reorder({
    required String listId,
    required List<String> orderedSectionIds,
  }) async {
    if (orderedSectionIds.toSet().length != orderedSectionIds.length) {
      throw ArgumentError.value(
        orderedSectionIds,
        'orderedSectionIds',
        '不能包含重复分组',
      );
    }
    await _db.transaction(() async {
      await _requireWritableList(listId);
      final sections = await (_db.select(
        _db.todoTaskSections,
      )..where((row) => row.listId.equals(listId))).get();
      if (sections.length != orderedSectionIds.length ||
          !sections.map((row) => row.id).toSet().containsAll(
            orderedSectionIds,
          )) {
        throw ArgumentError.value(
          orderedSectionIds,
          'orderedSectionIds',
          '必须包含清单内的全部分组',
        );
      }
      final byId = {for (final section in sections) section.id: section};
      final now = DateTime.now();
      for (final entry in orderedSectionIds.indexed) {
        final section = byId[entry.$2]!;
        await (_db.update(
          _db.todoTaskSections,
        )..where((row) => row.id.equals(section.id))).write(
          TodoTaskSectionsCompanion(
            sortOrder: Value(entry.$1),
            updatedAt: Value(now),
          ),
        );
        await _enqueueUpsert(
          section.copyWith(sortOrder: entry.$1, updatedAt: now),
        );
      }
    });
  }

  /// 删除分组不会删除任务；所有任务原子回到“未分组”并进入 outbox。
  Future<void> delete(String sectionId) async {
    await _db.transaction(() async {
      final section = await _sectionOrThrow(sectionId);
      await _requireWritableList(section.listId);
      final tasks = await (_db.select(
        _db.todoTasks,
      )..where((task) => task.sectionId.equals(sectionId))).get();
      final now = DateTime.now();
      for (final task in tasks) {
        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(task.id))).write(
          TodoTasksCompanion(
            sectionId: const Value(null),
            updatedAt: Value(now),
          ),
        );
        final updated = task.copyWith(
          sectionId: const Value(null),
          updatedAt: now,
        );
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: updated.id,
          serverId: updated.serverId,
          payload: _taskPayload(updated),
        );
      }
      await (_db.delete(
        _db.todoTaskSections,
      )..where((row) => row.id.equals(sectionId))).go();
      await _queue.enqueue(
        entity: SyncEntities.taskSection,
        op: SyncOps.delete,
        localId: sectionId,
        serverId: section.serverId,
        payload: section.toJson(),
      );
    });
  }

  Future<TodoTaskSection> _sectionOrThrow(String sectionId) async {
    final section = await (_db.select(
      _db.todoTaskSections,
    )..where((row) => row.id.equals(sectionId))).getSingleOrNull();
    if (section == null) throw StateError('分组不存在');
    return section;
  }

  Future<void> _requireWritableList(String listId) async {
    final list = await _db.listByLocalId(listId);
    if (list == null) throw StateError('清单不存在');
    if (!list.writable) throw StateError('当前清单为只读');
  }

  Future<void> _enqueueUpsert(TodoTaskSection section) {
    return _queue.enqueue(
      entity: SyncEntities.taskSection,
      op: SyncOps.upsert,
      localId: section.id,
      serverId: section.serverId,
      payload: section.toJson(),
    );
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
    payload.remove('assigneeUserName');
    return payload;
  }
}
