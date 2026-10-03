import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_raw_error_text.dart' as gate;

/// 第 219 轮的常驻门禁接进 `flutter test`（Issue #468）。
///
/// 第二意见（`agent --model grok-4.7-high`）判 FAIL 的第一条就是「这把尺没人跑」：
/// `grep -rn check_raw_error_text` 除脚本自身 0 命中，而 `.github/workflows/ci.yml` 在这个
/// Gitea 实例上没有 runner（runs 现读 `queued`），真正在跑的是 Jenkinsfile 的 `flutter test`。
/// 所以判据实现搬进 Dart 并由本用例调用——跑在 CI 的那一步里，且不依赖 python。
void main() {
  test('lib 下没有任何文案在插异常原文', () {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: '必须从包根跑（flutter test 的 cwd）；扫不到 lib 时这条判据是空的',
    );
    final scanned = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .length;
    expect(
      scanned,
      greaterThan(100),
      reason: '实际扫了 $scanned 个 .dart，应当覆盖整棵 lib',
    );
    final findings = gate.scanPaths(['lib']);
    expect(
      findings,
      isEmpty,
      reason: findings.map((f) => f.toString()).join('\n'),
    );
  });

  test('门禁不是恒绿：坏样本判红、好样本不误判', () {
    expect(gate.selftest(), isNull);
  });
}
