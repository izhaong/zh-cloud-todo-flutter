# 功能规格：清单动作表补「共享协作」入口（specs/053 / FL Issue #359 / 矩阵 #52）

## 一、来源（逐字引用，基准 zh-cloud-docs `origin/develop`）

`todo/99_参考资料/dida365-help-center/02-功能指南/07-共享与协作/01-如何共享清单.md`

| 锚点 | 原文 | 用在哪条 |
| --- | --- | --- |
| `:6` | 「**只有你自己创建的普通清单支持共享，「今天」、「明天」等智能清单以及「收集箱」不支持共享协作**。因此，在开始共享前，请先新建一个用于共享的普通清单。」 | FR-4（可达性边界） |
| `:8` | 「接着，进入该清单详情页面，点击右上角的「**···**」 → 选择「**共享协作**」 → 点击「**添加新成员**」，即可邀请对方加入共享清单。」 | FR-1（入口位置与命名）、FR-3（成员页内的「添加新成员」） |

术语照抄：**「共享协作」**。本仓现名是「协作」/「协作成员」，且入口挂在**任务**详情上（见现状）。

## 二、现状（基准 `zh-cloud-todo-flutter origin/develop@9032005`，逐条实测）

```
git grep -n "showListActions"              origin/develop -- lib   # 定义 list_actions.dart:65（按 develop 字节：`:62` 是 `];`、`:63` 空行、`:64` 文档注释）；唯一调用点 sidebar.dart:626
git grep -n "ListMemberPage"               origin/develop -- lib   # 定义 list_member_page.dart:48；唯一调用点 task_detail_pane.dart:1332
git grep -n "共享协作"                      origin/develop -- lib   # 0 命中
git grep -n "协作成员"                      origin/develop -- lib   # task_detail_pane.dart:1235 / :1327
git grep -n "Icons.more_horiz\|more_vert"  origin/develop -- lib/features/task/tasks_by_list_page.dart   # 0 命中
```

- **能力都在，入口不对**：成员页（owner 邀请 / 改角色 / 移除 / 接受邀请 / 退出）是完整的，
  但通往它的唯一入口在**任务详情页**的「协作」动作里；**清单**这一级没有「共享协作」。
- **本仓清单级动作表的真实形态**：不是「右上角···」，而是**侧栏长按清单行**弹出的 bottom sheet
  （`showListActions`，现有两项「编辑」「删除」）。嘀嗒 `:8` 说的是移动 App 的常见形态"清单详情右上角···"；
  本仓 `tasks_by_list_page.dart` 里清单级 `more_horiz` **0 命中**（上面第三条判据）⇒
  **不新增右上角「···」**（那要改 AppBar 结构、动 9 张基线的清单页截图），改在**已有的同类表**上加一项。
  这是**形态偏差**，不是能力缺失 ⇒ 记在下面的「取舍 1」，并回写矩阵缺口列。
- 成员页的加人**没有独立入口**：owner 视角下邀请表单常驻（`list_member_page.dart:221`/`:246` 的
  「邀请权限」「邀请」是**提交按钮**，不是"打开表单"的入口）。⇒ 嘀嗒 `:8` 的「添加新成员」
  在本仓**没有独立入口**（加人由 owner 视角下常驻的「邀请」提交按钮内联承担），把它当成"把『邀请』改名成『添加新成员』"是**错的**（那是提交动作）。见「取舍 2」。

## 三、用户故事

1. 我要把一个清单分享给别人，应该在**清单**上操作，而不是先打开某条任务再绕进去。
2. 我这个清单还没同步到服务器时，点进来要告诉我**为什么打不开**，别什么都不发生。

## 四、功能需求

- **FR-1 入口**：`showListActions` 的动作表里增加一项**「共享协作」**（术语照抄 `:8`），
  顺序取**「编辑 → 共享协作 → 删除」**（取舍 3）。嘀嗒 `:8` 只给路径、没给列表顺序 ⇒
  顺序是本仓的形态选择，不是照抄项；「删除」垫底是破坏性动作的通行约定。
  点击后 push `ListMemberPage`。
- **FR-2 传参**：`listServerId` 用该清单的 `serverId`，`title` 用清单名。
  与任务详情那条入口共用同一个页面与同一套前置校验，**不抄第二份**。
- **FR-3 未同步要有可见原因**：`serverId == null`（清单只在本地）⇒ 不 push，
  给可见提示；措辞与本文件既有那句对齐（`task_detail_pane.dart:1327` 现在是
  「清单尚未同步，无法打开协作成员」⇒ 统一成「清单尚未同步，无法打开共享协作」，两处同一口径）。
