# 163 · 农历两档的客户端接线（FL #325 客户端半，service !417）

## 判据源

《10-设置重复任务》`:91`「农历每年（春节、中秋、家人农历生日）/ 农历每月（初一、十五祈福）」。

## 一次重要的口径修正（opencode 交叉验证推翻了上一轮我自己定的）

上一轮（service !417）写「**客户端不上行农历月日** —— 一处真值」。
本轮客户端落地时撞到墙：客户端校验需要 lunarMonth/lunarDay，但客户端**没有农历表**。
opencode 修正：**「一处真值」的真正含义是农历换算的数学只有一份（在服务端），
不是"意图只能有一份"** —— 区分：

- `lunarMonth/lunarDay` 作为**用户意图**（"我要每年八月十五"）⇒ **客户端上行**；
- 作为**反解结果**（startAt 是八月十五）⇒ 服务端兜底（老客户端/导入，保留不删）。

它还点名一个真窟窿：**闰月无处安放**（字段没有 isLeapMonth，"闰四月初一"会**静默塌陷**成
"四月初一"）⇒ **v1 不提供闰月选择** —— 给选择就是给静默塌陷。**别让"塞不进字段"默认变成塌陷。**

A（客户端内置农历表）被否的依据是**本仓既有先例**：`specs/024` 写过
「不得让 Flutter 侧硬编码农历表绕过」—— 1900–2100 两份表 + 闰月 + 大小月逐一核对是长期负债。

## 改动

1. Drift：`lunar_month`/`lunar_day` 两列（schema 31→32，无回填——NULL 即非农历档）；
2. `sync_coordinator` **入站**补两字段（缺了服务端建的规则在第二台设备上编辑不了）；
3. `repeat_rule_repository`：白名单两档 + 校验守卫（正交就拒 / 按档校验 / **反向互斥**）
   + `save` 签名 + **出站 payload** 补两字段；
4. UI：档位表两 chip + 文案映射（读回"农历每年 八月十五"）+ 选中即弹**农历月日选择器**
   （intent 直选；v1 无闰月）+ `_lunarDayText` 中文日读法 + 保存守卫（缺意图不静默存 NULL）；
5. wire：`LUNAR_YEARLY ⇄ lunar-yearly`、`LUNAR_MONTHLY ⇄ lunar-monthly`。

## 判据（4+1 条）与探针（三处咬合）

| 判据 | 咬哪层 |
| --- | --- |
| widget：选农历每年 + 八月十五 ⇒ 落库 `freq=LUNAR_YEARLY, lunarMonth=8, lunarDay=15` 且 payload 带 `lunar-yearly/8/15` | 全链 |
| widget：**未选月日取消选择器 ⇒ 保存被拦**（repeat_rules 0 行） | 对话框守卫 |
| widget：读回「农历每年 八月十五」且不出现裸枚举 | 文案映射 |
| wire：两档双向对齐 + 往返恒等 | wire 层 |
| **直调 repository**：YEARLY 缺月日拒 / MONTHLY 带月拒 / **MONTHLY 缺农历日拒** / DAILY 带 lunar 拒 | repository 守卫 |

**反向探针**：
- 白名单拿掉两档 ⇒ **widget 2 红**；
- `lunarDay` 检查旁路（`if (false && …)`）⇒ **直调判据红**（MONTHLY-null 子句咬住的）。

## 过程教训（本刀最密集的一次，全部如实记）

1. **探针脚本必须带 assert**：本刀前两次探针的 `str.replace` 因 **dart format 重排了代码**
   （单行 `ArgumentError.value(...)` 被折成多行）而**静默未生效** —— 探针"跑过"其实没改到东西，
   判据绿是**假绿**。教训：**replace 前必须 `assert old in s`，探针后必须 grep 确认真改了**。
2. **判据的第一版自己会假绿**：`.last` 定位"取消"按钮 —— 弹层关闭顺序一变就点错，
   探针下守卫全拿掉仍绿。修法：**给弹中弹的按钮配 key**（`lunar-picker-cancel`），
   判据按 key 定位。
3. **widget 判据咬不住哪层要说清**：guard 判据先是"碰巧绿"（repository 层先抛了）；
   补一条**直调 repository** 的判据，牙齿才真正咬在目标层上。
4. **判据要覆盖探针的目标行**：直调判据第一版缺"MONTHLY 缺农历日"子句，
   旁路 lunarDay 检查时它仍绿 —— **每条守卫都要有对应子句，否则探针证明不了判据**。
5. **schema bump 牵连面**：19 处迁移测试硬编码 `user_version = 31` ⇒ 全红。
   逐处更新为 32（这种字面量应该从 schemaVersion 常量读 —— 顺手改一次？**不**，
   Surgical Changes：只更新数字，重构另提）。

## 边界

- **服务端**：`validateRepeatRule` 的"客户端不上行农历月日"注释需要随 intent 口径更新
  （现在 intent 优先、startAt 兜底）—— 小注释修订，随下一刀或 hotfix；
- **ON_COMPLETE 版**：产品收敛后放开（服务端已抛错不猜）；
- **闰月意图**（isLeapMonth 字段）：v1 明确不支持、选择器不提供 —— 要支持是**契约变更**。
