# 169 台账（FL #344 面④：输入框样式三档）

## 判据源

《01-添加任务》`:54`「点击输入框右侧的下拉选项…你还可以点击『输入框设置』切换输入框样式」。

## 口径（产品裁决 + opencode 形状）

三种样式（id 用稳定 wire 名）：`inline`（桌面内联回车即建，**默认 = 现状**）/
`collapsed`（收起单行：工具行不显示）/ `expanded`（展开带工具行）。
原文入口是**输入框右侧下拉 → 输入框设置**；v1 先落设置页「任务」分区
（紧邻「智能识别日期」），下拉入口随桌面壳成熟度另刀 —— 记在 spec 边界。

## 改动

- [x] `QuickAddInputStyleSetting`（三 id + 读侧坏值回默认 + 写侧枚举拒收）；
- [x] `QuickAddBar` 按样式渲染：collapsed ⇒ 工具行（日期/优先级/标签/标签计数）
      不显示，**输入框仍在、回车仍建**（收起的是工具，不是能力）；
- [x] 设置页 Tile（PopupMenu 三档选择）。

## 判据与探针

- [x] setting 4 条（默认 inline / 三档往返 / 坏值写拒读兜 / reset）；
- [x] widget 2 条（collapsed 工具 0 个+回车仍建；inline = 现状工具在）；
- [x] **探针**（_showTools 恒 true 忽略设置）⇒ collapsed 判据红；
- [x] 全量 `+2158 ~26` 0 失败；analyze 0；format rc=0。

## 过程教训

1. **设置页组件取色用 `brandColors(context)`，别用
   `Theme.of(context).extension<AppThemeExtension>()!`** —— 不少设置页测试的
   theme 不带 extension，`!` 直接 Null check 崩（旅程/星期开始两族测试连带红）；
2. **给设置页加行要跑全量**：窄视口的旅程测试（user_journey_simulation）
   对"星期开始于"的可见性有隐含假设 —— 加一行就把它挤出视口 ⇒ 测试补
   `scrollUntilVisible`（按用户实际动作滚过去，比改断言诚实）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| setting 4 条 + widget 2 条 | 全绿 |
| 反向探针 | 红 |
| 全量（exclude golden/performance） | `+2158 ~26`，**0 失败** |
