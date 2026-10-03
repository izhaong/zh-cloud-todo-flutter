import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/repeat_frequency_wire.dart';

/// specs/083 / FL Issue #324：本地大写常量与服务端小写连字符两套写法之间的映射。
///
/// 这条映射是本轮新加档位时**顺带挖出来的坑**：老档位全是单个词，`toLowerCase()` 恰好等价，
/// 所以基线一直没暴露；`LEGAL_WORKDAY` 一进来，出库就会发 `legal_workday`（服务端认不出），
/// 入站又会把 `legal-workday` 存成 `LEGAL-WORKDAY`（既匹配不上档位常量也查不到文案）。
void main() {
  const localArms = [
    'DAILY',
    'WEEKLY',
    'MONTHLY',
    'YEARLY',
    'WEEKDAY',
    'LEGAL_WORKDAY',
    'WEEKEND',
    'LEGAL_HOLIDAY',
    'CUSTOM',
  ];

  test('两档出库是小写连字符，与服务端 TodoRepeatFrequencyEnum 同名', () {
    expect(repeatFrequencyToWire('LEGAL_WORKDAY'), 'legal-workday');
    expect(repeatFrequencyToWire('LEGAL_HOLIDAY'), 'legal-holiday');
  });

  test('老档位形状不变（本轮没有顺手改掉已同步过的值）', () {
    for (final arm in [
      'DAILY',
      'WEEKLY',
      'MONTHLY',
      'YEARLY',
      'WEEKDAY',
      'WEEKEND',
      'CUSTOM',
    ]) {
      expect(repeatFrequencyToWire(arm), arm.toLowerCase());
    }
  });

  test('入站归一回大写常量，缺值退回 DAILY', () {
    expect(repeatFrequencyFromWire('legal-workday'), 'LEGAL_WORKDAY');
    expect(repeatFrequencyFromWire('legal-holiday'), 'LEGAL_HOLIDAY');
    expect(repeatFrequencyFromWire('weekday'), 'WEEKDAY');
    expect(repeatFrequencyFromWire(null), 'DAILY');
    expect(repeatFrequencyFromWire('  '), 'DAILY');
  });

  test('往返恒等：任何一档本地→wire→本地都不长出第三种写法', () {
    for (final arm in localArms) {
      expect(
        repeatFrequencyFromWire(repeatFrequencyToWire(arm)),
        arm,
        reason: '$arm 绕一圈回来变了形，说明某一侧的映射漏了分隔符处理',
      );
    }
  });
}
