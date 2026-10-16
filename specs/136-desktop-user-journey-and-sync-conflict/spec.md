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
| `test/user_journey_simulation_test.dart` | **16 条用户旅程**（见下，0 skip） |

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
| ⑦ | 搜索：⌘K 指令菜单 →「全局搜索」→ 搜索页（断言面板真的关闭） |
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

### Web 端（浏览器）真实账号巡检

用真实账号 + 真实后端把 release web 包跑在 Chromium 里逐条走主路径，
并用 `/app-api/todo/sync/pull` 反查服务端落地：

- 登录（密码 / 验证码两档卡片高度完全一致，427px 不动）→ 收集箱空态
- 快速添加 2 条 → 侧栏计数与列表即时刷新，输入框回车后清空
- 点行开详情（wide 档内联，右侧 432px）→ 改标题 → 保存 → 列表标题同步
- 勾选完成 → 计数 2→1，任务落到「已完成」分组
- 视图切换：列表 / 看板 / 时间线 / 四象限 / 日历均可进入
- 侧栏：标签（新建「工作」成功）、筛选器、笔记、设置；轨道：日历 / 习惯 / 我的
- ⌘K →「全局搜索」→ 搜「买」命中「任务 · 买牛奶和面包」
- 设置 → 主题 → 深色：整站换肤正确，验完改回「跟随系统」
- 服务端 `sync/pull` 回读：`task 1297 rev1→rev2`（改名）、`task 1298 rev1→rev2`
  （完成）、`tag 2 工作`、`view_preference 7 rev1→rev2`，**无 conflicts**

**本轮修掉的一个真实缺陷**：`TodoSyncStatusAnnouncement` 挂在
`Stack(fit: StackFit.expand)` 里，`SizedBox.shrink()` 被父级紧约束撑成整屏，
Web 无障碍层随之生成一个整屏 / `pointer-events: auto` / `z-index: 22` 的
`flt-semantics` 节点，**开着读屏器时整个工作区点不动**（自动化也报
“intercepts pointer events”）。改成 `Positioned(left: 0, top: 0)` 给松弛约束、
锚点固定 1×1 后，既有 DOM 节点（`aria-live` 播报）保留，又不再盖住命中区域；
回归测试见 `test/features/home/todo_workspace_layout_test.dart`
「sync status announcement does not cover the workspace hit area」。

**边界（诚实声明）**：浏览器巡检走 CanvasKit 渲染，与 macOS 原生打包版存在
平台差异（字体回退、`flutter_secure_storage`、通知 / 小组件）；巡检期间后端被
`scripts/dev-service-hot.sh` 反复热重启（`yudao-module-marketing` 源码在并发
编辑），同步请求间歇 `ERR_CONNECTION_REFUSED`，应用如实提示
「同步失败，将在稍后重试」而非伪成功。

---

## 四、已知遗留

1. **既有 7 条基线失败**归属别的切片（`specs/131` 打卡日志、`59235cba` auto_updater
   等引入），本切片未处理，建议各归属方收口。
2. **视觉覆盖仍不完整**：本轮补齐侧栏/详情/标题栏，但 169 个文件中仍有
   日历/看板/四象限/时间线/习惯/习惯统计等页面保留硬编码字号，
   后续可按同样方式逐步收敛到 `AppTextStyles`。
3. **暗色模式无 golden 基线**：本轮用旅程断言兜住选中态色条，
   但暗色整体无像素基线，建议补一组暗色 golden。

---

## 五、Web 巡检发现的版式问题（待排期）

按「影响面 × 修复成本」排序，均**未修**，仅记录证据：

1. **详情栏常驻 432px**：`_desktopWide` 里 `todo-detail` 是固定宽 `SizedBox`，
   没选任务时仍占满一列并显示「选择任务以查看详情」。1440 宽下内容区只剩
   ~677px，看板列被裁、日历列被挤；在「习惯 / 我的」等非任务模块里这列还
   语义不通（习惯页右侧仍写「选择任务以查看详情」）。
