# 功能规格：设置里的「日期与时间 → 时区」总开关（specs/055 / FL Issue #368 / 矩阵 #12 缺项 ⑥）

## 一、来源（逐字引用，基准 zh-cloud-docs `origin/develop`）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/07-固定时间与固定时区.md`

| 锚点 | 原文 | 用在哪条 |
| --- | --- | --- |
| `:11`（移动端） | 「点击「设置」 -「日期与时间」 - 开启「时区」开关。**开启后**，在为任务设置时间时，即可选择「固定时区」或「固定时间」。」 | FR-1、FR-2（开关是两档选择的**前置**，不是可选美化） |
| `:17`（桌面端） | 「点击「头像」-「设置」 - 「日期与时间」- 开启「时区」开关。开启后，…」 | 同一判据的另一端形态（本仓一套代码，只做一份入口） |
| `:48` | 「选择「固定时区」，即意味着任务的时间会**随着所在时区的不同而改变**。」 | 划清本面边界：这一档**已有**，本面不改它的语义 |
| `:60` | 「选择「固定时间」，即意味着**不论所处时区如何变化，任务的时间都会保持一致**。」 | **不在本面** ⇒ 另单 FL #369（要先补 service 契约） |

术语照抄嘀嗒：**「日期与时间」**、**「时区」**、**「固定时区」**、**「固定时间」**。不自创「时区支持 / 时区模式 / 跨时区」。

## 二、现状（基准 `zh-cloud-todo-flutter origin/develop@9032005`，逐条实测）

```
git grep -n "task-reminder-fixed-timezone" -- lib          # 1 命中：lib/features/task/task_detail_pane.dart:404
git grep -n "固定时区" -- lib                                # 命中在提醒弹窗、task_time_formatter、app_database 注释
git grep -n -e 日期与时间 -e 时区 -- lib/features/settings    # 0 命中（正向对照：同命令形态换 "任务" 在 settings_route.dart 有命中）
```

- **能力只在单个任务上**：提醒弹窗里有一条 `SwitchListTile(key: 'task-reminder-fixed-timezone', title: '固定时区')`
  （`task_detail_pane.dart:403-412`，键在 `:404`），它**永远出现** —— 没有任何全局前置。嘀嗒的句式是「开启后…即可选择」，⇒ 本仓缺的正是那个前置开关。
- 偏好怎么存已有成熟先例：`lib/state/repositories/task_sort_preference_repository.dart` 与
  `task_capture_defaults_repository.dart` 都落在 **`todo_view_preferences` 表**（`sourceType` + `sourceKey` + `valueJson`），
  并 `enqueue(entity: SyncEntities.viewPreference, …)` 走既有 outbox ⇒ **不动 SQL、不动后端契约**（缺项 ⑤ 才需要契约）。
- 「设置」页的骨架：`lib/features/settings/settings_route.dart` 用 `_Section(title: …)` 分组 + `_Tile` 进子页
  （小节现值：账号 / 任务 / 主题 / 关于 —— `git grep -n "_Section(title:" -- lib/features/settings/settings_route.dart` 数得 4 个）。

## 三、用户故事

1. 我从不出国，不想知道什么时区不时区 —— 「设置 → 日期与时间」里把「时区」关掉后，任务提醒弹窗里不该再出现「固定时区」这一项。
2. 我上周给「伦敦开会」那条任务勾了固定时区，这周图省事把总开关关了 —— **那条任务的时区不能因此被改掉或丢掉**，重新打开开关时它得还在原样。

## 四、功能需求

- **FR-1 有一个「日期与时间」小节，内含「时区」开关**：`settings_route.dart` 里新增 `_Section(title: '日期与时间')`，
  其内一条 `SwitchListTile(key: ValueKey('settings-timezone-enabled'))`、`title: Text('时区')`。文案与术语逐字取嘀嗒。
- **FR-2 关掉 ⇒ 任务上的「固定时区」这一档不出现**：`task_detail_pane.dart` 的固定时区 `SwitchListTile`
  （现值 `:403-412`）仅在偏好为开时渲染。**关掉后「创建时区（IANA）」那个输入框仍要在**
  （`labelText` 三元在 `:417`，它是本仓既有的普通字段，不因总开关消失 —— 这条边界写下来防我下一步顺手把它也藏了）。
