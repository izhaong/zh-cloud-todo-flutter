import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';

CountdownDto _countdownAt(DateTime target) =>
    CountdownDto(id: 1, title: '实测倒数日', targetDate: target, daysRemaining: 30);

void main() {
  // Issue #479：月/日不补零会让同一屏出现两种日期写法（服务端与本地存的都补零）。
  test('单位数月与单位数日都补零', () {
    expect(countdownDateText(DateTime(2026, 11, 3)), '2026-11-03');
    expect(countdownDateText(DateTime(2026, 1, 9)), '2026-01-09');
  });

  test('双位月日保持同一形状，不被改坏', () {
    expect(countdownDateText(DateTime(2026, 12, 25)), '2026-12-25');
  });

  test('列表副标题走同一个补零形状', () {
    expect(
      countdownDateSubtitle(_countdownAt(DateTime(2026, 11, 3))),
      '2026-11-03',
    );
  });
}
