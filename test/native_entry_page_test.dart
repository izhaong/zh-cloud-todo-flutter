import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(projection.lockScreenServerIds, [101, 102]);
    expect(projection.unsyncedImportantCount, 1);
    expect(projection.shareText, contains('提交工作报告'));
    expect(projection.shareText, isNot(contains('明天的重要任务')));
    expect(projection.stickyNoteText, contains('确认行程'));
  });

  test('平台未注册原生通道时安全返回不支持', () async {
    expect(await NativeIntents.handleIncomingUri(), isNull);
    expect(await NativeIntents.shareText('今日任务'), isFalse);
    expect(await NativeIntents.setStickyNote('今日重点'), isFalse);
    expect(await NativeIntents.pushLockScreenTasks([101]), isFalse);
    expect(await NativeIntents.widgetTodaySnapshot(), isEmpty);
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

  testWidgets('原生增强页把真实服务端任务 ID 推送到平台通道', (tester) async {
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
      'ids': [201],
    });
  });

  testWidgets('设置页提供可达的原生增强入口', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsRoute())),
    );

    expect(find.text('原生增强'), findsOneWidget);
    await tester.tap(find.text('原生增强'));
    await tester.pumpAndSettle();

    expect(find.byType(NativeEntryPage), findsOneWidget);
  });
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
    timeZone: timeZone,
    updatedAt: now,
    createdAt: now,
  );
}
