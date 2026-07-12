import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

void main() {
  test(
    'saving a task template persists locally and enqueues registration',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final taskRepository = TaskRepository(db, queue);
      final templateRepository = TemplateRepository(db, queue);
      final task = await taskRepository.create(
        listId: 'inbox',
        title: '每周复盘',
        description: '总结本周',
        priority: 2,
      );

      final template = await templateRepository.saveTask(
        task: task,
        name: '周复盘模板',
      );

      expect(template.name, '周复盘模板');
      final seed = templateRepository.taskSeed(template);
      expect(seed.title, '每周复盘');
      expect(seed.priority, 2);
      expect(
        (await db.select(db.todoSyncChanges).get()).where(
          (change) => change.entity == 'template',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'refreshing remote templates caches new records and updates server IDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final client = _templateListClient([
        {
          'id': 41,
          'name': '跨端周报模板',
          'content': '{"title":"跨端周报","priority":3}',
        },
      ]);
      final repository = TemplateRepository(db, queue, api: client);

      expect(await repository.refreshMy(), 1);
      expect(await repository.refreshMy(), 1);

      final templates = await db.select(db.todoTemplates).get();
      expect(templates, hasLength(1));
      expect(templates.single.serverId, 41);
      expect(templates.single.status, 'synced');
      expect(repository.taskSeed(templates.single).title, '跨端周报');
      expect(await db.select(db.todoSyncChanges).get(), isEmpty);
    },
  );
}

ApiClient _templateListClient(List<Map<String, dynamic>> items) {
  final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: {'code': 0, 'data': items},
        ),
      ),
    ),
  );
  return ApiClient(dio: dio);
}
