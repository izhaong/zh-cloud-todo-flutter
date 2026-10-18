# 164 · 快速添加底部功能栏（FL #344 面①）

## 判据源

《01-添加任务.md》`:17`「你还可以为任务设置『日期』『优先级』『标签』，以及将任务移到『清单』中」
+ `:24`「添加任务时底部功能栏的顺序支持自定义」。

## 口径（产品裁决 + opencode 三轮交叉验证）

- **默认序** `日期 → 优先级 → 标签 → 清单`（原文只列属性不给顺序 ⇒ 默认序为产品补口）；
  「模板」不进主按钮（归模板能力）；
- **v1 降面积路线**（opencode）：渲染**从配置读**（读不到=默认序），编辑入口放第二步 ——
  硬编码在 widget 里会把"推迟"变成"返工"；**id 用稳定 wire 名**（date/priority/tag/list），
  不用界面文案（`TaskSwipeAction.wire` 的教训）；读侧对坏数据丢弃兜底不抛；
- **三项契约写死**（opencode 点名）：
  1. **dueAt 来源优先级**：手选压着 NLP（用户最后的动作最大）；识别行只在没手选时出现；
  2. **标签是二次写入**（失败语义照 `_saveOnce` 先例：任务已建、标签没绑 ⇒ 明说，不回滚）；
  3. **切清单必须联动清空 sectionId**（分区属于原清单，保留会撞
     `create._requireSectionInList` 直接抛 StateError）；
- **优先级不做三态**：chip 显示**生效档**（`_priorityOverride ?? defaultPriority ?? 0` 的
  求值结果）—— 用户看到的 == 将要保存的；
- **清除日期 = 长按**（与桌面底栏逐字对齐；tap=打开弹层）。**识别行不并入日期 chip**
  （它的 tap 是"取消识别"—— `:81` 的判据，并进去两个动作就打架）。

## 改动

1. `QuickAddActionBarSetting`（默认序 + wire id + 读侧兜底 + 写侧恰等校验 + reset）；
2. `_QuickAddActionBar`/`_BarChip`（按配置序摆放；tap 开弹层、长按日期清除；高亮=有手选）；
3. 四个 handler：日期（今天/明天/下周一/选择日期…）、优先级、标签（二次写入）、清单（清 sectionId）；
4. 原**优先级整行 Dropdown 拆除**（`subtask_context_and_consecutive_test` 已同步改走新 chip）；
5. `create` 链路切 state：`_listId/_sectionId`（手选清单生效）；dueAt = 手选 ?? NLP；
6. 识别行加 `_manualDueAt == null` 前置。

## 判据（5 条）与探针

| 判据 | 咬什么 |
| --- | --- |
| 默认序四位都在且屏上单调递增（渲染走配置路径） | 配置序 |
| setting 层：默认读回 / 合法序存取 / 缺项·重复·未知 id 拒收 / reset | 读写两侧 |
| **手选日期压着 NLP**：选「明天」后输入"明天 9 点开会" ⇒ 识别行不出现、dueAt=明天 | dueAt 优先级 |
| **长按日期清除**（已选日期 → 日期） | 桌面口径 |
| **切清单联动清空 sectionId** 且任务落在新清单 | sectionId 联动 |

**反向探针**：切清单不清分区 + 识别行不压制 ⇒ **红**（sectionId 判据咬住）。

## 判据当场抓到的真缺陷（两处）

1. **`write()` 校验漏了"多余 id"**：`containsAll(knownIds)` 只查"不少"，未知 id 混进去照样过
   —— 判据（写 bogus 项）当场红 ⇒ 补上 `set.length != knownIds.length`（**恰等于**）；
2. **清单弹层只渲染"收集箱"**：`ref.watch(...).valueOrNull` 在首次订阅微任务未完成前是 null
   —— 判据（树里 0 个清单项）当场抓到 ⇒ 改 `await ref.read(provider.future)` + mounted 守卫。

## 过程教训（本机慢环境下的测试纪律）

1. **既有测试从不用 `pumpAndSettle`**：quick-add sheet 里 SharedPreferences/NLP listener
   会让"静止"永远等不到 —— 第一版判据直接 **10 分钟超时**。照 `quick_add_save_reentry_test`
   的固定步 pump；
2. **fixture 有种子数据**：`select(...).get()` 后 `hasLength(1)` 会撞上种子任务 —— **按标题过滤**；
3. **弹层项可能不在视口**：`shrinkWrap` 只保证已 build，不保证可点 —— ensureVisible 前先给足 pump 步；
4. heredoc 里的 `\$` 会被转义 —— print 调试串直接失效（用 `+` 拼接）。

## 边界

- **顺序自定义编辑器**（设置页 + 可拖拽）放第二步 —— v1 路径已走配置，届时只加 UI；
- **面④ 输入框样式**（收起单行/展开完整/桌面内联）：桌面内联已有（回车即建），
  移动端「收起单行」是 quick_add_bar 那条链的形状 —— 另刀；
- 标签弹层复用形状（未接「#」哈希路径的 ensureTagIds —— 那是 quick_add_bar 的能力）。
