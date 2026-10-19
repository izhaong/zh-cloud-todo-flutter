import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/core/settings/quick_add_input_style_setting.dart';

/// FL #344 面④：输入框样式设置（`:54`「切换输入框样式」）。
/// 三种样式（产品裁决）：inline（默认，= 现状）/ collapsed（收起单行）/ expanded（展开）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('默认读回 inline（= 现状，不改既有体验）', () async {
    final setting = QuickAddInputStyleSetting();
    expect(await setting.read(), 'inline');
  });

  test('三种样式都能存取往返', () async {
    final setting = QuickAddInputStyleSetting();
    for (final style in ['collapsed', 'expanded', 'inline']) {
      await setting.write(style);
      expect(await setting.read(), style, reason: '$style 存取往返');
    }
  });

  test('坏值：未知 id 写侧拒收、读侧回默认', () async {
    final setting = QuickAddInputStyleSetting();
    expect(
      () => setting.write('bogus'),
      throwsArgumentError,
      reason: '写侧校验 —— id 用稳定 wire 名，未知 id 混入会让渲染出空态',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todo_quick_add_input_style_v1', 'bogus');
    expect(await setting.read(), 'inline', reason: '读侧兜底：坏值回默认');
  });

  test('reset 回默认', () async {
    final setting = QuickAddInputStyleSetting();
    await setting.write('collapsed');
    await setting.reset();
    expect(await setting.read(), 'inline');
  });
}
