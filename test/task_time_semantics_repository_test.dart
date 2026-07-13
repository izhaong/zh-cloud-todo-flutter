import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('rejects an end time that is not after the start time', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.create(
        listId: 'inbox',
        title: '无效时段',
        startAt: DateTime(2026, 7, 13, 10),
        endAt: DateTime(2026, 7, 13, 10),
      ),
      throwsArgumentError,
    );
  });
}
