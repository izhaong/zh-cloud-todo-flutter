# 042 实施计划 — 倒数纪念日 天/年/周 单位切换

## 落点
唯一改动文件：`lib/features/countdown/countdown_page.dart`（develop 上 117 行、`样式`/`备注` 0 命中、无详情页）。
把 `itemBuilder` 里的 `ListTile` 搬进 `_CountdownTile`（StatefulWidget），因为单位切换是**按行**状态；
换算规则留在顶层纯函数 `countdownCountLabel` 里。

## 步骤 → 验证
| 步骤 | 验证 |
| --- | --- |
| 1. 先写用例（只用可见文案与 semantics label，不用未实现的 API） | 红：`Expected: exactly one matching node … Found: 0`，缺的是 `还有 3 年`，即「点了没换单位」 |
| 2. 加 `TodoCountdownUnit` + `countdownCountLabel` + `_CountdownTile` | 5 条用例全绿 |
| 3. 反向探针 | 摘掉 `InkWell(onTap:)` ⇒ 4 条切换用例红；`cp` 还原后 `cmp -s` 逐字节一致 |
| 4. 六项门禁（最终状态一次跑完，留日志） | 见 `tasks.md` |
| 5. 只读子代理复核 FR-001..FR-006 | 必须拿到 `VERDICT` |
| 6. 回写矩阵 #49（未合并只写「已实现待合并」） | 行仍 6 列、无反斜杠外 `|`、反引号偶数、全角括号配平 |

## 换算
`day` = 绝对天数；`year` = `days ~/ 365`；`week` = `days ~/ 7`。
1095 → 3 年 / 156 周；2000 → 5 年 / 285 周（用例即按此断言）。
闰年不特殊处理：源页没规定，取整即最直白的「多少年」。

## 不做
样式选择器、颜色、图片、备注、持久化、详情页。前三项要么缺契约要么会改可见布局（需先申请重录黄金基线），
后两项源页没写。
