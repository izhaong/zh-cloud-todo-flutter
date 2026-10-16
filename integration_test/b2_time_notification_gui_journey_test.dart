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

  /// 由 runner 显式传入；不带这个 define 时（macOS / web）系统通知断言照常生效。
  ///
  /// ## iOS 这一腿为什么在本机只能跳过（FL #519，含补法）
  ///
  /// 不是产品缺陷，是**本机自动化能力边界**：同一断言在 Android（`shown=2`）与
  /// macOS（`shown=6`）上都真的跑到了。两条路本机都实测走死：
  ///
  /// 1. `xcrun simctl privacy` 的 service 枚举里**没有 notifications**
  ///    （只有 all / calendar / contacts[-limited] / location[-always] / photos[-add] /
  ///    media-library / microphone / motion / reminders / siri）⇒ 命令行授权这条路不存在；
  /// 2. 弹窗也没有可点的界面：本机 `xcode-select -p` 指向的 Xcode 其 `Applications/` 为空、
  ///    `/Applications/Simulator.app` 不存在（`mdfind -name Simulator.app` 零命中），
  ///    System Events 里也没有 `Simulator` 进程 ⇒ 模拟器只能 headless 跑，弹窗无法呈现更无法点。
  ///
  /// **在装了 `Simulator.app` 的机器上这样收掉这一腿**（授权对 bundle id 是持久的）：
  ///
  /// ```bash
  /// # ① 起模拟器 UI
  /// open -a Simulator --args -CurrentDeviceUDID <UDID>
  /// # ② 让授权弹窗出现（带自己的 API 地址）
  /// flutter run -d <UDID> --dart-define=TODO_API_BASE_URL=http://127.0.0.1:15808
  /// # ③ 点「允许」（AppleScript 走 System Events 点 alert 按钮即可）
  /// # ④ 重跑本文件，判据有两条：
  /// #    那行 `system notification leg skipped` **不再出现**；且 `shown > 0`。
  /// #    若仍 `shown=0`，那才是真缺陷（提醒没派发）。
  /// ```
  ///
  /// 旅程侧不需要改代码：跳过这一腿时会打一行可见的 trace，不会出现「静默绿」。
  const skipSystemNotificationLeg = bool.fromEnvironment(
    'TODO_E2E_SKIP_SYSTEM_NOTIFICATION',
  );

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
      _trace('before coordinator');
      final coordinator = await _waitForCoordinator(tester, container);
      _trace('coordinator ready');
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

        // 顺序很关键：先在本地库确认真的落库（数据面为真），再回界面找那一行。
        // 反过来的话，脏夹具上会「滚完一整圈行才出现」，滚动白做，红在「Found 0 widgets
        // with text …」上看着像创建没生效。干净账号只有一行、滚不滚都在视口里，
        // 所以一直掩盖着这个顺序问题。
        var hits = (await tasks.watchAll().first)
            .where((task) => task.title == taskTitle)
            .toList();
        for (var attempt = 0; hits.isEmpty && attempt < 40; attempt++) {
          await tester.pump(const Duration(milliseconds: 250));
          hits = (await tasks.watchAll().first)
              .where((task) => task.title == taskTitle)
              .toList();
        }
        if (hits.isEmpty) {
          throw TestFailure('本地库里没有这条新建任务: $taskTitle（快速添加没落库）');
        }
        final created = hits.single;
        taskId = created.id;

        final taskTitleInRow = find.descendant(
          of: find.byType(TaskRow),
          matching: find.text(taskTitle),
        );
        await _scrollToTaskRow(tester, taskTitleInRow);
        // 屏上文案 + ModalBarrier + Scrollable 计数：这一步再红就能直接看出停在哪个面上。
        _trace('look for created row');
        await _pumpUntilWithDump(tester, taskTitleInRow, attempts: 60);
        _trace('created row on screen');
        await tasks.update(
          taskId,
          dueAt: DateTime.now().subtract(const Duration(minutes: 2)),
          // 「在结束时提醒」按 endAt 落 fireAt：没有结束时间时它当场弹「请先设置结束时间」并返回
          // （_addEndTimeReminder）。偏移要落在下面 90 秒轮询窗口之内 ——
          // 服务端只在 fireAt 到点时才生成派发，给到 +6 分钟会让这条判据永远等不到。
          endAt: DateTime.now().add(const Duration(seconds: 45)),
        );
        await tester.pumpAndSettle();

        // 找到过一次不等于还在屏上：推荐面板刷新会带着任务列表重建，滚动位置回到顶部，
        // 于是 find.ancestor 在「当前一个 TaskRow 都没命中」上抛 Bad state: No element。
        // 所以每次要碰这一行之前都先把它滚回视口（helper 已在视口内时是 no-op）。
        //
        // 但「出视口」和「不在这张列表里了」是两回事，修法完全不同（前者是旅程没滚到位，
        // 后者是改了截止时间之后任务的归属视图变了）。这条红在 macOS 与 Android 上都复现过，
        // 所以先把两者量开：红的文案要能指出是哪种，别再留一句 Bad state 让人猜。
        // 「当下不在树里」不等于「离开了这张列表」：任务列表是懒构建的，滚动位置回到
        // 顶部时这一行本来就没被 build。而 _scrollToTaskRow 内部是「按 400px 步进、
        // 跳满 400 次直到这一行被重新构建」的循环 —— 所以判归属之前必须先让它跑完。
        // 上一版把这条检查放在滚动之前，于是把正常的虚拟卸载当成「视图成员变了」，
        // 红在自家插桩上（文案还断言「不是滚动位置能解释的」，方向是反的）。
        final rowTotal = find.byType(TaskRow).evaluate().length;
        _trace(
          'after update TaskRow=$rowTotal '
          'titleHits=${taskTitleInRow.evaluate().length}',
        );
        await _scrollToTaskRow(tester, taskTitleInRow);
        if (taskTitleInRow.evaluate().isEmpty) {
          final stillThere = (await tasks.watchAll().first)
              .where((task) => task.id == taskId)
              .toList();
          final scrollables = <String>[];
          for (final element in find.byType(Scrollable).evaluate()) {
            final state = (element as StatefulElement).state as ScrollableState;
            scrollables.add(
              'max=${state.position.maxScrollExtent.toStringAsFixed(0)} '
              'px=${state.position.pixels.toStringAsFixed(0)}',
            );
          }
          throw TestFailure(
            '滚遍整张列表仍未构建出这一行（屏上 TaskRow=$rowTotal）。'
            '数据层归属：'
            '${stillThere.isEmpty ? '任务已不在 watchAll 结果里（不是卸载）' : 'listId=${stillThere.single.listId}'}；'
            'watchAll 共 ${(await tasks.watchAll().first).length} 条；'
            'Scrollable(${scrollables.length})=[${scrollables.join(" | ")}]',
          );
        }
        _trace(
          'after scrollTo titleHits=${taskTitleInRow.evaluate().length}',
        );
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

        _trace('await server dispatch');
        final wantTaskServerId = syncedTask!.serverId;
        final dispatch = await tester.runAsync(() async {
          // 这个循环以前既不报第几轮、也不报每次拿到几条、还把异常吞在 runAsync 里：
          // iOS 上一路挂到 8 分钟预算耗尽，读日志分不清是「请求不返回」「请求返回但空列表」
          // 还是「有派发但 taskId 对不上本地 serverId」。逐轮打点后就剩一种可能。
          for (var attempt = 0; attempt < 45; attempt++) {
            try {
              final inbox = await container
                  .read(reminderInboxRepositoryProvider)
                  .list();
              _trace(
                'inbox attempt=${attempt + 1} items=${inbox.length} '
                'wantTaskServerId=$wantTaskServerId',
              );
              for (final item in inbox) {
                if (item.taskId == syncedTask!.serverId && item.pending) {
                  return item;
                }
              }
            } on Object catch (error) {
              _trace('inbox attempt=${attempt + 1} ERROR $error');
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          return null;
        });
        expect(dispatch, isNotNull, reason: '服务端未在 90 秒内生成到期提醒派发');
        _trace('dispatch matched dispatchTaskId=${dispatch?.taskId}');

        // 空夹具上实测：派发在第 31 轮命中，之后就再无输出直到 8 分钟预算耗尽 ——
        // 卡点已经挪到 poller 或它之后的抽屉/收件箱 UI。先把 poll 变成有界并报数，
        // 下一轮就能一眼分出是「poll 不返回」还是「UI 锚点等不到」。
        final poller = container.read(reminderNotificationPollerProvider);
        _trace('before notification poll');
        final shown = poller == null
            ? null
            : await poller.poll().timeout(
                const Duration(seconds: 60),
                onTimeout: () => -1,
              );
        _trace('after notification poll shown=$shown');
        // 系统通知这一腿在 iOS 模拟器上不可判定：投递要等系统授权弹窗有人点「允许」，
        // 自动化跑到这里没人点，插件就是不返回（本 PR 已把它改成 10 秒上限 + 按未送达处理）。
        // 所以只有显式声明「本端不覆盖系统通知展示」时才跳过这一条断言，
        // 并继续走完应用内提醒收件箱那段（那才是本轮要验的用户可见路径）。
        if (!skipSystemNotificationLeg) {
          expect(shown, greaterThanOrEqualTo(1));
        } else {
          _trace(
            'system notification leg skipped（iOS 未授予通知权限），'
            '继续校验应用内提醒收件箱 shown=$shown',
          );
        }

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
          _trace('open reminder inbox');
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
  _trace('pumpUntil enter');
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
  _trace('pumpUntilWithDump enter');
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

/// 阶段流水：8 分钟裸 Timeout 不给出「停在第几步」，只给最后一行 STAGE 就能定位。
/// 上一轮 iOS 就是这么红的（04:00→08:00 预算耗尽，无任何 TestFailure）。
void _trace(String what) => debugPrint('B2-STAGE $what');

/// 布局分支用：宽屏与窄屏各有自己的任务入口，命中任意一个即算进主壳。
Future<void> _pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  int attempts = 40,
}) async {
  _trace('pumpUntilAny enter');
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
  _trace('pumpUntilAbsent enter');
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
    if (position == null ||
        state.position.maxScrollExtent > position.maxScrollExtent) {
      position = state.position;
    }
  }
  if (position == null) return;
  // 只能往前扫是这条 helper 的老缺陷：改完截止时间后列表按日期重排，那一行会跑到
  // 当前偏移**之上**，从当前位置向下扫到 max 就永远碰不到它（#510 偶发红的确切机制：
  // 红不红取决于行原来在哪、重排后去哪）。所以每次未命中都从顶部重新扫一遍整张列表。
  position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 50));
  for (var step = 0; step < 400 && rowTitle.evaluate().isEmpty; step++) {
    final next = (position.pixels + 400).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump(const Duration(milliseconds: 50));
  }
}