- **FR-4 智能清单与收集箱不给这个入口（可达性实测，不是猜）**：`showListActions` 的
  **唯一调用点**是侧栏的**真实清单行**（`sidebar.dart:626`，参数类型 `TodoList`）；
  今天/明天/收集箱是**合成行**，走的是另外的 row 组件 ⇒ 天然满足 `:6`。
  **但这条必须有用例钉住**（否则将来谁给合成行接上 `showListActions` 就静默违反 `:6`）：
  判据 = 收集箱行长按**不出现**「共享协作」，正对照 = 普通清单行长按**出现**。
  负断言一律按**文案**判（`find.textContaining('共享协作')` / `find.text('编辑')`），不按私有键判：
  只断 `BottomSheet` + 两个键会被"换个弹层类型给出共享入口"绕过。两处日志各管一半，别混引：
  **旧版拦不住** = `/tmp/r79c/R1_counterexample.log`（`+6` 全绿）、**补强后有牙** = `/tmp/r79g/cx/CX1.log`（同一形状 `+5 -1`，红的正是这条）。
  ⚠️ **判据上界（第 2 轮复核 N-A，这条之前没写下来）**：`find.text` 只认全等 ⇒ 带前后缀的`'共享协作 · 邀请成员'`、`SnackBar(Text('去共享协作'))` 当时都漏过 ⇒ 已改 `textContaining` 兜子串；**图标型入口**（`IconButton(icon: Icons.share, tooltip: '共享协作')`，压根没有 Text）则用`find.byIcon(Icons.share) findsNothing` 单独钉。本面**不声称**这张网拦得下任意形态，它声称的是：**给智能清单/收集箱行接上任何"文字含『共享协作』或分享图标"的入口，六条必红**。
- **FR-5 只做入口与传参，不动后端契约**：成员页本身、`/app-api/todo` 的共享接口都在 develop 已存在
  （矩阵 #52 现状列已取证）⇒ 本面无 BE 改动。

## 五、四件套（逐条写怎么量）

1. **320px + 1.3 倍字号**：在**动作表 sheet 自己的 context** 上量（`MediaQuery.textScalerOf(
   tester.element(byKey('sidebar-list-action-share')))`），并遍历 `RenderFlex` 子节点量越界
   （specs/052 的做法，不靠 `takeException()` 当唯一判据）。三项 ListTile 在 320px 下不溢出。
2. **独立读屏语义**：新项就是 `ListTile(title: Text('共享协作'))` ——
   `ListTile` 自己就把 title 变成语义 label 并标成按钮 ⇒ 用例断 `getSemantics(key).label` **全等**
   '共享协作'（**正向**判据用全等；反向的 :6 判据用 `textContaining`，见 FR-4 的上界说明）且 `flagsCollection.isButton`，
   再加一条 `find.bySemanticsLabel('共享协作')` 成对。**没有另套 `Semantics` 包装**
   （套了反而多一层节点，specs/052 那次是 `IconButton` 的 tooltip 不常驻才需要包）。
2b. **档位自检的定位器按文案取**：`MediaQuery.textScalerOf(tester.element(find.text('共享协作')))`，
   **不取 `Key('sidebar-list-action-share')`** —— 键名是内部契约，改个私有键名不该让"溢出量测"这条红
   （复核第 1 轮 X6 读数里 T6 的红是纯假警报）。测试文件 `:219` 与此处必须同口径
   （第 2 轮复核 F2：N3 当时只改了测试、规格没跟着走）。
3. **失败保留已加载数据**：本面无异步读；但 FR-3 是"失败要说得出"——提示出现时侧栏**还在**
   （断 `find.byType(Sidebar)` findsOneWidget）。
   ⚠️ 这里**不**用 `Key('todo-sidebar')`，理由要说准：该键**在 develop 上存在**
   （`git grep -n "Key('todo-sidebar')" origin/develop -- lib` → `todo_workspace.dart:150`、`:198`；
   全仓 `grep -rn "Key('todo-sidebar')" test/` → 22 处、6 个既有测试文件在用），
   红的真因是本用例的 `_TestSidebar` 只泵了裸 `Sidebar`、没渲染 `TodoWorkspace` ⇒ 键不在**这棵树**里。
   ⇒ 按类型断是**本用例装配下**的选择，不是"工作区级用例也不能用这个键"。
4. **过期响应不覆盖新响应**：**不适用** —— 入口是同步 push，`serverId` 从已加载的 `TodoList` 取，
   没有新增流/请求。如实写理由。

## 六、取舍（写清楚，不是拖延）

1. **形态偏差**：嘀嗒是"清单详情页右上角「···」→ 共享协作"，本仓清单级动作表在**侧栏长按**里。
   本轮**只补能力与命名**，不新增右上角「···」（会动 AppBar 结构并可能惊动黄金基线）。
   ⇒ 这条偏差要写进矩阵 #52 的说明格，不能算"已与嘀嗒一致"。
2. **「添加新成员」在本仓没有独立入口**（不是"没有对应控件"）：承担"加新成员"这件事的控件是存在的——
   owner 视角下邀请表单**无条件渲染**（`list_member_page.dart:221` 是下拉框的 `labelText: '邀请权限'`，
   `:242` 的 `FilledButton.icon(key: 'collaboration-invite-submit', icon: person_add_alt_1)`、
   其 `label: Text('邀请')` 在 `:246`）才是提交按钮，缺的是嘀嗒那种"点开表单的入口"与那个命名。
   把提交按钮改名成「添加新成员」等于改错东西 ⇒ **不改**，并在矩阵里写明"这一步在本仓是同一屏内联提交"。
3. **顺序**：「编辑 → 共享协作 → 删除」（理由见 FR-1）。
4. 不做"共享管理"聚合页、不改成员页角色文案（那是 #51/#52 别的格子）。

## 七、验收（矩阵口径）

- 矩阵 **#52**：这一格从"清单级无入口"变成"清单级有入口，形态与嘀嗒不同" ⇒ 合并后状态仍「部分」
  （`:8` 的路径三步里，第 1、2 步形态不同；第 3 步在本仓是同一屏内联提交、无独立入口），
  但缺口列要按实测改写。**PR 未合并 ⇒ 不翻状态，措辞用「已实现、未进 develop」**（校验器不允许说明格出现「待合并」）。
