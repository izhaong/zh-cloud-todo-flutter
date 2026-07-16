import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/attachment_upload_api.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'attachment sync uploads, registers metadata, and marks the outbox synced',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedAttachment(db);
      final coordinator = _coordinator(db, _SuccessfulAttachmentUploadApi());

      final pushed = await coordinator.push();

      expect(pushed, 1);
      final attachment = await db.select(db.todoAttachments).getSingle();
      expect(attachment.status, 'uploaded');
      expect(attachment.serverId, 51);
      expect(attachment.remoteUrl, 'https://files.example/weekly-report.pdf');
      expect(
        (await db.select(db.todoSyncChanges).getSingle()).status,
        'synced',
      );
    },
  );

  test(
    'attachment sync failure marks only the attachment and its outbox failed',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedAttachment(db);
      final coordinator = _coordinator(db, _FailingAttachmentUploadApi());

      final pushed = await coordinator.push();

      expect(pushed, 0);
      expect(
        (await db.select(db.todoAttachments).getSingle()).status,
        'failed',
      );
      expect(
        (await db.select(db.todoSyncChanges).getSingle()).status,
        'failed',
      );
    },
  );

  test(
    'attachment delete mutation removes server metadata and marks outbox synced',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 7, 12);
      await db
          .into(db.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'attachment-delete-mutation',
              entity: 'attachment',
              op: 'delete',
              entityLocalId: const Value('attachment-local'),
              entityServerId: const Value(51),
              payloadJson: '{}',
              createdAt: now,
            ),
          );
      final api = _DeletingAttachmentUploadApi();
      final coordinator = _coordinator(db, api);

      final pushed = await coordinator.push();

      expect(pushed, 1);
      expect(api.deletedServerId, 51);
      expect(
        (await db.select(db.todoSyncChanges).getSingle()).status,
        'synced',
      );
    },
  );

  test(
    'attachment retry after an offline failure registers metadata once',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedAttachment(db);
      final api = _RecoveringAttachmentUploadApi();
      final coordinator = _coordinator(db, api);
      final repository = TaskRepository(db, SyncChangeQueue(db));

      expect(await coordinator.push(), 0);
      expect(
        (await db.select(db.todoAttachments).getSingle()).status,
        'failed',
      );

      await repository.retryAttachment('attachment-local');
      expect(await coordinator.push(), 1);
      expect(await coordinator.push(), 0);

      expect(api.uploadAttempts, 2);
      expect(api.registerAttempts, 1);
      final attachment = await db.select(db.todoAttachments).getSingle();
      expect(attachment.status, 'uploaded');
      expect(attachment.serverId, 61);
    },
  );

  test(
    'new task uploads its queued attachment in the same recovery push',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 7, 13);
      await db.into(db.todoLists).insert(
        TodoListsCompanion.insert(
          id: 'list-local',
          serverId: const Value(10),
          name: '工作',
          updatedAt: now,
          createdAt: now,
        ),
      );
      await db.into(db.todoTasks).insert(
        TodoTasksCompanion.insert(
          id: 'task-new',
          listId: 'list-local',
          title: '带附件的新任务',
          updatedAt: now,
          createdAt: now,
        ),
      );
      await db.into(db.todoAttachments).insert(
        TodoAttachmentsCompanion.insert(
          id: 'attachment-new',
          taskId: 'task-new',
          name: 'brief.txt',
          localPath: const Value('/tmp/brief.txt'),
          mimeType: 'text/plain',
          size: 12,
          updatedAt: now,
          createdAt: now,
        ),
      );
      await db.into(db.todoSyncChanges).insert(
        TodoSyncChangesCompanion.insert(
          clientMutationId: 'task-new-mutation',
          entity: 'task',
          op: 'upsert',
          entityLocalId: const Value('task-new'),
          payloadJson: '{"listId":"list-local","title":"带附件的新任务"}',
          createdAt: now,
        ),
      );
      await db.into(db.todoSyncChanges).insert(
        TodoSyncChangesCompanion.insert(
          clientMutationId: 'attachment-new-mutation',
          entity: 'attachment',
          op: 'upsert',
          entityLocalId: const Value('attachment-new'),
          payloadJson: '{}',
          createdAt: now.add(const Duration(milliseconds: 1)),
        ),
      );
      final attachmentApi = _CapturingAttachmentUploadApi();
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(_syncClient(), clientId: 'test', deviceId: 'test'),
        todoApi: _syncClient(),
        attachmentApi: attachmentApi,
      );

      expect(await coordinator.push(), 2);

      expect(attachmentApi.registeredTaskServerId, 20);
      final attachment = await db.select(db.todoAttachments).getSingle();
      expect(attachment.status, 'uploaded');
      expect(attachment.serverId, 52);
      expect(
        (await db.select(db.todoSyncChanges).get()).map((change) => change.status),
        everyElement('synced'),
      );
    },
  );
}

