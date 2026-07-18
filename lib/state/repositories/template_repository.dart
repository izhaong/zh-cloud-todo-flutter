import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

class TemplateTaskSeed {
  const TemplateTaskSeed({
    required this.title,
    this.description,
    required this.priority,
  });

  final String title;
  final String? description;
  final int priority;
}

class TemplateRepository {
  TemplateRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Stream<List<TodoTemplate>> watchAll() {
    return (_db.select(
      _db.todoTemplates,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();
  }

  Future<TodoTemplate> saveTask({
    required TodoTask task,
    required String name,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError.value(name, 'name', '模板名称不能为空');
    final now = DateTime.now();
    final id = _uuid.v4();
    final content = jsonEncode({
      'title': task.title,
      'description': task.description,
      'priority': task.priority,
    });
    await _db.transaction(() async {
      await _db
          .into(_db.todoTemplates)
          .insert(
            TodoTemplatesCompanion.insert(
              id: id,
              name: normalized,
              contentJson: content,
              updatedAt: now,
              createdAt: now,
            ),
          );
      await _queue.enqueue(
        entity: SyncEntities.template,
        op: SyncOps.upsert,
        localId: id,
        payload: {'name': normalized, 'content': content},
      );
    });
    return (_db.select(
      _db.todoTemplates,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  /// 删除私有任务快照模板。已在服务端登记的模板保留一条 delete outbox，
  /// 未登记模板则和其尚未发送的 upsert 一起原子撤销，避免制造无效临时 ID。
  Future<void> delete(String templateId) async {
    await _db.transaction(() async {
      final template = await (_db.select(
        _db.todoTemplates,
      )..where((row) => row.id.equals(templateId))).getSingleOrNull();
      if (template == null) return;

      await (_db.delete(
        _db.todoTemplates,
      )..where((row) => row.id.equals(templateId))).go();
      if (template.serverId == null) {
        await (_db.delete(_db.todoSyncChanges)..where(
              (row) =>
                  row.entity.equals(SyncEntities.template) &
                  row.entityLocalId.equals(templateId),
            ))
            .go();
        return;
      }
      await _queue.enqueue(
        entity: SyncEntities.template,
        op: SyncOps.delete,
        localId: templateId,
        serverId: template.serverId,
        payload: const {},
      );
    });
  }

  TemplateTaskSeed taskSeed(TodoTemplate template) {
    final content = jsonDecode(template.contentJson) as Map<String, dynamic>;
    return TemplateTaskSeed(
      title: content['title']?.toString() ?? template.name,
      description: content['description']?.toString(),
      priority: (content['priority'] as num?)?.toInt() ?? 0,
    );
  }
}
