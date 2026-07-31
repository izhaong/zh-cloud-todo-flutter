import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS custom channel exclusively owns the todo deep link', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final sceneDelegate = File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsStringSync();

    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>zhcloudtodo</string>'));

    expect(appDelegate, contains('"zh_cloud_todo/native"'));
    expect(appDelegate, contains('"zh_cloud_todo/native_links"'));
    expect(appDelegate, contains('"getInitialLink"'));
    expect(appDelegate, contains('"share"'));
    expect(appDelegate, contains('UIActivityViewController'));
    expect(appDelegate, contains('FlutterMethodNotImplemented'));

    expect(sceneDelegate, contains('willConnectTo'));
    expect(sceneDelegate, contains('openURLContexts'));
    expect(sceneDelegate, contains('acceptInitial'));
    expect(sceneDelegate, contains('publishWarm'));
  });
}
