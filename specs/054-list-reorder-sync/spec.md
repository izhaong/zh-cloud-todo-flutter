# 功能规格：清单排序（上移/下移）要能同步出去（specs/054 / FL Issue #341 / 矩阵 #19）

## 一、来源（逐字引用，基准 zh-cloud-docs `origin/develop`）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`

| 锚点 | 原文 | 用在哪条 |
| --- | --- | --- |
| `:78` | 「在侧边栏左滑某个清单，会出现「置顶」、「编辑」和「删除」3个选项。点击中间「编辑」图标，即可进入清单编辑页面。」 | 现状与本单范围切分 |

术语照抄：**「置顶」**。嘀嗒同一页还给了"排序由拖动决定"的形态（《01-列表视图》:47「支持拖动调整任务排序」是**任务**侧，
**清单**侧的排序能力在本页以「置顶 + 顺序」体现）⇒ 本面不把它读成"清单也能任意拖拽"，
**本仓已有实现也不是拖拽**（这一条第一版写错了）：清单排序的入口是「清单管理」页
`list_page.dart:40` 的 `_move(TodoList list, int delta)`，`:308` 与 `:313` 是两个
`IconButton(tooltip: '上移')` / `IconButton(tooltip: '下移')`；该文件内 `Draggable`、
`LongPressDraggable`、`ReorderableList`、`onPan` 命中数 **0**（`grep -cE` 实测）。
⇒ 能力名一律写**「清单排序（上移/下移）」**。这条不靠"全篇已统一"这种全称句担保（⚠️ 判据本身也会被破例：第 3 轮复核 N-1 量出原来的 `grep -rn "拖"` 有 7 处命中，破例的 2 处是 `plan.md:22`「不是拖延」这个无关词与 `spec.md:44` 的禁令句，都不在豁免集里 ⇒ 单字判据换成词组，实测 4 处命中且全落在豁免集内），自扫命令：`grep -rnE "拖拽|拖动" specs/054-list-reorder-sync test/state/list_repository_reorder_sync_test.dart lib/state/repositories/list_repository.dart`，剩下的每一处命中都必须是**引用旧措辞的历史句**（本节与 tasks 的复核表），出现活的断言即失项。逐字引用那格去掉了我自加的
三对 `**`（源页 `:78` 的字节里没有）。

## 二、现状（基准 `zh-cloud-todo-flutter origin/develop@9032005`，逐条实测）

```
git grep -n "Future<void> reorder" origin/develop -- lib       # lib/state/repositories/list_repository.dart:163
git grep -n "\.reorder(" origin/develop -- lib                 # 出 **2** 行：list_page.dart:61 与
        # tasks_by_list_page.dart:1472（后者是 TaskSectionRepository.reorder，**不同接收者**）
        # ⇒ 这条命令证不出"唯一调用点"（复核 B 项）。收口按接收者：
        #   git grep -n "reorderRepo\.reorder" origin/develop -- lib  → 恰好 1 行 list_page.dart:61
git grep -n "_queue.enqueue" origin/develop -- lib/state/repositories/list_repository.dart
        # create :85 / rename :103 / moveToFolder :141 / delete :181 / saveSmart :212  ⇒ **reorder 一个都没有**
```

- **本地改得动、跨端不成立**：`reorder` 只写 `todo_lists.sortOrder` + `updatedAt`，
  **不往 `todo_sync_changes` 登记任何一行**。同文件其余**五个**写方法每个都 `enqueue(entity: list, op: upsert, …)`，
  只有它漏了。⇒ 换设备 / 重装后按 pull 恢复出来的仍是旧顺序，而界面上"刚刚排好了"。
  这不是"缺功能"，是**已有功能的主张说过头**：矩阵 #19 的「清单可排序」这一格，
  在补上同步登记之前只能算**本地半面**。
- ⚠️ **而这条缺陷今天是"潜伏"，不是用户可复现的症状**（第 1 轮复核 C-2；我上一轮把静态读出的
  仓储缺陷直接写成了用户故事）：唯一调用点 `list_page.dart:61` 所在的 `ListPage` 在 `lib/` 内
  **零引用** —— `git grep -nE "(^|[^A-Za-z])ListPage\(" HEAD -- lib test` 只命中它自己的声明
  （`list_page.dart:18`）与 `test/m11_b2_list_widget_test.dart:24`，`app.dart:33` 路由表只有
  `/login` 与 `/` → `HomeShell`。**这个事实在同一个仓的 develop 上早就写死了**：
  `specs/026-todo-sidebar-list-management/spec.md:9-10`「但**没有任何可达入口**：`ListPage`
  在 `lib/` 内零引用」。⇒ 本面按**仓储层契约修复**交付，症状要等「清单管理」页有可达入口那天
  才会被用户遇到；任何"用户拖了会回滚"式措辞都不许进矩阵与规格。
- 顺带：`reorder` 的循环**没有包事务** ⇒ 中途抛（某条 id 已被删）会留下"前几条已改、后几条没改"的半截顺序。
  同文件 `moveToFolder:118` 是 `_db.transaction(() async { … })` 的先例。
  ⚠️ 本节所有行号都按上面声明的基准 `origin/develop@9032005` 给；指不到时按符号名搜，别信行号。

## 三、用户故事

