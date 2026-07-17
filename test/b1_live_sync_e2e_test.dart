import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B1_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test(
    'B1 live sync maps a clean Drift aggregate and propagates tombstones',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      // 两个独立 NativeDatabase.memory 实例刻意模拟两个设备。
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final coordinatorA = _coordinator(dbA, apiA, 'b1-live-device-a');
      final coordinatorB = _coordinator(dbB, apiB, 'b1-live-device-b');
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final defaultsA = TaskCaptureDefaultsRepository(
        dbA,
        SyncChangeQueue(dbA),
      );
      final templatesA = TemplateRepository(dbA, SyncChangeQueue(dbA));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B1 live sync $suffix');
      String? taskLocalId;
      String? templateLocalId;
      int? attachmentServerId;
      File? attachmentFile;

      try {
        // 默认清单跨端引用的是服务端 list ID；先提交清单，避免把设备 A 的
        // 本地 UUID 带到设备 B。
        await coordinatorA.push();
        final syncedListA = await dbA.listByLocalId(list.id);
        expect(syncedListA?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B1 live sync task $suffix',
          description: '## Markdown\n\n来自设备 A 的正文。',
          priority: 2,
        );
        taskLocalId = task.id;
        final checklist = await tasksA.createChecklistItem(
          taskId: task.id,
          title: '在设备 B 回显检查事项',
        );
        await defaultsA.save(
          TaskCaptureDefaults(defaultListId: list.id, defaultPriority: 2),
        );
        await coordinatorA.push();

        final syncedTaskByLocalId = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.id.equals(task.id))).getSingle();
        final syncedChecklistA = await (dbA.select(
          dbA.todoChecklistItems,
        )..where((row) => row.id.equals(checklist.id))).getSingle();
        expect(syncedTaskByLocalId.serverId, isPositive);
        expect(syncedChecklistA.serverId, isPositive);
        expect(await _pendingOrFailedCount(dbA), 0);

        attachmentFile = File(
          '${Directory.systemTemp.path}/todo-b1-live-$suffix.txt',
        );
        await attachmentFile.writeAsString('B1 attachment $suffix');
        final attachment = await tasksA.queueAttachment(
          taskId: task.id,
          name: 'todo-b1-live-$suffix.txt',
          localPath: attachmentFile.path,
          mimeType: 'text/plain',
          size: await attachmentFile.length(),
        );
        await coordinatorA.push();
        final syncedAttachmentA = await (dbA.select(
          dbA.todoAttachments,
        )..where((row) => row.id.equals(attachment.id))).getSingle();
        expect(syncedAttachmentA.serverId, isPositive);
        expect(syncedAttachmentA.status, 'uploaded');
        expect(syncedAttachmentA.remoteUrl, isNotEmpty);
        attachmentServerId = syncedAttachmentA.serverId;
        expect(await _pendingOrFailedCount(dbA), 0);

        final template = await templatesA.saveTask(
          task: syncedTaskByLocalId,
          name: 'B1 private template $suffix',
        );
        templateLocalId = template.id;
        await coordinatorA.push();
        final syncedTemplateA = await (dbA.select(
          dbA.todoTemplates,
        )..where((row) => row.id.equals(template.id))).getSingle();
        expect(syncedTemplateA.serverId, isPositive);
        expect(syncedTemplateA.status, 'synced');
        expect(await _pendingOrFailedCount(dbA), 0);

        await coordinatorB.pull();

        final taskB = await dbB.taskByServerId(syncedTaskByLocalId.serverId!);
        expect(taskB, isNotNull);
        expect(taskB!.id, isNot(task.id));
        expect(taskB.description, '## Markdown\n\n来自设备 A 的正文。');
        final listB = await dbB.listByServerId(syncedListA!.serverId!);
        expect(listB, isNotNull);
        expect(listB!.id, isNot(list.id));
        final defaultsB = TaskCaptureDefaultsRepository(
          dbB,
          SyncChangeQueue(dbB),
        );
        final syncedDefaultsB = await defaultsB.get();
        expect(syncedDefaultsB.defaultPriority, 2);
        expect(syncedDefaultsB.defaultListId, listB.id);
        final checklistB =
            await (dbB.select(dbB.todoChecklistItems)..where(
                  (row) => row.serverId.equals(syncedChecklistA.serverId!),
                ))
                .getSingle();
        expect(checklistB.taskId, taskB.id);
        expect(checklistB.title, '在设备 B 回显检查事项');
        final attachmentB =
            await (dbB.select(dbB.todoAttachments)..where(
                  (row) => row.serverId.equals(syncedAttachmentA.serverId!),
                ))
                .getSingle();
        expect(attachmentB.taskId, taskB.id);
        expect(attachmentB.name, syncedAttachmentA.name);
        expect(attachmentB.remoteUrl, syncedAttachmentA.remoteUrl);
        expect(attachmentB.localPath, isNull);
        expect(attachmentB.status, 'uploaded');

        final templateB =
            await (dbB.select(dbB.todoTemplates)..where(
                  (row) => row.serverId.equals(syncedTemplateA.serverId!),
                ))
                .getSingle();
        expect(templateB.id, isNot(syncedTemplateA.id));
        expect(templateB.name, 'B1 private template $suffix');
        expect(templateB.contentJson, syncedTemplateA.contentJson);
        expect(templateB.status, 'synced');

        final activitiesBeforeRepeatPull =
            await (dbB.select(dbB.todoActivities)..where(
                  (row) =>
                      row.taskServerId.equals(syncedTaskByLocalId.serverId!),
                ))
                .get();
        expect(activitiesBeforeRepeatPull, isNotEmpty);
        expect(
          activitiesBeforeRepeatPull.map((activity) => activity.action),
          contains('task_created'),
        );
        expect(
          (await dbB.select(dbB.todoSyncChanges).get()).where(
            (change) => change.entity == 'activity',
          ),
          isEmpty,
        );
        final activityServerIds = activitiesBeforeRepeatPull
            .map((activity) => activity.serverId)
            .toSet();
        await coordinatorB.pull();
        final activitiesAfterRepeatPull =
            await (dbB.select(dbB.todoActivities)..where(
                  (row) =>
                      row.taskServerId.equals(syncedTaskByLocalId.serverId!),
                ))
                .get();
        expect(
          activitiesAfterRepeatPull,
          hasLength(activitiesBeforeRepeatPull.length),
        );
        expect(
          activitiesAfterRepeatPull
              .map((activity) => activity.serverId)
              .toSet(),
          activityServerIds,
        );

        await templatesA.delete(template.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(
          await (dbB.select(
                dbB.todoTemplates,
              )..where((row) => row.serverId.equals(syncedTemplateA.serverId!)))
              .getSingleOrNull(),
          isNull,
        );
        templateLocalId = null;

        await tasksA.deleteChecklistItem(checklist.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(
          await (dbB.select(dbB.todoChecklistItems)..where(
                (row) => row.serverId.equals(syncedChecklistA.serverId!),
              ))
              .getSingleOrNull(),
          isNull,
        );

        await tasksA.deleteAttachment(syncedAttachmentA.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(
          await (dbB.select(dbB.todoAttachments)..where(
                (row) => row.serverId.equals(syncedAttachmentA.serverId!),
              ))
              .getSingleOrNull(),
          isNull,
        );
        attachmentServerId = null;

        await tasksA.delete(task.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(await dbB.taskByServerId(syncedTaskByLocalId.serverId!), isNull);
      } finally {
        if (attachmentServerId != null) {
          await _deleteAttachmentIfPresent(apiA, attachmentServerId);
        }
        if (templateLocalId != null) {
          await templatesA.delete(templateLocalId);
          await coordinatorA.push();
        }
        if (taskLocalId != null) {
          await _deleteIfPresent(
            apiA,
            '/app-api/todo/task/delete',
            taskLocalId,
            dbA,
          );
        }
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', list.id, dbA);
        if (attachmentFile != null && await attachmentFile.exists()) {
          await attachmentFile.delete();
        }
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _enabled ? false : 'set --dart-define=TODO_B1_LIVE=true to run',
  );
}

Future<void> _deleteAttachmentIfPresent(ApiClient client, int serverId) async {
  try {
    final response = await client.raw.delete<Map<String, dynamic>>(
      '/app-api/todo/attachment/delete?id=$serverId',
    );
    final body = response.data;
    if (body?['code'] != 0) {
      throw StateError(body?['msg']?.toString() ?? 'attachment cleanup failed');
    }
  } on DioException catch (error) {
    if (error.response?.statusCode != 404) rethrow;
  }
}

Future<TodoAuthSession> _login() => AuthGatewayImpl(
  _client(''),
  tenantId: _tenantId,
).passwordLogin(mobile: _mobile, password: _password);

ApiClient _client(String token) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: _baseUrl)),
  tokenProvider: () => token,
  tenantIdProvider: () => _tenantId,
);

SyncCoordinator _coordinator(
  AppDatabase db,
  ApiClient client,
  String deviceId,
) => SyncCoordinator(
  db: db,
  api: SyncApi(client, clientId: deviceId, deviceId: deviceId),
  todoApi: client,
);

Future<int> _pendingOrFailedCount(AppDatabase db) async {
  final changes = await db.select(db.todoSyncChanges).get();
  return changes
      .where((change) => change.status == 'queued' || change.status == 'failed')
      .length;
}

Future<void> _deleteIfPresent(
  ApiClient client,
  String path,
  String localId,
  AppDatabase db,
) async {
  final serverId = path.contains('/task/')
      ? (await (db.select(
          db.todoTasks,
        )..where((row) => row.id.equals(localId))).getSingleOrNull())?.serverId
      : (await db.listByLocalId(localId))?.serverId;
  if (serverId == null) return;
  await client.raw.delete<Map<String, dynamic>>('$path?id=$serverId');
}
