import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  String? launchPayload;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    launchPayload = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' ||
              call.method == 'requestPermissions') {
            return true;
          }
          if (call.method == 'pendingNotificationRequests') {
            return [
              {
                'id': 11,
                'title': '当前用户',
                'body': '提醒',
                'payload': 'reminder:11:tenant_user:1785312300000',
              },
              {
                'id': 12,
                'title': '其他用户',
                'body': '提醒',
                'payload': 'reminder:12:other_user:1785312300000',
              },
            ];
          }
          if (call.method == 'getActiveNotifications') {
            return [
              {
                'id': 13,
                'title': '已展示',
                'body': '提醒',
                'payload': 'reminder:13:tenant_user:1785312300000',
              },
              {
                'id': 14,
                'title': '其他用户',
                'body': '提醒',
                'payload': 'reminder:14:other_user:1785312300000',
              },
            ];
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {
              'notificationLaunchedApp': launchPayload != null,
              if (launchPayload != null)
                'notificationResponse': {
                  'notificationId': 15,
                  'notificationResponseType': 0,
                  'payload': launchPayload,
                },
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'macOS requests permission and presents foreground notifications',
    () async {
      final service = LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      );

      await service.init();
      expect(await service.requestPermissions(), isTrue);
      await service.show(id: 7, title: '到期提醒', body: '测试任务');

      final permissionCall = calls.singleWhere(
        (call) => call.method == 'requestPermissions',
      );
      expect(permissionCall.arguments, containsPair('alert', true));
      expect(permissionCall.arguments, containsPair('badge', true));
      expect(permissionCall.arguments, containsPair('sound', true));

      final showCall = calls.singleWhere((call) => call.method == 'show');
      final arguments = showCall.arguments as Map<Object?, Object?>;
      final platformSpecifics =
          arguments['platformSpecifics'] as Map<Object?, Object?>;
      expect(platformSpecifics['presentAlert'], isTrue);
      expect(platformSpecifics['presentBanner'], isTrue);
      expect(platformSpecifics['presentList'], isTrue);
      expect(platformSpecifics['presentSound'], isTrue);
    },
  );

  test('future reminder uses persistent zoned schedule', () async {
    final service = LocalNotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
    );
    final fireAt = DateTime.now().add(const Duration(minutes: 5));

    await service.init();
    await service.schedule(
      id: 8,
      title: '未来提醒',
      body: '跨重启仍应触发',
      fireAt: fireAt,
      payload: 'reminder:8',
    );

    final scheduleCall = calls.singleWhere(
      (call) => call.method == 'zonedSchedule',
    );
    final arguments = scheduleCall.arguments as Map<Object?, Object?>;
    expect(arguments['id'], 8);
    expect(arguments['payload'], 'reminder:8');
    expect(arguments['title'], '未来提醒');
  });

  test('system reminder lookup is isolated by user scope', () async {
    final service = LocalNotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
    );
    await service.init();

    final schedules = await service.pendingReminderSchedules('tenant_user');
    final activeIds = await service.activeReminderIds('tenant_user');

    expect(schedules.keys, {11});
    expect(
      schedules[11],
      DateTime.fromMillisecondsSinceEpoch(1785312300000, isUtc: true),
    );
    expect(activeIds, {13});
  });

  test('reminder payload remains compatible and carries task identity', () {
    expect(
      ReminderNotificationSelection.parse(
        'reminder:11:tenant_user:1785312300000:201',
      ),
      const ReminderNotificationSelection(
        dispatchId: 11,
        scope: 'tenant_user',
        taskServerId: 201,
      ),
    );
    expect(
      ReminderNotificationSelection.parse(
        'reminder:12:tenant_user:1785312300000',
      ),
      const ReminderNotificationSelection(dispatchId: 12, scope: 'tenant_user'),
    );
    expect(ReminderNotificationSelection.parse('reminder:bad'), isNull);
  });

  test('notification response publishes a typed reminder selection', () async {
    final service = LocalNotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
    );
    final selection = service.reminderSelections.first;

    service.dispatchNotificationResponseForTesting(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'reminder:16:tenant_user:1785312300000:206',
      ),
    );

    expect(
      await selection,
      const ReminderNotificationSelection(
        dispatchId: 16,
        scope: 'tenant_user',
        taskServerId: 206,
      ),
    );
  });

  test('duplicate notification response is dispatched only once', () {
    final service = LocalNotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
    );
    final selections = <ReminderNotificationSelection>[];
    service.reminderSelections.listen(selections.add);
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: 'reminder:16:tenant_user:1785312300000:206',
    );

    service.dispatchNotificationResponseForTesting(response);
    service.dispatchNotificationResponseForTesting(response);

    expect(selections, [
      const ReminderNotificationSelection(
        dispatchId: 16,
        scope: 'tenant_user',
        taskServerId: 206,
      ),
    ]);
  });

  test(
    'notification launch selection is retained until UI consumes it',
    () async {
      launchPayload = 'reminder:17:tenant_user:1785312300000:207';
      final service = LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      );

      await service.init();

      expect(
        service.takePendingReminderSelection(),
        const ReminderNotificationSelection(
          dispatchId: 17,
          scope: 'tenant_user',
          taskServerId: 207,
        ),
      );
      expect(service.takePendingReminderSelection(), isNull);
    },
  );
}
