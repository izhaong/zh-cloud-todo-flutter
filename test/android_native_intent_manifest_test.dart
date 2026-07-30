import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android custom channel exclusively owns the todo deep link', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
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
  });
}
