import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/activity_repository.dart';

void main() {
  test(
    'activity refresh persists server records for offline reading',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ActivityRepository(
        db,
        _FakeActivityApi([
          TaskActivityRecord(
            id: 9,
            taskId: 10,
            action: 'task_updated',
            actorUserName: 'Alice',
            occurredAt: DateTime(2026, 7, 12, 9),
          ),
        ]),
      );

      await repository.refreshTask(10);

      final activities = await repository.watchTask(10).first;
      expect(activities, hasLength(1));
      expect(activities.single.action, 'task_updated');
      expect(activities.single.actorUserName, 'Alice');
    },
  );
}

class _FakeActivityApi extends ActivityApi {
  _FakeActivityApi(this.records) : super(ApiClient());

  final List<TaskActivityRecord> records;

  @override
  Future<List<TaskActivityRecord>> listTask(int taskServerId) async => records;
}
