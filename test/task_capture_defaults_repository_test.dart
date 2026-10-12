import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';

void main() {
  test(
    'capture defaults persist locally and enqueue a view preference mutation',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskCaptureDefaultsRepository(db, SyncChangeQueue(db));

      await repository.save(
        const TaskCaptureDefaults(
          defaultListId: 'personal',
          defaultPriority: 2,
        ),
      );

      expect(
        await repository.get(),
        const TaskCaptureDefaults(
          defaultListId: 'personal',
          defaultPriority: 2,
        ),
      );
      final row = await db.select(db.todoViewPreferences).getSingle();
      expect(row.sourceType, 'TASK_CAPTURE');
      expect(row.sourceKey, 'defaults');
      expect(jsonDecode(row.valueJson), {
        'defaultListId': 'personal',
        'defaultPriority': 2,
      });
      final change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.entity, 'view_preference');
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['valueJson'], row.valueJson);
    },
  );

  test(
    'capture defaults unwrap the server view-preference payload on pull',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskCaptureDefaultsRepository(db, SyncChangeQueue(db));
      final valueJson = jsonEncode({
        'defaultListId': 'inbox',
        'defaultPriority': 1,
      });
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'local-defaults',
              serverId: const drift.Value(81),
              sourceType: 'TASK_CAPTURE',
              sourceKey: 'defaults',
              valueJson: jsonEncode({'valueJson': valueJson}),
              updatedAt: DateTime(2026, 7, 12),
              createdAt: DateTime(2026, 7, 12),
            ),
          );

      expect(
        await repository.get(),
        const TaskCaptureDefaults(defaultListId: 'inbox', defaultPriority: 1),
      );
    },
  );
}