- **FR-3 开关不改写任何任务数据（本面的主断言）**：切换开关只写 `todo_view_preferences` 一行，
  **不许**触碰 `todo_tasks.timeZone` / `fixedTimezone`。判据用"读回来一样"而不是"没报错"：
  关 ⇒ 既有固定时区任务的 `timeZone` 与 `fixedTimezone` 逐字段等于切换前；再开 ⇒ 仍等于切换前。
- **FR-4 持久化 + 跨重启**：偏好走 `todo_view_preferences`（`sourceType='DATE_TIME'`、`sourceKey='timezone'`、
  `valueJson='{"enabled":<bool>}'`），并 `enqueue(entity: SyncEntities.viewPreference, op: upsert, …)`
  —— 照 `task_sort_preference_repository.dart` 的形，不自己拼 outbox 字段。
- **FR-5 展示层不受总开关影响**：`lib/core/time/task_time_formatter.dart` 那条「`<IANA> 固定时区`」渲染
  （`git grep -n "固定时区" -- lib/core/time`）在开关关掉时**照旧**输出 —— 数据还在，就不该假装没设过。
- **FR-6 「固定时间」那一档本面不做**：它需要逐任务的三态模式位（不固定 / 固定时区 / 固定时间），
  现在只有 `fixedTimezone` 布尔 + `timeZone` 字符串 ⇒ 按「后端缺契约时先在 zh-cloud-service 修契约再动前端」，
  已另立 FL #369（其正文把契约问题写成第一道门），本面不碰。

## 五、四件套（新增界面必须过）

1. **320px + 1.3 倍字号**：在**设置页自己的 context** 上实测（宽度 320、`textScaler: TextScaler.linear(1.3)`），
   判据是「小节标题 + 『时区』标题 + 『日期与时间』标题」三处 `RenderFlex` 溢出量 = 0；
   ⚠️ 测的是这条新加的 `SwitchListTile` 所在的 `Column`，不是整页根 —— 拿整页当被测对象会恒绿。
2. **独立读屏语义**：开关的 `Semantics` 要能读出「时区」+ 开/关状态，不许只靠颜色区分。
   判据用 **`getSemantics(f).getSemanticsData().flagsCollection.isToggled`**：开时 `Tristate.isTrue`、
   切换后 `Tristate.isFalse`（正反两条都要，只有正向的那条可能恒真）；名称另由
   `find.bySemanticsLabel(RegExp('时区'))` 钉住。
   为什么是这份数据（三方独立一致：复核探针、本仓 `/tmp/r82/probe-pre-fix-bad0933.log`、
   cursor-agent 交叉验证 `/tmp/xcheck/q1.out`）：`SemanticsNode.flagsCollection` 只是**节点自有**的位，
   子节点被合并时 flags 不回写；而 `SemanticsNode._addToUpdate` 是先 `getSemanticsData()`、再
   `updateNode(flags: data.flagsCollection)` ⇒ 平台读屏吃的是 `SemanticsData` 那份。
   名字坑（都实测过）：`Switch` 发的是 `toggled` 不是 `checked`；`dart:ui` 上叫 `isToggled`/`isChecked`，
   没有 `isToggle`/`hasCheckedState`；本仓这版 SDK 的 `WidgetTester` **没有** `getSemanticsData(finder)`
   （编译不过），得写 `getSemantics(f).getSemanticsData()`；`SemanticsNode` 也没有公开的 `actions`。
3. **失败保留已加载数据**：写偏好抛错 ⇒ 开关**回到切换前的值**并给可见反馈（SnackBar），
   且既有任务的 `timeZone` 不受影响（FR-3 的同一套断言，只是这次注入一次失败）。
4. **过期响应不覆盖新响应**：判据是 R3 —— 并发 `setEnabled(false)` 与 `setEnabled(true)`，
   要求不抛异常、`todo_view_preferences` 恰 1 行、`get()` 回**最后一次意图**、outbox 留 2 条。
   ⚠️ 这一条上一版被我判成"本面不可达"、只登记了取舍。复核第 1 轮 F-2 用实测驳回并被本仓复算接受：
   "读 → 插"不在事务里时，两次并发都读到"无行"，撞 `{source_type, source_key}` 的 UNIQUE 索引
   ⇒ `SqliteException(2067)` 且最后一次意图丢失（`get()` 回 false 而不是最后要的 true）。
   修法不是新增机制，而是**照抄仓内先例**：`task_sort_preference_repository.save()` 本来就整段包
   `_db.transaction(...)`，我抄形时把事务漏了。留痕：`/tmp/r82/probe-pre-fix-bad0933.log`（修前）。

