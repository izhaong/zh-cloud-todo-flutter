import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' ||
              call.method == 'requestPermissions') {
            return true;
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
}
