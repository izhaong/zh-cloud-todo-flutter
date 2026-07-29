import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fileName in [
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    test('$fileName enables Keychain access for secure storage', () {
      final contents = File('macos/Runner/$fileName').readAsStringSync();

      expect(contents, contains('<key>keychain-access-groups</key>'));
      expect(
        contents,
        contains(RegExp(r'<key>keychain-access-groups</key>\s*<array\s*/>')),
      );
    });
  }
}
