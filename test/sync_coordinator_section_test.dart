import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_section_repository.dart';

void main() {
  test('push 先发送清单与 Section 并把任务本地引用换成同批临时 ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final list = await ListRepository(db, queue).create(name: '工作');
    final section = await TaskSectionRepository(
      db,
      queue,
    ).create(listId: list.id, name: '本周');
    await TaskRepository(
      db,
      queue,
    ).create(listId: list.id, sectionId: section.id, title: '完成周报');
    final api = _SectionSyncApi();

    expect(
      await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).push(),
      3,
    );

    final batch = api.pushed.single;
    expect(batch.map((change) => change.entityType), [
      SyncEntities.list,
      SyncEntities.taskSection,
      SyncEntities.task,
    ]);
    final listChange = batch[0];
    final sectionChange = batch[1];
    final taskChange = batch[2];
    expect(sectionChange.payload!['listId'], listChange.entityId);
    expect(taskChange.payload!['listId'], listChange.entityId);
    expect(taskChange.payload!['sectionId'], sectionChange.entityId);
  });

  test('pull 即使任务先返回也先落清单与 Section 再恢复本地归组', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _SectionSyncApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.task,
              entityId: 300,
              operation: SyncOps.upsert,
              payload: {
                'listId': 100,
                'sectionId': 200,
                'title': '完成周报',
                'status': 'TODO',
              },
            ),
            SyncChangeDto(
              entityType: SyncEntities.taskSection,
              entityId: 200,
              operation: SyncOps.upsert,
              payload: {'listId': 100, 'name': '本周', 'sortOrder': 0},
            ),
            SyncChangeDto(
              entityType: SyncEntities.list,
              entityId: 100,
              operation: SyncOps.upsert,
              payload: {'name': '工作', 'sortOrder': 0},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: false,
        ),
      ],
    );

    await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).pull();

    final section = await db.taskSectionByServerId(200);
    final task = await db.taskByServerId(300);
    expect(section, isNotNull);
    expect(task, isNotNull);
    expect(task!.sectionId, section!.id);
  });

  test('pull 跨页时暂存先于父清单到达的 Section', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _SectionSyncApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.taskSection,
              entityId: 200,
              operation: SyncOps.upsert,
              payload: {'listId': 100, 'name': '本周', 'sortOrder': 0},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: true,
        ),
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.task,
              entityId: 300,
              operation: SyncOps.upsert,
              payload: {
                'listId': 100,
                'sectionId': 200,
                'title': '完成周报',
                'status': 'TODO',
              },
            ),
            SyncChangeDto(
              entityType: SyncEntities.list,
              entityId: 100,
              operation: SyncOps.upsert,
              payload: {'name': '工作', 'sortOrder': 0},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c2',
          hasMore: false,
        ),
      ],
    );

    await SyncCoordinator(
      db: db,
      api: api,
      todoApi: ApiClient(),
    ).pull(limit: 1);

    final section = await db.taskSectionByServerId(200);
    final task = await db.taskByServerId(300);
    expect(section, isNotNull);
    expect(task, isNotNull);
    expect(task!.sectionId, section!.id);
    expect((await db.readSyncCursor())?.cursor, 'c2');
  });

  test('pull 末页仍缺父清单时不推进游标以免永久丢失 Section', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.writeSyncCursor('c0');
    final api = _SectionSyncApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.taskSection,
              entityId: 200,
              operation: SyncOps.upsert,
              payload: {'listId': 100, 'name': '本周', 'sortOrder': 0},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: false,
        ),
      ],
    );

    await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).pull();

    expect(await db.taskSectionByServerId(200), isNull);
    expect((await db.readSyncCursor())?.cursor, 'c0');
  });

  test('Section tombstone 保留任务并回到未分组', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _SectionSyncApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.list,
              entityId: 100,
              operation: SyncOps.upsert,
              payload: {'name': '工作', 'sortOrder': 0},
            ),
            SyncChangeDto(
              entityType: SyncEntities.taskSection,
              entityId: 200,
              operation: SyncOps.upsert,
              payload: {'listId': 100, 'name': '本周', 'sortOrder': 0},
            ),
            SyncChangeDto(
              entityType: SyncEntities.task,
              entityId: 300,
              operation: SyncOps.upsert,
              payload: {
                'listId': 100,
                'sectionId': 200,
                'title': '完成周报',
                'status': 'TODO',
              },
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: false,
        ),
        SyncPullResult(
          changes: const [],
          tombstones: [
            SyncTombstoneDto(
              entityType: SyncEntities.taskSection,
              entityId: 200,
            ),
          ],
          nextCursor: 'c2',
          hasMore: false,
        ),
      ],
    );
    final coordinator = SyncCoordinator(db: db, api: api, todoApi: ApiClient());

    await coordinator.pull();
    await coordinator.pull();

    expect(await db.taskSectionByServerId(200), isNull);
    final task = await db.taskByServerId(300);
    expect(task, isNotNull);
    expect(task!.sectionId, isNull);
  });
}

class _SectionSyncApi extends SyncApi {
  _SectionSyncApi({List<SyncPullResult>? pulls})
    : _pulls = [...?pulls],
      super(ApiClient(), clientId: 'section-test', deviceId: 'section-test');

  final List<SyncPullResult> _pulls;
  final List<List<SyncChangeDto>> pushed = [];

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async {
    pushed.add(changes);
    return SyncPushResult(
      ok: true,
      accepted: [
        for (final change in changes)
          SyncChangeDto(
            entityType: change.entityType,
            entityId: switch (change.entityType) {
              SyncEntities.list => 100,
              SyncEntities.taskSection => 200,
              SyncEntities.task => 300,
              _ => 999,
            },
            operation: change.operation,
            clientMutationId: change.clientMutationId,
          ),
      ],
      conflicts: const [],
      nextCursor: null,
    );
  }

  @override
  Future<SyncPullResult> pull({
    String? cursor,
    int limit = 200,
    List<String>? entityTypes,
  }) async {
    if (_pulls.isEmpty) {
      return SyncPullResult(
        changes: const [],
        tombstones: const [],
        nextCursor: cursor,
        hasMore: false,
      );
    }
    return _pulls.removeAt(0);
  }
}