2. **全局页在桌面端仍是移动版式**：设置 / 搜索 / 标签 / 筛选器走独立路由，
   没有轨道与侧栏，标题居中、卡片与输入框拉满 1440px；而习惯 / 我的在
   工作区里是左对齐标题。同一桌面端出现两套标题对齐与两套内容宽度。
   （搜索页的「全部 / 任务 / 清单 / 标签」筛选条还是居中的，与左对齐结果列表不一致。）
3. **日历月视图末行被裁**：月网格固定约 98px 行高，6 行 + 表头 =
   626px > 可用 600px（1440×900），最后一行（1–7）只露出约 38px，
   且不可纵向滚动。
4. **四象限任务裸文本**：看板卡片有白底圆角描边 + 优先级 chip + 拖拽手柄，
   四象限里的任务只有一行文字（无卡片外壳、无复选框），两个视图的卡片语言不一致。
5. **编辑缓冲与即时生效混用**：详情面板的标题 / 描述 / 优先级要按「保存」
   才落库（实测关掉面板即丢弃），而截止时间 / 清单 / 标签 / 检查事项是即时生效；
   面板没有任何「未保存」提示。
6. **无障碍命名缺失**：标签新建弹窗的颜色色块按钮没有可访问名称
   （semantics 里只有空 button）。
7. **轨道 tooltip 抢指针**：轨道图标 hover 出的 tooltip 其无障碍节点
   `pointer-events: auto`，会盖住紧邻的下一个轨道项，自动化点击被拦。
   与已修的播报锚点是同一类问题（Flutter web 给非交互语义节点也开了 auto）。
8. **推荐任务卡片不跟随改名 / 完成刷新**：任务改名或勾选完成后，
   「推荐任务」里仍是旧标题、旧状态，直到重进页面。

---

## 六、第二轮：用户真机反馈的 5 条（已修）

用户在装好的 macOS 版上手动过了一遍，逐条提了 5 个问题。全部用「先写会红的
测试 → 再改 → 变异验证」的方式收口，9 张 golden 一张未重录。

1. **垃圾桶空态不居中**（偏左 205px @wide / 349px @compact）。
   根因：内容区外面裹着 `Stack(fit: StackFit.expand)` 的默认值 `loose`，
   非定位子节点拿到松弛约束，`AppEmptyState` 于是缩成「内容宽度」贴上左边。
   修：`Stack(fit: StackFit.expand)`。测试
   `test/features/home/todo_workspace_layout_test.dart` 的
   「{wide,compact} 垃圾桶空态在内容区水平居中」。
2. **「显示农历」联动「显示节假日调休」**（真 bug，不只是观感）。
   `_CalendarInfoToggleTile.onChanged` 里 `showHolidays` 那一路的三元写漏了
   一个分支，点「显示农历」会把节假日也置成同一个值。修：改用
   `_CalendarInfoField` 枚举定位自己那一位，三个分支写对称。测试
   `test/features/settings/calendar_info_settings_test.dart` 的
   「点「显示农历」不会顺带改「显示节假日调休」」（widget 级真点开关，
   原来那条用例是绕开页面直写仓储，所以漏了）。
3. **任务详情「时间段」两个按钮紧贴成一块**。原先是 `ListView` 里两个
   `OutlinedButton` 直接相邻、描边相接。修：并排成 `Row` + `Expanded`，
   中间留 12px；文案去掉与图标重复的「开始：/ 结束：」前缀，长值靠省略号兜底。
   测试 `test/features/task/task_detail_pane_test.dart` 的
   「时间段两个入口并排且有间距，不是上下紧贴的一整块」。
4. **「新任务默认值」下拉框拉满整屏**。修：表单限宽 420 居中
   （下拉展开层宽度跟字段走，展开后也不再是一整屏宽的板子）。测试
   `test/features/task/task_default_reminder_test.dart` 的
   「1440 宽桌面端表单限宽，下拉不拉满整屏」。
