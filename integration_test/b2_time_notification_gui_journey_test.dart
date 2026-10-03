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
    'B2 GUI creates, dispatches and opens a reminder with repeat (desktop/mobile share the same assertions)',
    (tester) async {
      if (mobile.isEmpty || password.isEmpty) {
        fail('需要通过受保护的 dart-define 提供 B2 测试账号（手机号与密码）');
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
      // 两条诊断分别对应「手机号没进控制器」与「提交按钮被置灰（tap 打空且不报错）」，
      // 缺了它们，真机失败只剩一句「找不到主壳锚点」。
      final mobileField = tester.widget<TextFormField>(
        find.byKey(const Key('todo-auth-mobile-input')),
      );
      expect(
        mobileField.controller?.text,
        mobile,
        reason: '手机号没有写进输入框控制器：enterText 打到了别的字段',
      );
      expect(
        _submitEnabled(tester),
        isTrue,
        reason:
            '提交按钮 disabled ⇒ 登录页仍在忙（tap 打空且不报错）。'
            '屏上文案: ${_onScreenTexts()}',
      );
      await tester.tap(find.byKey(const Key('todo-auth-submit')));
      // 窄屏（手机）不渲染顶部快速添加条，只有右下角 FAB；宽屏相反。
      // 这条旅程要在 macOS 与 Android 上跑同一套判据，所以先量出当前是哪一种布局。
      final desktopQuickAdd = find.byKey(const Key('todo-quick-add-input'));
      final mobileAddEntry = find.byKey(const Key('todo-mobile-add'));
      // 真后端经隧道有冷启动延迟，这里给到 30 秒；桌面/移动两个锚点命中任一即算进主壳。
      await _pumpUntilAny(tester, [
        desktopQuickAdd,
        mobileAddEntry,
      ], attempts: 120);
      final usesMobileEntry = desktopQuickAdd.evaluate().isEmpty;

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeShell)),
      );
      final tasks = container.read(taskRepositoryProvider)!;
      final database = container.read(appDatabaseProvider)!;
      final coordinator = await _waitForCoordinator(tester, container);
      final taskTitle = 'B2 提醒验收 ${DateTime.now().microsecondsSinceEpoch}';
      String? taskId;

      try {
        if (usesMobileEntry) {
          await tester.tap(mobileAddEntry);
          await _pumpUntil(
            tester,
            find.byKey(const Key('todo-mobile-add-field')),
          );
          await tester.enterText(
            find.byKey(const Key('todo-mobile-add-field')),
            taskTitle,
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await _pumpUntilAbsent(
            tester,
            find.byKey(const Key('todo-mobile-add-field')),
          );
        } else {
          await tester.enterText(desktopQuickAdd, taskTitle);
          await tester.testTextInput.receiveAction(TextInputAction.done);
        }

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
          // 「在结束时提醒」按 endAt 落 fireAt：没有结束时间时它会当场弹
          // 「请先设置结束时间」并返回（task_detail_pane.dart 的 _addEndTimeReminder），
          // 所以这条旅程必须先有结束时间。
          endAt: DateTime.now().add(const Duration(minutes: 6)),
        );
        await tester.pumpAndSettle();

        final taskRow = find.ancestor(
          of: taskTitleInRow,
          matching: find.byType(TaskRow),
        );
        await tester.tap(
          find.descendant(of: taskRow, matching: find.byType(InkWell)).first,
        );
        // 移动端点任务行是推进详情页；红在这里就说明根本没进到带「截止时间」区块的那一层，
        // 光看「找不到锚点」分不清是导航没成还是布局换了，所以带上屏上文案。
        await _pumpUntilWithDump(
          tester,
          find.byKey(const Key('task-schedule-options')),
        );
        await tester.tap(find.byKey(const Key('task-schedule-options')));
        // 等弹层自己的标题，不要等列表里的按钮：schedule sheet 的内容是 ListView（懒构建），
        // 窄屏上「在结束时提醒」此刻还没被构建，而标题一定在。
        // 上一版直接取 Scrollable.last 去滚，结果在弹层落位前取到空树（Bad state: No element）。
        await _pumpUntilWithDump(tester, find.text('日期、提醒与重复'));
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

/// 与 _pumpUntil 同义，但超时会把屏上文案与模态/滚动层数量一起报出来。
Future<void> _pumpUntilWithDump(
  WidgetTester tester,
  Finder finder, {
  int attempts = 12,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure(
    '未在固定时间内找到 GUI 锚点: $finder\n'
    '屏上文案: ${_onScreenTexts()}\n'
    'ModalBarrier: ${find.byType(ModalBarrier).evaluate().length} '
    'Scrollable: ${find.byType(Scrollable).evaluate().length}',
  );
}

/// 登录页「空闲」判据：请求在途时 `_isBusy` 会把提交按钮置灰，tap 打空且不报错。

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('todo-auth-submit')))
        .onPressed !=
    null;

/// 布局分支用：宽屏与窄屏各有自己的任务入口，命中任意一个即算进主壳。
Future<void> _pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  int attempts = 40,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finders.any((finder) => finder.evaluate().isNotEmpty)) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  final onScreen = _onScreenTexts();
  throw TestFailure('未在固定时间内找到任一 GUI 锚点: $finders\n屏幕上现有文案: $onScreen');
}

/// 登录卡在中间态时，光看断言名字分不出「停在哪儿」，把屏上文案一起带出来。
String _onScreenTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .toSet()
    .take(30)
    .join(' | ');

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
