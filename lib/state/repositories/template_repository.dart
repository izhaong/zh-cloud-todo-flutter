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
        payload: {'name': normalized, 'content': content, 'templateType': 1},
      );
    });
    return (_db.select(
      _db.todoTemplates,
    )..where((row) => row.id.equals(id))).getSingle();
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
