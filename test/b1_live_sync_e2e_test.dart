import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_dispatch_action_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_inbox_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B1_LIVE');
const _b2Enabled = bool.fromEnvironment('TODO_B2_LIVE');
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

  test(
    'B2 live sync restores a real revision conflict before a new edit replays',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinatorA = _coordinator(
        dbA,
        _client(sessionA.accessToken),
        'b2-live-conflict-device-a',
      );
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-live-conflict-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final tasksB = TaskRepository(dbB, SyncChangeQueue(dbB));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 conflict live $suffix');
      String? taskId;
      var stage = 'push list';

      try {
        expect(await coordinatorA.push(), 1);
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 conflict origin $suffix',
        );
        taskId = task.id;
        stage = 'push task';
        expect(await coordinatorA.push(), 1);
        final taskA = await tasksA.getById(task.id);
        expect(taskA?.serverId, isPositive);

        stage = 'pull stale task on device B';
        await coordinatorB.pull();
        final taskB = await dbB.taskByServerId(taskA!.serverId!);
        expect(taskB, isNotNull);

        stage = 'commit newer title on device A';
        await tasksA.update(task.id, title: 'B2 conflict server $suffix');
        expect(await coordinatorA.push(), 1);

        stage = 'push stale title from device B';
        await tasksB.update(taskB!.id, title: 'B2 conflict stale $suffix');
        expect(await coordinatorB.push(), 0);
        final restoredB = await tasksB.getById(taskB.id);
        expect(restoredB?.title, 'B2 conflict server $suffix');
        final failed = await (dbB.select(dbB.todoSyncChanges)
              ..where((row) => row.status.equals('failed')))
            .get();
        expect(failed, hasLength(1));

        stage = 'replay a new edit from restored revision';
        await tasksB.update(taskB.id, title: 'B2 conflict recovered $suffix');
        expect(await coordinatorB.push(), 1);
        await coordinatorA.pull();
        final convergedA = await dbA.taskByServerId(taskA.serverId!);
        expect(convergedA?.title, 'B2 conflict recovered $suffix');
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('B2 live conflict recovery failed at stage: $stage; $error'),
          stackTrace,
        );
      } finally {
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'B2 live sync preserves time, persistent reminder and ON_COMPLETE linkage',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(dbA, apiA, 'b2-live-device-a');
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final remindersA = ReminderRepository(dbA, SyncChangeQueue(dbA));
      final repeatsA = RepeatRuleRepository(dbA, SyncChangeQueue(dbA));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final startAt = DateTime.now().toUtc().add(const Duration(days: 2));
      final endAt = startAt.add(const Duration(hours: 2));
      final list = await listsA.create(name: 'B2 live sync $suffix');
      String? taskId;
      String? generatedTaskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        stage = 'read synced list';
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 ON_COMPLETE $suffix',
          startAt: startAt,
          endAt: endAt,
          dueAt: endAt,
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        taskId = task.id;
        stage = 'push task';
        await coordinatorA.push();
        stage = 'read synced task';
        final syncedTask = await dbA.taskByServerId(
          (await tasksA.getById(task.id))!.serverId!,
        );
        expect(syncedTask?.serverId, isPositive);

        final reminder = await remindersA.create(
          taskId: task.id,
          fireAt: startAt.subtract(const Duration(hours: 1)),
          persistent: true,
          intervalMinutes: 30,
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        final rule = await repeatsA.save(
          taskId: task.id,
          frequency: 'DAILY',
          startAt: startAt,
          repeatMode: 'ON_COMPLETE',
          timeZone: 'Asia/Shanghai',
        );
        stage = 'push reminder and repeat rule';
        await coordinatorA.push();
        stage = 'read synced reminder and repeat rule';
        final syncedReminder = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(reminder.id))).getSingle();
        final syncedRule = await (dbA.select(
          dbA.todoRepeatRules,
        )..where((row) => row.id.equals(rule.id))).getSingle();
        expect(syncedReminder.serverId, isPositive);
        expect(syncedRule.serverId, isPositive);

        await tasksA.toggleComplete(task.id);
        stage = 'push completion';
        await coordinatorA.push();
        stage = 'pull second device';
        await coordinatorB.pull();

        stage = 'read second-device parent task';
        final parentB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(parentB, isNotNull);
        final parent = parentB!;
        stage = 'read second-device repeat rule';
        final ruleB =
            await (dbB.select(dbB.todoRepeatRules)
                  ..where((row) => row.serverId.equals(syncedRule.serverId!)))
                .getSingle();
        stage = 'read second-device persistent reminder';
        final reminderB =
            await (dbB.select(dbB.todoReminders)..where(
                  (row) => row.serverId.equals(syncedReminder.serverId!),
                ))
                .getSingle();
        stage = 'read second-device ON_COMPLETE instance';
        final generated =
            await (dbB.select(dbB.todoTasks)
                  ..where((row) => row.repeatParentTaskId.equals(parent.id)))
                .getSingle();

        expect(parent.completedAt, isNotNull);
        expect(parent.timeZone, 'Asia/Shanghai');
        expect(parent.fixedTimezone, isTrue);
        expect(reminderB.persistent, isTrue);
        expect(reminderB.intervalMinutes, 30);
        expect(generated.repeatRuleId, ruleB.id);
        expect(generated.repeatOccurrenceAt, isNotNull);

        // A materialized ON_COMPLETE occurrence is a real server task.  Its
        // skip/catchup commands must still be addressed to the template rule
        // and template task, then converge through the normal outbox on both
        // devices.
        stage = 'pull materialized instance on first device';
        await coordinatorA.pull();
        final generatedA = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.repeatParentTaskId.equals(task.id))).getSingle();
        final occurrenceAt = generatedA.repeatOccurrenceAt;
        expect(occurrenceAt, isNotNull);

        stage = 'queue skip for materialized instance';
        await repeatsA.skip(
          repeatRuleId: rule.id,
          taskId: task.id,
          occurrenceAt: occurrenceAt!,
        );
        stage = 'push materialized-instance skip';
        await coordinatorA.push();
        stage = 'pull materialized-instance tombstone on both devices';
        await coordinatorA.pull();
        await coordinatorB.pull();
        expect(await dbA.taskByServerId(generatedA.serverId!), isNull);
        expect(await dbB.taskByServerId(generated.serverId!), isNull);

        stage = 'queue catchup for materialized instance';
        await repeatsA.catchup(
          repeatRuleId: rule.id,
          taskId: task.id,
          occurrenceAt: occurrenceAt,
        );
        stage = 'push materialized-instance catchup';
        await coordinatorA.push();
        stage = 'pull caught-up instance on both devices';
        await coordinatorA.pull();
        await coordinatorB.pull();
        final restoredA = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.repeatParentTaskId.equals(task.id))).getSingle();
        final restoredB =
            await (dbB.select(dbB.todoTasks)
                  ..where((row) => row.repeatParentTaskId.equals(parent.id)))
                .getSingle();
        generatedTaskId = restoredA.id;
        expect(restoredA.serverId, isPositive);
        expect(restoredA.serverId, isNot(generatedA.serverId));
        expect(restoredA.repeatOccurrenceAt, occurrenceAt);
        expect(restoredB.serverId, restoredA.serverId);
        expect(restoredB.repeatOccurrenceAt, occurrenceAt);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('B2 live sync failed at stage: $stage; $error'),
          stackTrace,
        );
      } finally {
        if (generatedTaskId != null) {
          await tasksA.delete(generatedTaskId);
          await coordinatorA.push();
        }
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
  );

  test(
    'B2 live reminder dispatch syncs multi-reminder snooze with retry',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(dbA, apiA, 'b2-reminder-live-device-a');
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-reminder-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final remindersA = ReminderRepository(dbA, SyncChangeQueue(dbA));
      final actionsA = ReminderDispatchActionRepository(SyncChangeQueue(dbA));
      final inboxA = ReminderInboxRepository(TodoRestApi(apiA).reminder);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 dispatch live $suffix');
      String? taskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 dispatch $suffix',
        );
        taskId = task.id;
        await coordinatorA.push();
        final syncedTask = await tasksA.getById(task.id);
        expect(syncedTask?.serverId, isPositive);

        // 同一任务写入一条已经到期、可由服务端 Job 派发的提醒和一条未来提醒。
        final dueReminder = await remindersA.create(
          taskId: task.id,
          fireAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        final laterReminder = await remindersA.create(
          taskId: task.id,
          fireAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        stage = 'push two reminder rules';
        await coordinatorA.push();
        final syncedDue = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(dueReminder.id))).getSingle();
        final syncedLater = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(laterReminder.id))).getSingle();
        expect(syncedDue.serverId, isPositive);
        expect(syncedLater.serverId, isPositive);

        stage = 'pull two reminder rules on second device';
        await coordinatorB.pull();
        final taskB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(taskB, isNotNull);
        final remindersB = await (dbB.select(
          dbB.todoReminders,
        )..where((row) => row.taskId.equals(taskB!.id))).get();
        expect(remindersB, hasLength(2));

        stage = 'wait for due reminder dispatch';
        final dispatch = await _waitForReminderDispatch(
          inboxA,
          syncedDue.serverId!,
        );
        expect(dispatch.reminderId, syncedDue.serverId);

        stage = 'queue snooze action';
        final mutationId = await actionsA.snooze(
          reminderDispatchId: dispatch.id,
          minutes: 10,
        );
        // 在已持久化 outbox 的第一次 push 注入短暂连接失败；第二次仍必须以原
        // mutation 回放到真实 Service，不会把动作旁路为直连 REST。
        var rejected = false;
        apiA.raw.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (!rejected && options.path.endsWith('/todo/sync/push')) {
                rejected = true;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
                return;
              }
              handler.next(options);
            },
          ),
        );
        stage = 'push transient snooze failure';
        expect(await coordinatorA.push(), 0);
        final retryable = await (dbA.select(
          dbA.todoSyncChanges,
        )..where((row) => row.clientMutationId.equals(mutationId))).getSingle();
        expect(retryable.status, 'retryable');
        expect(retryable.attemptCount, 1);

        stage = 'replay snooze action';
        expect(await coordinatorA.push(), 1);
        final syncedAction = await (dbA.select(
          dbA.todoSyncChanges,
        )..where((row) => row.clientMutationId.equals(mutationId))).getSingle();
        expect(syncedAction.status, 'synced');
        stage = 'confirm snoozed dispatch leaves inbox';
        await _waitForReminderDispatchRemoval(inboxA, dispatch.id);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'B2 reminder dispatch live sync failed at stage: $stage; $error',
          ),
          stackTrace,
        );
      } finally {
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
  );

  test(
    'B2 live sync materializes a new ON_DUE rule immediately on both devices',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(dbA, apiA, 'b2-ondue-live-device-a');
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-ondue-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final repeatsA = RepeatRuleRepository(dbA, SyncChangeQueue(dbA));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 ON_DUE live $suffix');
      String? taskId;
      String? generatedTaskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 ON_DUE $suffix',
          dueAt: DateTime.now().toUtc(),
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        taskId = task.id;
        stage = 'push template task';
        await coordinatorA.push();
        final syncedTask = await tasksA.getById(task.id);
        expect(syncedTask?.serverId, isPositive);

        final rule = await repeatsA.save(
          taskId: task.id,
          frequency: 'DAILY',
          startAt: DateTime.now().toUtc(),
          countLimit: 1,
          repeatMode: 'ON_DUE',
          timeZone: 'Asia/Shanghai',
        );
        stage = 'push ON_DUE rule with immediate materialization';
        await coordinatorA.push();
        stage = 'pull materialized instance on first device';
        await coordinatorA.pull();
        final generatedA = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.repeatParentTaskId.equals(task.id))).getSingle();
        generatedTaskId = generatedA.id;
        expect(generatedA.serverId, isPositive);
        expect(generatedA.repeatRuleId, rule.id);
        expect(generatedA.repeatOccurrenceAt, isNotNull);

        stage = 'pull materialized instance on second device';
        await coordinatorB.pull();
        final parentB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(parentB, isNotNull);
        final generatedB =
            await (dbB.select(dbB.todoTasks)
                  ..where((row) => row.repeatParentTaskId.equals(parentB!.id)))
                .getSingle();
        expect(generatedB.serverId, generatedA.serverId);
        expect(generatedB.repeatOccurrenceAt, generatedA.repeatOccurrenceAt);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('B2 ON_DUE live sync failed at stage: $stage; $error'),
          stackTrace,
        );
      } finally {
        if (generatedTaskId != null) {
          await tasksA.delete(generatedTaskId);
          await coordinatorA.push();
        }
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
  );

  test(
    'B2 live sync materializes every remaining ON_DUE frequency on both devices',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final now = DateTime.now().toUtc();
      final definitions = <String, Map<String, Object?>>{
        'WEEKLY': {
          'weekdays': [now.weekday],
        },
        'MONTHLY': {'monthDay': now.day},
        'YEARLY': const {},
        'WEEKDAY': const {},
        'CUSTOM': {
          'weekdays': [now.weekday],
        },
      };
      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinatorA = _coordinator(
        dbA,
        _client(sessionA.accessToken),
        'b2-frequency-live-device-a',
      );
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-frequency-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final repeatsA = RepeatRuleRepository(dbA, SyncChangeQueue(dbA));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 frequency live $suffix');
      final taskIds = <String, String>{};
      final generatedTaskIds = <String>[];
      final ruleIds = <String, String>{};
      var stage = 'push list';

      try {
        await coordinatorA.push();
        for (final frequency in definitions.keys) {
          final task = await tasksA.create(
            listId: list.id,
            title: 'B2 $frequency $suffix',
            dueAt: now,
            timeZone: 'Asia/Shanghai',
            fixedTimezone: true,
          );
          taskIds[frequency] = task.id;
        }
        stage = 'push frequency templates';
        await coordinatorA.push();

        for (final entry in definitions.entries) {
          final rule = await repeatsA.save(
            taskId: taskIds[entry.key]!,
            frequency: entry.key,
            weekdays: entry.value['weekdays'] as List<int>?,
            monthDay: entry.value['monthDay'] as int?,
            startAt: now,
            countLimit: 1,
            repeatMode: 'ON_DUE',
            timeZone: 'Asia/Shanghai',
          );
          ruleIds[entry.key] = rule.id;
        }
        stage = 'push remaining ON_DUE rules';
        await coordinatorA.push();
        stage = 'pull generated frequencies on both devices';
        await coordinatorA.pull();
        await coordinatorB.pull();

        for (final frequency in definitions.keys) {
          final templateA = await tasksA.getById(taskIds[frequency]!);
          expect(templateA?.serverId, isPositive, reason: frequency);
          final generatedA =
              await (dbA.select(dbA.todoTasks)..where(
                    (row) => row.repeatParentTaskId.equals(taskIds[frequency]!),
                  ))
                  .getSingle();
          final parentB = await dbB.taskByServerId(templateA!.serverId!);
          expect(parentB, isNotNull, reason: frequency);
          final generatedB =
              await (dbB.select(
                    dbB.todoTasks,
                  )..where((row) => row.repeatParentTaskId.equals(parentB!.id)))
                  .getSingle();
          generatedTaskIds.add(generatedA.id);
          expect(generatedA.serverId, isPositive, reason: frequency);
          expect(
            generatedA.repeatRuleId,
            ruleIds[frequency],
            reason: frequency,
          );
          expect(generatedA.repeatOccurrenceAt, isNotNull, reason: frequency);
          expect(generatedB.serverId, generatedA.serverId, reason: frequency);
          expect(
            generatedB.repeatOccurrenceAt,
            generatedA.repeatOccurrenceAt,
            reason: frequency,
          );
        }
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('B2 frequency live sync failed at stage: $stage; $error'),
          stackTrace,
        );
      } finally {
        for (final generatedTaskId in generatedTaskIds) {
          await tasksA.delete(generatedTaskId);
        }
        if (generatedTaskIds.isNotEmpty) {
          await coordinatorA.push();
        }
        for (final taskId in taskIds.values) {
          await tasksA.delete(taskId);
        }
        if (taskIds.isNotEmpty) {
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
  );

  test(
    'B2 live END reminder syncs the end anchor and dispatches it',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(
        dbA,
        apiA,
        'b2-end-reminder-live-device-a',
      );
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-end-reminder-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final remindersA = ReminderRepository(dbA, SyncChangeQueue(dbA));
      final inboxA = ReminderInboxRepository(TodoRestApi(apiA).reminder);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final endAt = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      final startAt = endAt.subtract(const Duration(hours: 1));
      final list = await listsA.create(name: 'B2 END reminder live $suffix');
      String? taskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 END reminder $suffix',
          startAt: startAt,
          endAt: endAt,
          dueAt: endAt,
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        taskId = task.id;
        stage = 'push dated task';
        await coordinatorA.push();
        final syncedTask = await tasksA.getById(task.id);
        expect(syncedTask?.serverId, isPositive);

        // END 的 fireAt 由客户端按截止时刻与 offset 展开后经 outbox 提交；
        // 同时保留 anchor 元数据供跨端编辑与服务端契约使用。
        final reminder = await remindersA.create(
          taskId: task.id,
          fireAt: endAt,
          anchorType: 'END',
          offsetMinutes: 0,
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        stage = 'push END reminder';
        await coordinatorA.push();
        final syncedReminder = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(reminder.id))).getSingle();
        expect(syncedReminder.serverId, isPositive);
        expect(syncedReminder.anchorType, 'END');
        expect(syncedReminder.offsetMinutes, 0);
        expect(
          syncedReminder.remindAt.toUtc().difference(endAt).abs(),
          lessThan(const Duration(seconds: 1)),
        );

        stage = 'pull END reminder on second device';
        await coordinatorB.pull();
        final taskB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(taskB, isNotNull);
        final reminderB =
            await (dbB.select(dbB.todoReminders)..where(
                  (row) => row.serverId.equals(syncedReminder.serverId!),
                ))
                .getSingle();
        expect(reminderB.taskId, taskB!.id);
        expect(reminderB.anchorType, 'END');
        expect(reminderB.offsetMinutes, 0);
        expect(
          reminderB.remindAt.toUtc().difference(endAt).abs(),
          lessThan(const Duration(seconds: 1)),
        );

        stage = 'wait for END reminder dispatch';
        final dispatch = await _waitForReminderDispatch(
          inboxA,
          syncedReminder.serverId!,
        );
        expect(dispatch.reminderId, syncedReminder.serverId);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'B2 END reminder live sync failed at stage: $stage; $error',
          ),
          stackTrace,
        );
      } finally {
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'B2 live reminder completion replays through outbox and syncs the task',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(
        dbA,
        apiA,
        'b2-reminder-complete-live-device-a',
      );
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-reminder-complete-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final remindersA = ReminderRepository(dbA, SyncChangeQueue(dbA));
      final actionsA = ReminderDispatchActionRepository(SyncChangeQueue(dbA));
      final inboxA = ReminderInboxRepository(TodoRestApi(apiA).reminder);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 complete reminder live $suffix');
      String? taskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 complete reminder $suffix',
        );
        taskId = task.id;
        stage = 'push task';
        await coordinatorA.push();
        final syncedTask = await tasksA.getById(task.id);
        expect(syncedTask?.serverId, isPositive);

        final reminder = await remindersA.create(
          taskId: task.id,
          fireAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        stage = 'push due reminder';
        await coordinatorA.push();
        final syncedReminder = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(reminder.id))).getSingle();
        expect(syncedReminder.serverId, isPositive);

        stage = 'pull task on second device';
        await coordinatorB.pull();
        final taskB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(taskB, isNotNull);
        expect(taskB!.completedAt, isNull);

        stage = 'wait for reminder dispatch';
        final dispatch = await _waitForReminderDispatch(
          inboxA,
          syncedReminder.serverId!,
        );
        final mutationId = await actionsA.complete(
          reminderDispatchId: dispatch.id,
        );
        stage = 'push completion action';
        expect(await coordinatorA.push(), 1);
        final action = await (dbA.select(
          dbA.todoSyncChanges,
        )..where((row) => row.clientMutationId.equals(mutationId))).getSingle();
        expect(action.status, 'synced');

        stage = 'confirm completed dispatch leaves inbox';
        await _waitForReminderDispatchRemoval(inboxA, dispatch.id);
        stage = 'pull completed task on second device';
        await coordinatorB.pull();
        final completedTaskB = await dbB.taskByServerId(syncedTask.serverId!);
        expect(completedTaskB?.completedAt, isNotNull);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'B2 reminder completion live sync failed at stage: $stage; $error',
          ),
          stackTrace,
        );
      } finally {
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'B2 live persistent reminder redispatches after its configured interval',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final coordinatorA = _coordinator(
        dbA,
        apiA,
        'b2-persistent-reminder-live-device-a',
      );
      final coordinatorB = _coordinator(
        dbB,
        _client(sessionB.accessToken),
        'b2-persistent-reminder-live-device-b',
      );
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final remindersA = ReminderRepository(dbA, SyncChangeQueue(dbA));
      final inboxA = ReminderInboxRepository(TodoRestApi(apiA).reminder);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B2 persistent live $suffix');
      String? taskId;
      var stage = 'push list';

      try {
        await coordinatorA.push();
        final syncedList = await dbA.listByLocalId(list.id);
        expect(syncedList?.serverId, isPositive);

        final task = await tasksA.create(
          listId: list.id,
          title: 'B2 persistent redispatch $suffix',
        );
        taskId = task.id;
        stage = 'push task';
        await coordinatorA.push();
        final syncedTask = await tasksA.getById(task.id);
        expect(syncedTask?.serverId, isPositive);

        // 该提醒已到期；一分钟间隔可在服务端 30 秒扫描周期内观察到首次和
        // 第二次 IN_APP dispatch，而无需客户端直连或人工触发 Job。
        final reminder = await remindersA.create(
          taskId: task.id,
          fireAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
          persistent: true,
          intervalMinutes: 1,
          timeZone: 'Asia/Shanghai',
          fixedTimezone: true,
        );
        stage = 'push persistent reminder';
        await coordinatorA.push();
        final syncedReminder = await (dbA.select(
          dbA.todoReminders,
        )..where((row) => row.id.equals(reminder.id))).getSingle();
        expect(syncedReminder.serverId, isPositive);
        expect(syncedReminder.persistent, isTrue);
        expect(syncedReminder.intervalMinutes, 1);

        stage = 'pull reminder on second device';
        await coordinatorB.pull();
        final taskB = await dbB.taskByServerId(syncedTask!.serverId!);
        expect(taskB, isNotNull);
        final reminderB =
            await (dbB.select(dbB.todoReminders)..where(
                  (row) => row.serverId.equals(syncedReminder.serverId!),
                ))
                .getSingle();
        expect(reminderB.taskId, taskB!.id);
        expect(reminderB.persistent, isTrue);
        expect(reminderB.intervalMinutes, 1);

        stage = 'wait for two server dispatches';
        final dispatches = await _waitForReminderDispatches(
          inboxA,
          syncedReminder.serverId!,
          minimumCount: 2,
        );
        expect(dispatches.map((dispatch) => dispatch.id).toSet(), hasLength(2));
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'B2 persistent reminder live sync failed at stage: $stage; $error',
          ),
          stackTrace,
        );
      } finally {
        if (taskId != null) {
          await tasksA.delete(taskId);
          await coordinatorA.push();
        }
        await listsA.delete(list.id);
        await coordinatorA.push();
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _b2Enabled ? false : 'set --dart-define=TODO_B2_LIVE=true to run',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<ReminderInboxItem> _waitForReminderDispatch(
  ReminderInboxRepository inbox,
  int reminderId,
) async {
  for (var attempt = 0; attempt < 18; attempt++) {
    final match = (await inbox.list()).cast<ReminderInboxItem?>().firstWhere(
      (item) => item?.reminderId == reminderId,
      orElse: () => null,
    );
    if (match != null) return match;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  throw StateError('reminder dispatch was not available before timeout');
}

Future<void> _waitForReminderDispatchRemoval(
  ReminderInboxRepository inbox,
  int dispatchId,
) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    final remains = (await inbox.list()).any((item) => item.id == dispatchId);
    if (!remains) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('snoozed reminder dispatch remained in the inbox');
}

Future<List<ReminderInboxItem>> _waitForReminderDispatches(
  ReminderInboxRepository inbox,
  int reminderId, {
  required int minimumCount,
}) async {
  for (var attempt = 0; attempt < 42; attempt++) {
    final matches = (await inbox.list())
        .where((item) => item.reminderId == reminderId)
        .toList(growable: false);
    if (matches.length >= minimumCount) return matches;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  throw StateError(
    'persistent reminder did not produce $minimumCount dispatches before timeout',
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
