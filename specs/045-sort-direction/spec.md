# 045 · 清单排序方向（从旧到新 / 从新到旧）

## 依据（嘀嗒原文，唯一事实源）

`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/03-用分组和排序管理任务.md`
（`origin/develop` 版，全页 292 行）：

- `:136`「打开清单，点击右上角「...」-「分组排序」，即可选择排序方式。」⇒ 方向属于同一个「分组排序」面板，不另开入口。
- `:169`「## 按创建时间排序（新增）」→ `:173-176`「支持：- 从旧到新；- 从新到旧。」
- `:185`「## 按修改时间排序（新增）」→ 同样列这两个方向。
- `:141`「## 按时间排序」、`:153`「## 按优先级排序」**没有**「支持：…」这一段。
- `:203` 场景写「**排序：创建时间（从新到旧）**」⇒ 界面措辞用「从新到旧 / 从旧到新」，不写「降序 / 升序」。

矩阵行：**#20「用分组和排序管理任务」**（`zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md`）。
本面在 develop 上缺的就是 Issue #320 那一格：档位有、方向没有。

## 现状与差距

- 档位存在：`lib/state/repositories/task_query_repository.dart` 的 `enum TaskSort { smart, priorityDesc, dueDate, title, createdAt, updatedAt }`，
  文案在 `lib/features/task/widgets/task_workspace_header.dart` 的 `TaskSortX.label`。
- **方向不存在**：比较器里 `createdAt` / `updatedAt` 两行写死 `right.compareTo(left)`（即只有「从新到旧」），
  `lib/` 内 `从旧到新`、`ascending`、`toggleSort` 全 0 命中。

## 需求

- **FR-1 方向是一等档位**：`TaskSortDirection { newestFirst, oldestFirst }`，label 分别是「从新到旧」「从旧到新」。
  `newestFirst` 排第一且是默认值 —— 它等于本轮之前唯一的行为。
- **FR-2 只有两档时间轴有方向**：`compareTodoTasks` 只在 `createdAt` / `updatedAt` 上读方向；
  `smart` / `priorityDesc` / `dueDate` / `title` 四档切方向结果不变（嘀嗒没给它们方向）。
- **FR-3 方向按清单存偏好，跨重启与跨端保留**：`TASK_SORT` 那行的 `valueJson` 多存一个 `direction` 键。
  存量行没有这个键 ⇒ 读回 `newestFirst`，**不能**连带把档位退回 `smart`。
- **FR-4 界面接上**：排序菜单在当前档位是时间轴时给两行方向，带当前项勾选；非时间轴不给。
  选完立刻重排列表，且重进清单（新 State）仍是那个方向。
- **FR-5 不越界**：不改 `todoViewPreferences` 的表结构（不加列、不 bump `schemaVersion`）；
  不改看板 / 时间线 / 日历的分组轴；不动侧栏与 dock；不新增 push 路由。

## 取舍（拿不准时按这里走，别重开）

1. **方向存进 JSON 而不是加数据库列。** 加列要 `schemaVersion` 23 + `onUpgrade` `addColumn`，
   而这份偏好本来就是整列 `valueJson` 存 JSON（`sort` 也在里面）。加列的收益是零，成本是一次迁移。
2. **默认值必须是 `newestFirst`。** 否则"没存过偏好的清单"会在升级当场换序，
   用户没做任何操作却看到列表重排 —— 那是回归，不是新能力。
3. **不做「再点一次同一档位翻转方向」。** 很多应用这么做，嘀嗒原文写的是"支持：从旧到新 / 从新到旧"
   两项可选（`:203` 把它写成"排序：创建时间（从新到旧）"这种可选状态）。
   隐式翻转是隐藏交互，读屏也念不出"现在是哪个方向"，所以显式给两行 + 勾选。
4. **方向不进 4 个非时间档。** 见 FR-2。给它们方向就是自创能力；用例反向钉住（探针 PB）。
5. **只有列表形状的视图吃方向。** 看板按优先级分列、时间线按日期分组，各有自己的轴；
   本轮只把方向交给 `_visibleTasksInListOrder` 与 `_ListBody`（工作区的平铺顺序），其余视图的 `sort` 通道原样不动。
6. **未知 `direction` 取值只回退方向，不牵连档位。** 跨端拉回的 JSON 里若出现我们不认的方向名，
   连带退回 `smart` 会把用户的档位也弄丢（探针 PD 的第二半）。

## 四件套（新增/改动的表面）

| 件 | 本面怎么做 | 落在哪条用例 |
| -- | ---------- | ------------ |
| 320px + 1.3 倍字号（在该表面自己的 context 上实测） | 菜单是独立路由，取 `find.text('从旧到新')` 自己 context 的 `textScaler`；两行方向都要求 `hitTestable` | 「320px + 1.3 倍：方向行排得下、各自可命中、有独立语义」 |
| 独立读屏语义 | 两行方向各是独立 `Text` 节点，用 `bySemanticsLabel(RegExp('从新到旧'/'从旧到新'))` 各命中一次 | 同上 |
| 失败保留已加载数据 | 偏好保存失败走既有 `SnackBar` 路径，不改内存态：列表仍按用户刚选的方向显示 | 页面级用例走的是成功路径；失败路径沿用 `_changeSort` 已有分支，未新增吞异常 |
| 过期响应不覆盖新响应 | 方向是本地偏好、单一写入者（同一清单一次一个 `save`），无并发读回 | 不适用，理由记在这里而不是空勾 |
