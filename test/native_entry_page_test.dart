import 'package:flutter/material.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/native/native_entry_page.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/native/native_intents.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('原生任务投影只使用真实今日和重要任务且不伪造服务端 ID', () {
    final projection = NativeTaskProjection.fromTasks([
      _task(
        id: 'today-high',
        serverId: 101,
        title: '提交工作报告',
        dueAt: DateTime(2026, 7, 30, 18),
        priority: 3,
      ),
      _task(
        id: 'today-pinned-local',
        title: '确认行程',
        dueAt: DateTime(2026, 7, 30, 12),
        isPinned: true,
      ),
      _task(
        id: 'tomorrow-high',
        serverId: 102,
        title: '明天的重要任务',
        dueAt: DateTime(2026, 7, 31, 9),
        priority: 3,
      ),
      _task(
        id: 'completed',
        serverId: 103,
        title: '已经完成',
        dueAt: DateTime(2026, 7, 30, 10),
        priority: 3,
        completed: true,
      ),
    ], now: DateTime(2026, 7, 30, 9));

    expect(projection.todayTasks.map((task) => task.id), [
      'today-pinned-local',
      'today-high',
    ]);
    expect(projection.importantTasks.map((task) => task.id), [
      'today-high',
      'tomorrow-high',
      'today-pinned-local',
    ]);
    expect(projection.lockScreenTasks, const [
      NativeLockScreenTask(serverId: 101, title: '提交工作报告'),
      NativeLockScreenTask(serverId: 102, title: '明天的重要任务'),
    ]);
    expect(projection.unsyncedImportantCount, 1);
    expect(projection.shareText, contains('提交工作报告'));
    expect(projection.shareText, isNot(contains('明天的重要任务')));
    expect(projection.stickyNoteText, contains('确认行程'));
  });

  test('平台未注册原生通道时安全返回不支持', () async {
    expect(await NativeIntents.handleIncomingUri(), isNull);
    expect(await NativeIntents.shareText('今日任务'), isFalse);
    expect(await NativeIntents.setStickyNote('今日重点'), isFalse);
    expect(await NativeIntents.setKeepScreenAwake(true), isFalse);
    expect(
      await NativeIntents.pushLockScreenTasks(const [
        NativeLockScreenTask(serverId: 101, title: '今日重点'),
      ]),
      isFalse,
    );
    expect(await NativeIntents.widgetTodaySnapshot(), isEmpty);
    expect(await NativeIntents.updateTodayWidgetSnapshot(['今日任务']), isFalse);
  });

  test('常亮请求交给 wakelock_plus', () async {
    final fake = _RecordingWakelock();
    final previous = wakelockPlusPlatformInstance;
    wakelockPlusPlatformInstance = fake;
    addTearDown(() => wakelockPlusPlatformInstance = previous);

    expect(await NativeIntents.setKeepScreenAwake(true), isTrue);
    expect(await NativeIntents.setKeepScreenAwake(false), isTrue);
    expect(fake.calls, [true, false]);
  });

  test('常亮请求在平台异常时安全降级', () async {
    final fake = _RecordingWakelock()..throwOnToggle = true;
    final previous = wakelockPlusPlatformInstance;
    wakelockPlusPlatformInstance = fake;
    addTearDown(() => wakelockPlusPlatformInstance = previous);

    expect(await NativeIntents.setKeepScreenAwake(true), isFalse);
    expect(fake.calls, isEmpty);
  });

  test('锁屏快照只把显式空列表用于清除且拒绝无效任务', () async {
    const channel = MethodChannel('zh_cloud_todo/native');
    final received = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    expect(await NativeIntents.pushLockScreenTasks(const []), isTrue);
    expect(received.single.arguments, {'tasks': <Object>[]});

    expect(
      await NativeIntents.pushLockScreenTasks(const [
        NativeLockScreenTask(serverId: 0, title: '无效任务'),
      ]),
      isFalse,
    );
    expect(received, hasLength(1));
  });

  test('今日投影按任务固定时区的墙上日期归组', () {
    final projection = NativeTaskProjection.fromTasks([
      _task(
        id: 'los-angeles-evening',
        title: '洛杉矶晚间任务',
        dueAt: DateTime.utc(2026, 7, 31, 2),
        fixedTimezone: true,
        timeZone: 'America/Los_Angeles',
      ),
    ], now: DateTime(2026, 7, 30, 9));

    expect(projection.todayTasks.single.id, 'los-angeles-evening');
  });

  testWidgets('原生增强页把真实服务端任务快照推送到平台通道', (tester) async {
    const channel = MethodChannel('zh_cloud_todo/native');
    MethodCall? received;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      received = call;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final tasks = [
      _task(
        id: 'today-high',
        serverId: 201,
        title: '真实锁屏任务',
        dueAt: DateTime(2026, 7, 30, 18),
        priority: 3,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 7, 30, 9),
          ),
        ],
        child: MaterialApp(
          home: NativeEntryPage(taskStream: Stream.value(tasks)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('演示'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '推送 1 项重要任务'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '推送 1 项重要任务'));
    await tester.pumpAndSettle();

    expect(received?.method, 'pushLockScreenTasks');
    expect(received?.arguments, {
      'tasks': [
        {'id': 201, 'title': '真实锁屏任务'},
      ],
    });
  });

  testWidgets('原生增强页把真实今日任务快照更新到桌面小组件', (tester) async {
    const channel = MethodChannel('home_widget');
    final received = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      received.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final tasks = [
      _task(
        id: 'today-widget',
        title: '更新桌面小组件',
        dueAt: DateTime(2026, 7, 30, 18),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 7, 30, 9),
          ),
        ],
        child: MaterialApp(
          home: NativeEntryPage(taskStream: Stream.value(tasks)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '更新桌面小组件（1）'));
    await tester.pumpAndSettle();

    expect(received.map((call) => call.method), contains('saveWidgetData'));
    expect(
      received.singleWhere((call) => call.method == 'saveWidgetData').arguments,
      {'id': 'tasks', 'data': '["更新桌面小组件"]'},
    );
  });

  testWidgets('设置页提供可达的原生增强入口', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsRoute())),
    );

    expect(find.text('原生增强'), findsOneWidget);
    // 「账号」分组与「任务」分组各加过行之后，800x600 默认视口里这一行已经掉到
    // 折叠线以下；`ensureVisible` 在这条列表上不会真把它滚进来（实测中心还在
    // y=662，视口只有 600），所以改成看得见地滚。
    await tester.dragUntilVisible(
      find.text('原生增强'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('原生增强')).dy,
      lessThan(600),
      reason: '正对照：这一行真的进了视口，下面那一次 tap 才有意义',
    );
    await tester.tap(find.text('原生增强'));
    await tester.pumpAndSettle();

    expect(find.byType(NativeEntryPage), findsOneWidget);
  });
}

class _RecordingWakelock extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  var throwOnToggle = false;

  @override
  Future<void> toggle({required bool enable}) async {
    if (throwOnToggle) {
      throw PlatformException(code: 'unsupported');
    }
    calls.add(enable);
  }

  @override
  Future<bool> get enabled async => false;
}

TodoTask _task({
  required String id,
  required String title,
  int? serverId,
  DateTime? dueAt,
  int priority = 0,
  bool isPinned = false,
  bool completed = false,
  bool fixedTimezone = false,
  String? timeZone,
}) {
  final now = DateTime.utc(2026, 7, 30, 9);
  return TodoTask(
    id: id,
    serverId: serverId,
    listId: 'list-inbox',
    title: title,
    completed: completed,
    cancelled: false,
    priority: priority,
    isPinned: isPinned,
    sortOrder: 0,
    dueAt: dueAt,
    allDay: false,
    fixedTimezone: fixedTimezone,
    timeMode: TaskTimeMode.fromLegacyFlag(fixedTimezone).wire,
    timeZone: timeZone,
    updatedAt: now,
    createdAt: now,
  );
}
