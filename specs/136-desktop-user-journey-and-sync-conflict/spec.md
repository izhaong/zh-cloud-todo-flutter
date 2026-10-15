# 136 · 桌面端用户旅程模拟 + 同步冲突根治（v1.0.8 实测）

**状态**：已实现并合入 `develop`（PR #656 / #657，Issue #655）

## 背景

用户反馈两件事：

1. **「样式跟之前没什么区别」** —— v1.0.8 装机后肉眼看不出视觉改动。
2. **「时不时报错，有冲突」** —— 界面持续显示红色横幅：
   > 6 项同步需要处理
   > 其中 6 项与其他设备冲突，已采用服务器版本

本规格记录这两个问题的**根因、修法与可复现证据**，并补上「真实用户旅程模拟」
这条此前缺失的自动化验证。

---

## 一、同步冲突：根因与修法

### 证据（全部来自用户机器上的真实库 `todo_t1_u286.sqlite`）

| 证据 | 事实 |
| --- | --- |
| `todo_sync_changes` | `view_preference` serverId=2 排 **3 条**、serverId=4 排 **3 条**，全为 `failed` |
| `attempt_count` | 6 条均为 **0** —— 从未重试 |
| `failure_reason` | 6 条全是 `REVISION_CONFLICT` |
| `todo_entity_revisions` | `view_preference\|2` = **24**、`\|4` = **6**（同组多条共享同一基线） |

### 机制（三个缺陷叠加）

1. **`SyncChangeQueue.enqueue` 不去重**：日历偏好（农历 / 节假日 / 习惯开关）
   每点一次排一条 outbox，同一 `serverId` 会堆多条。
2. **同批共享 baseRevision**：这几条在**同一次 `push()` 批**里各自读到同一个
   revision（24）。服务端接受第一条后 revision→25，后续条目仍带 24 ⇒ 必然
   `REVISION_CONFLICT`。
3. **failed 行不会被重取**：`push()` 只取 `queued|retryable`，于是 failed 行
   永久留在库里 ⇒ 横幅永久挂着，用户点「处理」也无从下手。

### 修法

在 `_pushSyncableChanges` 里先做**批内合并**（`_supersedeWithinBatch`）：

- 分组键：`(entity, serverId 优先 / localId)`。
- 只发送每组**最后一条**；被取代的旧条目置 `resolved`
  （保留审计与幂等键，不物理删除，与 `BoardPreferenceRepository.recoverLatestFailed`
  同口径）。

### 为什么安全

- syncable 实体的 payload 均为**全量快照**（task 走 `_taskPayload`，带
  `parentTaskId` / `sortOrder` 等全部字段），后写完全覆盖前写。
- **追加型动作**（`reminder_dispatch_action`、`repeat_occurrence_action`）每次
  生成**新的 localId**，天然落在不同分组，不会被误合并。
- task 的缩进与排序虽是同一实体，但 payload 都是全量快照，同批只发最后一条即可
  收敛；**本地审计仍保留全部 4 条 queued**，`task_hierarchy_actions_test` 的
  契约不受影响。

### 曾经走错的弯路（记录以免重犯）

最初把去重放在 **`enqueue` 侧**（入队即作废旧条目）。这会让
`task_hierarchy_actions_test` 的「缩进 + 排序共 4 条 outbox 全 queued」契约变红——
该契约要求同实体多条并存。正确位置是**推送侧**：入队保持多条（本地审计），
发送时收敛为一条。

---

## 二、视觉改造：为什么「看不出变化」

### 根因

上一轮（PR #651）**只改了 5 个文件**：

```
lib/app.dart
lib/core/theme/app_theme.dart
lib/core/theme/todo_layout_tokens.dart
lib/core/widgets/app_widgets.dart
lib/features/task/widgets/task_row.dart
```

而仓库共 **169 个 Dart 文件**。用户实际盯着的**侧栏**与**任务详情面板**（4044 行）
**一行都没动**；`AppTextStyles` 只在 3 个文件生效，另有 31 个文件仍硬编码字号。
且既有 golden **只覆盖浅色模式**，而用户实际使用**暗色模式**。

### 本轮改造（按 surfaces 补齐）

| Surface | 改动 |
| --- | --- |
| 排版令牌 | `AppTextStyles` 从 7 个扩为完整阶梯：display 18 / title 15 / subtitle 13-14 / body 13 / label 12 / caption 11，均带行高 |
| 侧栏 | 分组标题、导航行（选中 w600）、徽章、文件夹行、右键菜单、效能坞全部令牌化；硬编码 fontSize 11 处 → 2 处 |
| **选中态** | `F2F2F2` 淡灰（在 `FAFAFA` 画布上几乎不可见）→ 品牌蓝底 `E8F1FE` + 左侧 3px 色条 + 文字 w600 |
| 详情面板 | 硬编码 fontSize 4 处 → 0 处；分区标题加品牌色小圆点做视觉锚 |
| 标题栏 / 快速添加 / 分组标题 | 全部接入令牌 |