1. 我在手机上用「下移」把「工作」排到「生活」后面，第二天在平板上打开，顺序应该还是那样。
   ⚠️ 这条**今天走不到用户面前**（入口页不可达，见「二」最后那条 ⚠️）⇒ 它写的是这层契约修好后
   应有的行为，不是当前可复现的症状。把它读成"现在就复现得了"就是上一版的错（复核 C-2）。
2. 排序登记同步时如果出错了，我要嘛整批顺序都是新的、要嘛整批都是旧的，不要一半新一半旧。

## 四、功能需求

- **FR-1 每条被改位次都登记一次 upsert**：`reorder(orderedIds)` 内，对每个 id 写完 `sortOrder` 后
  `enqueue(entity: SyncEntities.list, op: SyncOps.upsert, localId: id, serverId: row.serverId, payload: row.toJson())`，
  **payload 取自重新读回的那一行**（照 `rename` 的形，不自己拼 map；基准 `origin/develop@9032005` 上该形是 `100-108`——第 3 轮复核 N-4 订正：原先写 `100-107`，区间停在 `serverId:` 行，少包了 `payload: row.toJson()` 那一行）。
  位次为 `i` ⇒ `payload['sortOrder'] == i`。
- **FR-2 整批一个事务**：`reorder` 全体包在 `_db.transaction` 里（先例 `moveToFolder` 的事务，develop `:118`）⇒
  任一条抛错 ⇒ 所有 `sortOrder` 与所有 outbox 行都不留（FR-3 的断言据此才有力）。
- **FR-3 不吞掉不存在的 id**：`orderedIds` 里查不到的 id 不参与写、也不登记（清单可能刚被别的面删掉），
  但**不许**因为"少了一条"就把剩下的位次写歪 ⇒ 位次按**实际写成的那批**连续排。
  这条如果实现不了（比如非要保持传入下标）就在本文件登记取舍，不许悄悄改判据。
- **FR-4 不改任何界面**：排序入口（那对上移/下移按钮）、侧栏形态、左滑、置顶都**不在本面**。
  置顶需要服务端字段（见下），左滑是另一面 ⇒ 本面只修"排序登记同步"这一处缺陷，
  这样 `flutter test --tags golden` 的 9 张基线一张都不该动（无 UI 变更是本面的**约束**，不是巧合）。
- **FR-5 置顶（嘀嗒 `:78` 的那个词）本面不做，因为服务端没有这个字段**：
  `git ls-tree` + 读 `AppTodoListBaseVO` 只有 `name` 与 `sortOrder` 两个字段（无 pinned/置顶），
  `FL TodoLists` 表也**没有** `isPinned` 列（`app_database.dart:29-48`，只有 `TodoTasks` 有）⇒
  按「后端缺契约时先在 zh-cloud-service 修契约再动前端」，另立 service Issue，本面不碰。

## 五、四件套

1. **320px + 1.3 倍字号**：**不适用** —— 本面无 UI 变更（FR-4）。如实写理由，不编造测量。
2. **独立读屏语义**：**不适用** —— 同上。
3. **失败保留已加载数据**：这就是本面的主断言（FR-2/FR-3）：登记失败 ⇒ 顺序回到失败前，
   且列表仍能读出来（`getAll()` 返回旧顺序，不是空）。
4. **过期响应不覆盖新响应**：不适用 —— 本面是**写路径**，没有新增流；
   `watchAll()` 已按 `sortOrder` 排（`list_repository.dart:28`），不引入第二事实源。

> ⚠️ 本面不是"新增界面"，所以四件套里两条按"不适用 + 理由"处理。
> 这个判断如果复核不认，请指出哪一条在**只改仓储与同步登记**的情况下是可测的。

## 六、取舍

1. **位次以"实际写成的那批"为准**（FR-3）：传入 `['a','x','b']` 而 `x` 已不存在时，
   结果是 `a=0, b=1`，不是 `a=0, b=2`。理由：`sortOrder` 的语义是"同一可见序列里的位次"，
   留空洞会让下一次排序的读数依赖"曾经有多少条被删"，而 `watchAll` 只按值排、不看连续性 ⇒
   两种实现界面等价，但"无空洞"更好验证，也避免长期漂移成大整数。
2. **不做"只登记变化的那几条"**：整批 upsert 里包含位次没变的行（一次上移/下移会把该文件夹内所有行的 `sortOrder` 都重写）。
   代价是 outbox 行数 = 该文件夹内清单数；收益是"payload 与库内一致"这条判据可以无例外地成立。
   真嫌啰嗦时再做差量，但**那要另开一单**并给出"少登记但不能少收敛"的判据。
3. 不引入 `PUT /list/reorder` 这类新端点：清单是同步白名单实体，走既有 `list/upsert` outbox 即可
   （`moveToFolder` 就是这个先例，REST 特例只用于 folder 本身）。

## 七、验收（矩阵口径）

- 矩阵 **#19「用清单管理任务」**：本面把"清单可排序"从**只本地**修成**本地 + 可同步**。
  但该格还缺「置顶」与「左滑」两面（`:78` 的三项里我们只有编辑/删除，且入口是长按）⇒
  **状态不翻**（仍「部分」），只把缺口列按实测改窄，并写明「清单排序（上移/下移）的同步登记已由 specs/054 修掉，但入口页 `ListPage` 当前不可达 ⇒
  这一格的可见性缺口另算，不因为登记修好了就写成用户已经能感知」。
  **PR 未合并 ⇒ 措辞用「已实现、未进 develop」**（校验器不允许说明格出现「待合并」）。
