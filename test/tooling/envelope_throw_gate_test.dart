import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_envelope_throws.dart' as gate;

/// Issue #477 的常驻门禁，接进 `flutter test`（Jenkinsfile 真执行的那一步）。
///
/// 形状照搬 `raw_error_text_gate_test.dart`：判据实现留在 `tool/`，由本用例调用，
/// 这样「7 处信封抛点都改到位」不是靠人肉 grep 的一句话。
void main() {
  test('lib 下没有自己拼的信封失败异常', () {
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