Future<void> _seedAttachment(AppDatabase db) async {
  final now = DateTime(2026, 7, 12);
  await db
      .into(db.todoTasks)
      .insert(
        TodoTasksCompanion.insert(
          id: 'task-local',
          serverId: const Value(10),
          listId: 'inbox',
          title: '撰写周报',
          updatedAt: now,
          createdAt: now,
        ),
      );
  await db
      .into(db.todoAttachments)
      .insert(
        TodoAttachmentsCompanion.insert(
          id: 'attachment-local',
          taskId: 'task-local',
          name: 'weekly-report.pdf',
          localPath: const Value('/tmp/weekly-report.pdf'),
          mimeType: 'application/pdf',
          size: 1024,
          updatedAt: now,
          createdAt: now,
        ),
      );
  await db
      .into(db.todoSyncChanges)
      .insert(
        TodoSyncChangesCompanion.insert(
          clientMutationId: 'attachment-mutation',
          entity: 'attachment',
          op: 'upsert',
          entityLocalId: const Value('attachment-local'),
          payloadJson: '{}',
          createdAt: now,
        ),
      );
}

SyncCoordinator _coordinator(
  AppDatabase db,
  AttachmentUploadApi attachmentApi,
) {
  final client = ApiClient();
  return SyncCoordinator(
    db: db,
    api: SyncApi(client, clientId: 'test', deviceId: 'test'),
    todoApi: client,
    attachmentApi: attachmentApi,
  );
}

ApiClient _syncClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final changes = ((options.data as Map?)?['changes'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'code': 0,
              'data': {
                'ok': true,
                'accepted': changes
                    .map(
                      (change) => {
                        'entityType': change['entityType'],
                        'entityId': 20,
                        'operation': 'upsert',
                        'clientMutationId': change['clientMutationId'],
                      },
                    )
                    .toList(),
                'conflicts': <Map<String, dynamic>>[],
              },
            },
          ),
        );
      },
    ),
  );
  return ApiClient(dio: dio);
}

class _SuccessfulAttachmentUploadApi implements AttachmentUploadApi {
  @override
  Future<void> deleteTaskAttachment({required int serverId}) =>
      throw StateError('not reached');

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) async => 51;

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) async => 'https://files.example/weekly-report.pdf';
}

class _CapturingAttachmentUploadApi implements AttachmentUploadApi {
  int? registeredTaskServerId;

  @override
  Future<void> deleteTaskAttachment({required int serverId}) =>
      throw StateError('not reached');

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) async {
    registeredTaskServerId = taskServerId;
    return 52;
  }

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) async => 'https://files.example/brief.txt';
}

class _FailingAttachmentUploadApi implements AttachmentUploadApi {
  @override
  Future<void> deleteTaskAttachment({required int serverId}) =>
      throw StateError('not reached');

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) => throw StateError('not reached');

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) => throw StateError('network unreachable');
}

class _DeletingAttachmentUploadApi implements AttachmentUploadApi {
  int? deletedServerId;

  @override
  Future<void> deleteTaskAttachment({required int serverId}) async {
    deletedServerId = serverId;
  }

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) => throw StateError('not reached');

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) => throw StateError('not reached');
}

class _RecoveringAttachmentUploadApi implements AttachmentUploadApi {
  var uploadAttempts = 0;
  var registerAttempts = 0;

  @override
  Future<void> deleteTaskAttachment({required int serverId}) =>
      throw StateError('not reached');

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) async {
    registerAttempts++;
    return 61;
  }

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) async {
    uploadAttempts++;
    if (uploadAttempts == 1) throw StateError('network unreachable');
    return 'https://files.example/weekly-report.pdf';
  }
}
