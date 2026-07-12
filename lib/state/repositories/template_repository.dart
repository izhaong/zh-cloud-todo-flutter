import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
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
  TemplateRepository(this._db, this._queue, {ApiClient? api, Uuid? uuid})
    : _api = api,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final ApiClient? _api;
  final Uuid _uuid;

  Stream<List<TodoTemplate>> watchAll() {
    return (_db.select(
      _db.todoTemplates,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();
  }

  /// 拉取当前账号模板并写入 Drift。远端缺失项不在这里删除，避免离线队列中的
  /// 本地模板被错误清理；删除语义由后续模板删除用例单独处理。
  Future<int> refreshMy() async {
    final api = _api;
    if (api == null) throw StateError('TemplateRepository requires ApiClient');
    final response = await api.get<dynamic>('/template/list-my');
    final envelope = response.data;
    final rawItems = envelope is Map<String, dynamic>
        ? envelope['data']
        : envelope;
    if (rawItems is! List) return 0;
    var refreshed = 0;
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final serverId = (item['id'] as num?)?.toInt();
      final name = item['name']?.toString().trim();
      final content = item['content']?.toString();
      if (serverId == null || name == null || name.isEmpty || content == null) {
        continue;
      }
      final existing = await (_db.select(
        _db.todoTemplates,
      )..where((row) => row.serverId.equals(serverId))).getSingleOrNull();
      final now = DateTime.now();
      await _db
          .into(_db.todoTemplates)
          .insertOnConflictUpdate(
            TodoTemplatesCompanion.insert(
              id: existing?.id ?? _uuid.v4(),
              serverId: Value(serverId),
              name: name,
              contentJson: content,
              status: const Value('synced'),
              updatedAt: now,
              createdAt: existing?.createdAt ?? now,
            ),
          );
      refreshed++;
    }
    return refreshed;
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
