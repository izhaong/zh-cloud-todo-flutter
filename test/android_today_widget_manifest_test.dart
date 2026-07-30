import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android manifest registers the real today tasks app widget renderer',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final providerInfo = File(
        'android/app/src/main/res/xml/today_tasks_widget_info.xml',
      );
      final layout = File(
        'android/app/src/main/res/layout/today_tasks_widget.xml',
      );

      expect(manifest, contains('.TodayTasksWidgetProvider'));
      expect(manifest, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(manifest, contains('@xml/today_tasks_widget_info'));
      expect(providerInfo.existsSync(), isTrue);
      expect(layout.existsSync(), isTrue);
      expect(
        providerInfo.readAsStringSync(),
        contains('@layout/today_tasks_widget'),
      );
      expect(layout.readAsStringSync(), contains('@+id/widget_task_5'));
    },
  );
}
