import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android custom channel exclusively owns the todo deep link', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/zh04/zh_cloud_todo_flutter/MainActivity.kt',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        '<meta-data android:name="flutter_deeplinking_enabled" '
        'android:value="false"/>',
      ),
    );
    expect(manifest, contains('android:path="/add"'));
    expect(manifest, isNot(contains('android:pathPrefix="/add"')));
    expect(activity, contains('"supportsLinkEvents" -> result.success(true)'));
  });
}