5. **设置页「时区」开关比其它开关右出 12px**（1423 行实测：时区 1415，
   其余三个开关与所有 trailing 文案 / 箭头都是 1403）。根因是那一行自带
   `contentPadding: horizontal 12`。修：不覆写内边距，跟同卡其它行走同一默认值。
   另外把「标签」「过滤器」并进同一张 `AppCard`（原来两张卡之间的卡间距
   比同卡行距大一截，与「日期与时间 / 功能模块 / 主题」的分组观感不一致）；
   并卡后 Flutter 会把每行拆成独立语义节点，故按行补 `MergeSemantics`
   把「取值 + 失败原因同节点」的既有读屏契约原样保住。
   测试 `test/features/settings/settings_layout_test.dart` 两条。

**这一轮的门禁**：`flutter analyze` 0 issue；全量 `flutter test` 与基线同为
7 条既有失败；`test/visual/` 9 张 golden 全绿（未重录）。

---

## 七、真机闭环巡检：任务挂标签整条链路是断的（已修）

在真实后端上逐功能跑「UI → 本地库 → push → 服务端 → 拉回」时抓到：

- 详情面板勾上「工作」后本地 `todo_task_tags` 有行、复选框 `aria-checked=true`；
- `/sync/push` 请求体里带着
  `{"entityType":"task_tag","payload":{"taskId":…,"tagIds":[…]}}`；
- 服务端 `TodoSyncServiceImpl` 对 `ENTITY_TASK_TAG` 直接
  `throw exception(TODO_SYNC_INVALID_ARGUMENT)`（源码注释写明「task_tag 关联表
  不支持客户端 push：所有变更走 `/app-api/todo/tag/{task-bind,task-unbind}`」）；
- 响应 `{"code":1032001003,"msg":"Todo 同步参数无效"}`，界面**既无横幅也无报错**；
- 而且**整批一个事务**：与它同批的检查事项被一起拒掉，跟着一起丢。

改法（对齐服务端契约，不动后端）：

1. `SyncEntities` 把 `taskTag` 移出 `syncable`，与 `folder` 一样由
   `SyncCoordinator` 路由到 REST；
2. 新增 `_pushTaskTagChanges`：按「先 `task-unbind` 掉被移除的、再 `task-bind`
   目标集合」落到 `/tag/task-bind`；`code != 0` 当失败重试（不再静默吞）；
3. `TagRepository.setTaskTags` 的 payload 补 `previousTagIds`，供推送端算解绑集合。

**闭环证据**（同一账号真实后端 `sync/pull` 回读）：修复前服务端 `task_tag` 实体数
为 **0**；修复后出现 `task_tag #1 rev2` / `task_tag #2 rev1`，并且被连坐的
`task #1319 rev1 闭环检查项1` 也一起落地了。

**回归**：`test/sync_task_tag_rest_test.dart`（新增，先红后绿）；
`test/sync_coordinator_organize_search_test.dart` 两条旧契约用例改为锁
「走 REST + 用换回来的真 ID、临时 ID 不泄漏」。

**待确认的跨仓契约**：后端明确拒绝 task_tag 的 push，而客户端此前为此专门写了
临时 ID 映射（`same batch task-tag reuses unsynced task and tag temporary IDs`）。
两者只能留一个——本次按后端注释改成 REST。若后端后续要支持 task_tag push，
需要后端与客户端一起改。

---

## 八、真机闭环矩阵（真实后端逐功能反查）

判据：每条都用 `POST /app-api/todo/sync/pull` 反查服务端实体/字段，不看界面自证。

