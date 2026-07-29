import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