## 六、取舍（拿不准的按推荐走，写在这里）

1. **默认值取「开」**。理由：本仓的固定时区能力今天对每个任务**恒可用**（见「二」），
   默认关会让已有能力对全部老用户凭空消失（数据在、入口没了）—— 那是回归，不是对齐。
   ⚠️ 上一版把这条写成"不照嘀嗒默认「关」"，还留了一句把举证成本推给复核的"这条如果复核不认，请指出……不可测"。
   两处都要改，且都是我的错：
   ① 嘀嗒这页**通篇没写默认状态** —— `grep -c 默认` 在那份 64 行的镜像页上 = 0（命令见 `tasks.md` 二），
      所以"默认关"从来不是原文判据，是我替它加的；
   ② "默认关不可测"也不成立（复核 F-1′ 驳回、本仓复算接受）：默认值有断言（R1 `get()` 即"无记录=开"）、
      "不改写既有任务"有 R2、"入口消失"有提醒显隐那两条 ⇒ 三块合起来完全可测，没有哪一块测不到。
   剩下的只是产品判断：**默认开 = 不破坏既有能力**；代价是新用户首屏比嘀嗒多一个开着的开关。
2. **不复用 `TASK_CAPTURE/defaults` 那条偏好行**：混进去会让"新任务默认值"页的读写多一个它不该关心的字段，
   且两页各自 watch 同一行会互相触发重建。另立 `DATE_TIME/timezone` 一行，代价是多一行偏好记录。
3. **不做"关掉总开关就把所有任务的 fixedTimezone 清掉"**：那是把显隐当数据变更，正是 FR-3 要拦住的那种实现。
4. **（已撤回，留档防止重犯）**上一版为"读屏读不出开/关"给标题加了 `semanticsLabel: '时区，已开启/已关闭'`。
   那个前提是**假的**：我读的是 `SemanticsNode.flagsCollection`（节点自有的位，合并时不含子节点），
   而平台吃的是 `getSemanticsData()` 那份 —— `Switch` 的 `toggled` 本来就出得来（三方实测一致，见「五-2」）。
   ⇒ 自创文案已删，屏幕与播报都回到"嘀嗒的「时区」+ 系统自带的开关态"。
   教训（写进 `tasks.md` 三-3）：**判"某个能力不存在"之前，先确认读的是导出给平台的那份数据；
   名字要按 SDK 里的真名读，读不到名字 ≠ 读不到能力。**

## 七、验收（矩阵口径）

- 矩阵 **#12「固定时间与固定时区」**：做完本面只去掉「设置里没有『时区』总开关」这一条缺口（即 FL #368
  自认的那条"缺项 ⑥"），仍留「任务上没有『固定时间』档」这一条（FL #369 标题写的"缺项 ⑤"）
  ⇒ **状态不翻**（仍「部分」），缺口列改窄并写明「总开关已由 specs/055 落地、剩余缺口是 #369」。
  ⚠️ 编号 ⑤/⑥ 的**可见性取决于读的是哪个 ref**（复核 F-6，本仓复算后按实写成两半）：
  `origin/develop` 上 #12 那一格只有一句「`time_zone/fixed_timezone` 字段有；缺跨时区展示闭环」
  （判据：`git show origin/develop:…#dida-parity-matrix.md | sed -n 73p`），**没有 ①—⑥ 清单** ⇒ 复核员说得对；
  而这张清单只存在于**未合并**的 docs 分支（同一文件在 `docs/parity-replay-combined` 上是 `:79`，
  `grep -c ⑤` 两边分别是 3 与 21）。⇒ 这不是"谁写错了"，是 docs 那批 PR 压着没合的后果；
  矩阵侧已把本轮的落点写成文字缺口 + Issue 号，不再让读者依赖编号。
- PR 未合并 ⇒ 矩阵措辞用「已实现、未进 develop」，不写"已支持"。
