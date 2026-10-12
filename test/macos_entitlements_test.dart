import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS 权限文件的结构判据。
///
/// 这条用例原来盯的是「`keychain-access-groups` 必须是空数组」—— 那正是让
/// `flutter build macos` 过不去的配置：空数组等于申请一个空的钥匙串访问组，
/// 而本机没有 Apple 开发者证书，ad-hoc 签名下 Xcode 直接回
/// `"Runner" has entitlements that require signing with a development certificate`
/// （FL !482 删掉后 rc=1 → rc=0）。判据留着就是在钉一个坏配置，所以改成钉
/// 「不许再把它加回来」+「沙箱必须还在」——后者才是当初想保护的东西。
///
/// 会话在 macOS 上仍写不进钥匙串（`-34018`，data-protection 钥匙串要真 Team ID）
/// 是另一件事，挂在 FL #481，本文件不声称它已修好。
void main() {
  for (final fileName in [
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    test('$fileName 不带 keychain-access-groups：空数组会让 ad-hoc 签名构建失败', () {
      final contents = File('macos/Runner/$fileName').readAsStringSync();

      expect(
        contents,
        isNot(contains('keychain-access-groups')),
        reason: '带这个键（哪怕是空数组）会让 flutter build macos 在没有开发者证书时直接签名失败',
      );
    });

    test('$fileName 仍然保留 App Sandbox', () {
      final contents = File('macos/Runner/$fileName').readAsStringSync();

      expect(
        contents,
        contains(
          RegExp(r'<key>com\.apple\.security\.app-sandbox</key>\s*<true/>'),
        ),
        reason: '沙箱开关必须还在且是开启状态（绕开签名问题的办法不是关掉沙箱）',
      );
    });
  }
}
