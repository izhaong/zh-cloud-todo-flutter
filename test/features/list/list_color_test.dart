import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/list/list_color.dart';

/// specs/102 / FL Issue #339：清单编辑器「颜色」属性。
///
/// 嘀嗒《02-用清单管理任务.md》:73
/// 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
/// 色板具体取值本端裁定（嘀嗒未公开色值），见 specs/102-list-color/spec.md。
void main() {
  group('listColorFromHex', () {
    test('六位 #RRGGBB 解析成不透明色', () {
      expect(listColorFromHex('#4772FA'), const Color(0xFF4772FA));
      expect(
        listColorFromHex('#00c853'),
        const Color(0xFF00C853),
        reason: '小写也要吃',
      );
    });

    test('null / 非法串一律回 null，不抛错', () {
      expect(listColorFromHex(null), isNull);
      expect(listColorFromHex(''), isNull);
      expect(listColorFromHex('red'), isNull, reason: '不是 hex 就回退无色');
      expect(listColorFromHex('#12345'), isNull, reason: '位数不对不猜');
    });
  });

  group('kListColorChoices', () {
    test('色板非空且全部可解析、无重复', () {
      expect(kListColorChoices, isNotEmpty);
      expect(
        kListColorChoices.toSet().length,
        kListColorChoices.length,
        reason: '重复色会让两颗圆点长一样',
      );
      for (final hex in kListColorChoices) {
        expect(listColorFromHex(hex), isNotNull, reason: '$hex 必须能被自家解析器吃下');
      }
    });
  });
}
