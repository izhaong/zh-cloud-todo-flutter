import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';
import 'package:zh_cloud_todo_flutter/main.dart' as app;
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const definedMobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
  const definedPassword = String.fromEnvironment('TODO_B1_E2E_PASSWORD');
  final mobile = definedMobile.isNotEmpty
      ? definedMobile
      : Platform.environment['TODO_B1_E2E_MOBILE'] ?? '';
  final password = definedPassword.isNotEmpty
      ? definedPassword
      : Platform.environment['TODO_B1_E2E_PASSWORD'] ?? '';

  testWidgets(
    'B2 macOS GUI creates, dispatches and opens a reminder with repeat',
    (tester) async {
      if (mobile.isEmpty || password.isEmpty) {
        fail('需要通过受保护的 dart-define 提供 B2 测试账号');
      }

      app.main();
      await _pumpUntil(tester, find.byKey(const Key('todo-auth-mobile-input')));
      await tester.enterText(
        find.byKey(const Key('todo-auth-mobile-input')),
        mobile,
      );
      await tester.enterText(
        find.byKey(const Key('todo-auth-password-input')),
        password,
      );
      await tester.tap(find.byKey(const Key('todo-auth-submit')));
      await _pumpUntil(tester, find.byKey(const Key('todo-quick-add-input')));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeShell)),
      );
      final tasks = container.read(taskRepositoryProvider)!;
      final database = container.read(appDatabaseProvider)!;
      final coordinator = await _waitForCoordinator(tester, container);
      final taskTitle =
          'B2 macOS 提醒验收 ${DateTime.now().microsecondsSinceEpoch}';
      String? taskId;

      try {
        await tester.enterText(
          find.byKey(const Key('todo-quick-add-input')),
          taskTitle,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);

        final taskTitleInRow = find.descendant(
          of: find.byType(TaskRow),
          matching: find.text(taskTitle),
        );
        await _pumpUntil(tester, taskTitleInRow);
        final created = (await tasks.watchAll().first).singleWhere(
          (task) => task.title == taskTitle,
        );
        taskId = created.id;
        await tasks.update(
          taskId,
          dueAt: DateTime.now().subtract(const Duration(minutes: 2)),
        );
        await tester.pumpAndSettle();

        final taskRow = find.ancestor(
          of: taskTitleInRow,
          matching: find.byType(TaskRow),
        );
        await tester.tap(
          find.descendant(of: taskRow, matching: find.byType(InkWell)).first,
        );
        await _pumpUntil(
          tester,
          find.byKey(const Key('task-schedule-options')),
        );
        await tester.tap(find.byKey(const Key('task-schedule-options')));
        await _pumpUntil(
          tester,
          find.byKey(const Key('task-add-end-reminder')),
        );

        final scheduleScroll = find.byType(Scrollable).last;
        final addReminder = find.byKey(const Key('task-add-end-reminder'));
        await tester.scrollUntilVisible(
          addReminder,
          160,
          scrollable: scheduleScroll,
        );
        await tester.drag(scheduleScroll, const Offset(0, -100));
        await tester.pumpAndSettle();
        await tester.tap(addReminder);
        await tester.pumpAndSettle();
        final remindersAfterTap = await database
            .select(database.todoReminders)
            .get();
        expect(
          remindersAfterTap.any(
            (entry) => entry.taskId == taskId && entry.anchorType == 'END',
          ),
          isTrue,
        );

        final repeatRule = find.byKey(const Key('task-repeat-rule'));
        await tester.scrollUntilVisible(
          repeatRule,
          160,
          scrollable: scheduleScroll,
        );
        await tester.drag(scheduleScroll, const Offset(0, -100));
        await tester.pumpAndSettle();
        await tester.tap(repeatRule);
        await _pumpUntil(
          tester,
          find.byKey(const Key('task-repeat-frequency-weekly')),
        );
        await tester.tap(find.byKey(const Key('task-repeat-frequency-weekly')));
        await tester.tap(find.byKey(const Key('task-repeat-save')));
        await _pumpUntilAbsent(
          tester,
          find.byKey(const Key('task-repeat-save')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('task-schedule-close')));
        await tester.pumpAndSettle();
        _closeOpenEndDrawer(tester);
        await tester.pumpAndSettle();

        final taskOutboxBeforeSync =
            (await database.select(database.todoSyncChanges).get())
                .where((entry) => entry.entityLocalId == taskId)
                .toList();
        final firstSync = await coordinator.syncOnce();
        var syncedTask = await tasks.getById(taskId);
        if (syncedTask?.serverId == null) {
          await coordinator.syncOnce();
          syncedTask = await tasks.getById(taskId);
        }
        expect(
          syncedTask?.serverId,
          isNotNull,
          reason:
              '任务 outbox=${taskOutboxBeforeSync.map((entry) => entry.status).toList()}，'
              '首轮同步推送 ${firstSync.pushed} 项后未回写 task serverId',
        );

        final reminders = await database.select(database.todoReminders).get();
        final reminder = reminders.singleWhere(
          (entry) => entry.taskId == taskId,
        );
        expect(reminder.serverId, isNotNull);
        expect(reminder.anchorType, 'END');

        final repeatRules = await database
            .select(database.todoRepeatRules)
            .get();
        final repeat = repeatRules.singleWhere(
          (entry) => entry.taskId == taskId,
        );
        expect(repeat.serverId, isNotNull);
        expect(repeat.freq, 'WEEKLY');

        final dispatch = await tester.runAsync(() async {
          for (var attempt = 0; attempt < 45; attempt++) {
            final inbox = await container
                .read(reminderInboxRepositoryProvider)
                .list();
            for (final item in inbox) {
              if (item.taskId == syncedTask!.serverId && item.pending) {
                return item;
              }
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          return null;
        });
        expect(dispatch, isNotNull, reason: '服务端未在 90 秒内生成到期提醒派发');

        final shown = await container
            .read(reminderNotificationPollerProvider)!
            .poll();
        expect(shown, greaterThanOrEqualTo(1));

        for (final messenger in tester.stateList<ScaffoldMessengerState>(
          find.byType(ScaffoldMessenger),
        )) {
          messenger.clearSnackBars();
        }
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        await tester.tap(
          find.byKey(const Key('todo-reminder-inbox-action')).first,
        );
        await _pumpUntil(tester, find.text('提醒收件箱'));
        await _pumpUntil(tester, find.text(taskTitle));
        expect(find.text(taskTitle), findsWidgets);
      } finally {
        if (taskId != null) {
          await tasks.delete(taskId);
          await coordinator.syncOnce();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<SyncCoordinator> _waitForCoordinator(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container.read(deviceIdProvider.future);
  container.invalidate(syncCoordinatorProvider);
  for (var attempt = 0; attempt < 40; attempt++) {
    final coordinator = container.read(syncCoordinatorProvider);
    if (coordinator != null) return coordinator;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure('同步协调器未在固定时间内就绪');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure('未在固定时间内找到 GUI 锚点: $finder');
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finder.evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure('GUI 锚点未在固定时间内消失: $finder');
}

void _closeOpenEndDrawer(WidgetTester tester) {
  for (final state in tester.stateList<ScaffoldState>(find.byType(Scaffold))) {
    if (state.isEndDrawerOpen) state.closeEndDrawer();
  }
}
