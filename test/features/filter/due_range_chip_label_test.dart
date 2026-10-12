import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';

/// 筛选页签的标签必须是中文（Issue #483）。
///
/// 判据不是「等于某个字符串」一条，而是整张档位表都不许出现纯英文标签 ——
/// 单点断言挡不住下一次漏翻。
void main() {
  const allRanges = <String?>[
    null,
    'today',
    'tomorrow',
    'last7days',
    'next7days',
    'overdue',
    'future',
  ];

  test('未选到期范围时页签叫「日期」，不再是漏翻的 Due', () {
    expect(dueRangeChipLabel(null), '日期');
  });

  test('到期范围每一档的可见标签都不是纯英文', () {
    for (final range in allRanges) {
      final label = dueRangeChipLabel(range);
      expect(
        label,
        isNot(matches(RegExp(r'^[A-Za-z0-9 ]+$'))),
        reason: '档位 $range 的可见标签是「$label」，用户可见文案不得只有英文',
      );
    }
  });

  test('已知的六档都有中文标签，未知值不落到英文兜底', () {
    expect(dueRangeChipLabel('today'), '今日');
    expect(dueRangeChipLabel('tomorrow'), '明天');
    expect(dueRangeChipLabel('last7days'), '近 7 天');
    expect(dueRangeChipLabel('next7days'), '未来 7 天');
    expect(dueRangeChipLabel('overdue'), '已过期');
    expect(dueRangeChipLabel('future'), '将来');
    // 未知值走兜底：兜底本身必须是中文，否则任何脏数据都会吐出英文页签。
    expect(dueRangeChipLabel('nonsense'), '日期');
  });
}