| 功能 | UI 动作 | 服务端证据 | 结论 |
| --- | --- | --- | --- |
| 登录 / 会话失效 | 密码登录；过期后自动回登录页 | 登录成功；页面提示「登录状态已失效」 | 闭环 |
| pull | 清空 IndexedDB 后重新登录 | 一次拉回 18 项，任务/清单/标签/偏好都在 | 闭环 |
| 快速添加任务 | 收集箱回车 | `task #1311 rev1 闭环任务A` | 闭环 |
| 改名 + 优先级 | 详情改标题、选「高优先级」、保存 | `#1311 rev2 闭环任务A改 prio=3` | 闭环 |
| 截止时间 | 时间设置 sheet → 日期 → 时间 → 详情「保存」 | `#1311 rev4 dueAt=1792085700000` | 闭环 |
| 完成 / 取消完成 | 行复选框两次 | `#1311 rev5 status=DONE` → `rev6 status=TODO` | 闭环 |
| 标签挂任务 | 详情勾「工作」 | `task_tag #1 rev2` / `#2 rev1` | 闭环（本轮修复） |
| 检查事项 | 详情加检查项 | `task #1319 rev1 闭环检查项1` | 闭环（本轮修复） |
| 子任务 | 详情 → 添加子任务 → 保存 | `task #1320 rev1 闭环子任务1` | 闭环 |
| 清单创建 | 侧栏 → 新建清单 → 保存 | `list #34 rev1 闭环清单A` | 闭环 |
| 删除任务 | 详情 → 删除 → 确认 | `tombstones: DEL task #1311` | 闭环 |
| 视图切换 / 偏好 | 列表↔日历↔看板 | `view_preference #7/#8` revision 推进 | 闭环 |
| 全局搜索 | ⌘K → 全局搜索 → 输入 | 命中「任务·闭环子任务1」「清单·闭环清单A」「标签·工作」 | 闭环（本地） |
| 习惯 / 番茄 / 倒数日 / 笔记 | 效能坞逐个打开 | 各自空态正常，`pageerror` 0 条 | 可打开（纯本地，不入 outbox） |
| **垃圾桶恢复** | 删除后打开垃圾桶 | 页面**写死空态**（`home_shell.dart:838` 直接 return `AppEmptyState`），从不查库；服务端也只有 tombstone、无 undelete | **未实现** |

未跑：清单重命名/删除、标签删除、筛选器 CRUD、成就与勋章、设置页各开关的真机闭环。

---

## 九、真机全闭环验收总结

在真实 Chromium + 真实后端（`127.0.0.1:48080`）环境下，以反查 `sync/pull` 实体变更为主干，完成了全功能的真机闭环巡检：

1. **认证与拉取（Pull）**：IndexedDB 全清后登录，一次性拉回全部实体，页面即时重绘，数据完整无丢。
2. **任务生命周期**：快速创建 → 详情编辑标题 → 优先级高 → 截止时间保存 → 勾选完成（`status=DONE`） → 取消完成（`status=TODO`） → 删除任务（`tombstone DEL task`），全部 revision 递增有序，无冲突。
3. **标签与检查事项**：
   - 修复了 `task_tag` 不支持 push 导致的整批回滚，改走 REST `/app-api/todo/tag/{task-bind,task-unbind}`；
   - 标签绑定成功落库服务端（`task_tag #1, #2`），解除了连坐效应，检查事项（`task #1319`）与子任务（`task #1320`）均正常落地。
   - 标签删除产生 `DEL tag #3` tombstone。
4. **清单与筛选器**：
   - 清单创建 `list #34 闭环清单A` → 长按编辑重命名 `闭环清单A改`（rev2） → 删除产生 `DEL list #34` tombstone。
   - FilterBar 设定高优先级条件 → 「保存为过滤器」生成 `filter #1 rev1 高优先级过滤器` → 侧栏「筛选器」页面解析展示 → 二次确认删除产生 `DEL filter #1` tombstone。
5. **设置项与偏好**：
   - 「显示农历」与「节假日调休」联动 bug 修复经真机验证彻底解除联动；服务端 `view_preference #8`（`CALENDAR_INFO`）独立由 rev3 升级到 rev4。
   - 「星期开始于」修改为周日，服务端新落地 `view_preference #9`（`WEEK_START: {"weekStart":7}`）。
   - 「成就与勋章」页面入口完整正常打开。
6. **已知遗留与边界**：
   - 垃圾桶当前为纯占位空态，无恢复已删除功能（服务端仅留 tombstone）。
   - 习惯/番茄/倒数日/笔记为纯本地表存储，不参与 outbox 同步协议。

门禁验收：`flutter analyze` 保持 **0 issue**，`flutter test` 保持 **仅 7 条基线既有失败**，`test/visual/` 9 张 golden 全部通过。
