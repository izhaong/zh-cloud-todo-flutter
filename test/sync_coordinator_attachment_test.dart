import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/attachment_upload_api.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

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
