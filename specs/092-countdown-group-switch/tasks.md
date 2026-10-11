# 092 tasks

- [x] 红测：改写 countdown_group_test.dart 为「顶部 tab + 单组页面 + 左右滑」形态（5 红）
- [x] 实现：`_activeGroupIndex` 状态、顶部 tab 条（Semantics selected + label）、
      列表区 `GestureDetector.onHorizontalDragEnd` 横滑翻组、越界收敛、未知 type 平铺兜底
- [x] 绿：10/10
- [x] 变异探针：双路径废掉 → 红 3 条可归因；还原 → 全绿
- [x] 门禁：format 0 changed / analyze 无告警 / 全量 +1589 ~26 All tests passed
- [x] selfscan：specs/092-countdown-group-switch 失项 0
- [x] PR → 合并 → 矩阵 #50 行收尾 → 父仓 pin