### 关键约束（踩过的坑）

- 选中态色条**必须走 `AnimatedContainer` 的 `border` 绘制**，不能在该行 `Row`
  里加子组件：`list_share_entry_test` 用「子树组件数 = 47」的结构判据守护这一行，
  加 2 个组件会变成 54 而红。
- **不能用 `Stack` + `Positioned`** 加色条：`Stack` 的 loose 约束会让内层
  `Material` 塌成零高，**长按命中不到**，动作表弹不出来（实测 16 个测试红）。

---

## 三、可复现验证

### 新增测试

| 文件 | 内容 |
| --- | --- |
| `test/sync_batch_supersede_test.dart` | 模拟服务端「按 revision 只接受第一条」的真实语义：断言同实体只发 1 条、`conflicts` 为空；不同 localId 不互相取代。**变异验证**：注释掉合并逻辑后立刻变红 |
| `test/e2e_real_db_conflict_test.dart` | 在本机真实库**副本**上验证入队行为与真机一致。路径按 macOS 沙箱动态解析，无库则 `skip`，不拖红 CI |
| `test/user_journey_simulation_test.dart` | **15 条用户旅程**（见下） |

### 用户旅程清单

| # | 旅程 |
| --- | --- |
| ① | 启动后四区骨架齐全（rail/sidebar/content/detail） |
| ② | 逐个点开侧栏智能清单，工作区内容区跟着换 |
| ②b | 独立页入口（标签/筛选/笔记）能打开且不崩 |
| ③ | 快速添加创建任务：输入回车后进入当前清单 |
| ④ | 选中任务 → 详情区出真实内容 → 不再显示空态 |
| ⑤ | 完成任务勾选框可点，状态切换不抛异常 |
| ⑥ | 逐个切视图：列表 / 看板 / 时间线 / 四象限 / 日历 |
| ⑦ | 搜索入口（无独立图标时 skip） |
| ⑧ | 设置页可打开且「星期开始于」在 |
| ⑨ | **暗色模式**四区齐全 + 选中态左色条存在 |
| ⑩ | 空数据也进得去（空态不崩） |
| ⑪ | 效能坞：习惯打卡 / 番茄专注 / 倒数纪念日逐个打开不崩 |
| ⑫ | 习惯页在无网络（桩）下优雅降级，不白屏 |
| ⑬ | 成就与勋章页可从设置进入，无网络下不白屏 |
| ⑭ | 改：详情面板改标题并保存，**直接查本地库断言落库** |
| ⑮ | 删：任务右键菜单可达且含「添加子任务」 |

**边界（诚实声明）**：旅程用固定 fixture（内存 Drift + 网络全桩），
**不连真实后端、不替代真机联调**；它能在无人值守下给出「主路径没断」的
可复现证据，但覆盖不到真实同步时序、真实账号态与第三方 SDK 行为。
登录页也不在范围内（fixture 直接以已登录态进 `HomeShell`）。

### 门禁读数

| 门禁 | 结果 |
| --- | --- |
| `flutter analyze` | **0 issue** |
| 全量 `flutter test` | **2058 通过 / 27 跳过 / 7 失败** |
| 那 7 条失败 | **全部为基线既有**（裸 `develop` 同样红，与本切片无关）：`raw_error_text_gate`、`habit_year_stats`×2、`folder_disband_entry`、`task_organize_search_repository`×2、`ios_native_intent_contract` |
| golden | 9 张按新视觉重录 |

### 真机实测

- 用户库 6 条 `failed` 置 `resolved` 后，app 运行 20s+ 无新增 `failed`。
- 装机 v1.0.8（含修复）后，红色冲突横幅消失。

---

## 四、已知遗留

1. **既有 7 条基线失败**归属别的切片（`specs/131` 打卡日志、`59235cba` auto_updater
   等引入），本切片未处理，建议各归属方收口。
2. **视觉覆盖仍不完整**：本轮补齐侧栏/详情/标题栏，但 169 个文件中仍有
   日历/看板/四象限/时间线/习惯/习惯统计等页面保留硬编码字号，
   后续可按同样方式逐步收敛到 `AppTextStyles`。
3. **暗色模式无 golden 基线**：本轮用旅程断言兜住选中态色条，
   但暗色整体无像素基线，建议补一组暗色 golden。
