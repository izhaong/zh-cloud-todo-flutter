import 'dart:async';
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
        await _scrollToTaskRow(tester, taskTitleInRow);
        // 夹具体量大时这一句会红。用带屏上文案与 ModalBarrier 计数的等待，才能分清
        // 「行没进构建窗口」「根本没进这个列表」「快速添加被静默挡回」三种情况。
        await _pumpUntilWithDump(tester, taskTitleInRow, attempts: 60);
        final created = (await tasks.watchAll().first).singleWhere(
          (task) => task.title == taskTitle,
        );
        taskId = created.id;
        await tasks.update(
          taskId,
          dueAt: DateTime.now().subtract(const Duration(minutes: 2)),
          // 「在结束时提醒」按 endAt 落 fireAt：没有结束时间时它当场弹「请先设置结束时间」并返回
          // （_addEndTimeReminder）。偏移要落在下面 90 秒轮询窗口之内 ——
          // 服务端只在 fireAt 到点时才生成派发，给到 +6 分钟会让这条判据永远等不到。
          endAt: DateTime.now().add(const Duration(seconds: 45)),
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
        // 宽屏的收件箱入口在工作区顶部（rail 上），窄屏（mobile/tablet）把整块侧栏放进
        // Scaffold 的 start drawer，同一个 rowKey 只有抽屉打开时才在树上 ——
        // 直接 tap 会打在空 finder 上（实测 Bad state: No element）。
        final inboxAction = find.byKey(const Key('todo-reminder-inbox-action'));
        if (inboxAction.evaluate().isEmpty) {
          // 此时窄屏的任务详情还压在上面（ModalBarrier>=1），抽屉被 modal 挡住点不到；
          // 先按系统 pop 收回 shell —— 与 b1 用 handlePopRoute 而非 pageBack 同一理由
          // （pageBack 只认英文 'Back'，中文界面下打不中）。
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          for (final scaffold in tester.stateList<ScaffoldState>(
            find.byType(Scaffold),
          )) {
            scaffold.openDrawer();
          }
          await tester.pumpAndSettle();
          await _pumpUntilWithDump(tester, inboxAction, attempts: 24);
        }
        await tester.tap(inboxAction.first);
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
    // 真后端 + 模拟器：4 分钟在 macOS 干净账号上是 00:56 过，在 iOS 模拟器上会撞上预算而不是撞上断言
    // （实测 04:00 TimeoutException 且没有任何定位信息）。判据不变，只抬墙钟预算。
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<SyncCoordinator> _waitForCoordinator(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // 这一句原本是无界 await：设备号取不到时旅程既不报错也不结束，连用例自己声明的
  // 4 分钟 Timeout 都不会触发（实测跑到 10:02 仍无 TestFailure），三端排查时只能靠猜。
  try {
    await container
        .read(deviceIdProvider.future)
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw TestFailure(
      '设备号未在 30 秒内就绪（多为会话存储走到了真实钥匙串：'
      '跑集成测试需要同时带 FLUTTER_TEST 与 TODO_E2E_DEVICE_ID 两个 dart-define）；'
      '屏幕上现有文案: ${_onScreenTexts()}',
    );
  }
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

/// 任务列表是懒构建的 ListView.builder：无截止时间的新建任务落在「无日期」分组
/// （六组里的第五组），fixture 任务一多，那一行根本没进构建窗口，
/// 直接 find 只会得到「Found 0 widgets」，分不清是功能坏了还是没滚到。
/// 滚动定位同时把该行留在视口里，后面的 tap 才打得中。
Future<void> _scrollToTaskRow(WidgetTester tester, Finder rowTitle) async {
  if (rowTitle.evaluate().isNotEmpty) return;
  final rows = find.byType(TaskRow);
  if (rows.evaluate().isEmpty) return;
  // 不靠命名 Scrollable：scrollUntilVisible 要求 scrollable: 恰好命中一个，而实测这里
  // 既不在 todo-task-list-scroll 之下、也可能套着行内的横向滚动。改为在所有 Scrollable
  // 里取「可滚动范围最大」的那个——几百行的任务列表远大于任何行内滑动容器。
  ScrollPosition? position;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (position == null || state.position.maxScrollExtent > position.maxScrollExtent) {
      position = state.position;
    }
  }
  if (position == null) return;
  for (var step = 0; step < 400 && rowTitle.evaluate().isEmpty; step++) {
    final next = (position.pixels + 400).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump(const Duration(milliseconds: 50));
  }
}
