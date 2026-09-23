# 工作区排序补「修改时间」档（矩阵 #20）

## 背景与缺口来源

嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》的「如何使用排序」一节列出四种排序方式：
按时间、按优先级、按创建时间（**支持从旧到新 / 从新到旧**）、按修改时间（**同样支持双向**）。
第 14 轮轨道 A 取证（基准 `origin/develop@a1d7733`）实测本端：

- 档位枚举 `lib/state/repositories/task_query_repository.dart:22` 是
  `enum TaskSort { smart, priorityDesc, dueDate, title, createdAt }` ⇒ **没有「修改时间」这一档**；
- 数据不缺：`updatedAt` 早在表里（`lib/core/db/app_database.dart:43`），Drift 行对象上就有该列，
  测试夹具也在喂它（`test/support/todo_visual_fixture.dart:128/139/146/153/411`）；
- 菜单是**由枚举自动生成的**：`lib/features/task/widgets/task_workspace_header.dart:154-159`
  用 `for (final candidate in TaskSort.values)` 产 `PopupMenuItem`，
  档位文案来自 `TaskSortX.label`（`:32-39`）。

⇒ 补这一档**不需要服务端改动**：工作区排序是本地比较器（`compareTodoTasks`），
排序偏好走 `TaskSortPreferenceRepository`（按 `TaskSort.name` 编解码，
`task_sort_preference_repository.dart:109`），新增枚举值自动可存可读。

## 功能需求

- FR-1 「修改时间」出现在任务工作区右上角「...」的排序菜单里，措辞照嘀嗒（叫「修改时间」，
  不叫「更新时间」「最近修改」），位置紧跟「创建时间」之后 —— 菜单由 `TaskSort.values` 生成，
  所以顺序=枚举声明顺序，**不重排既有档位**（避免无谓 diff 与既有偏好位移）。
- FR-2 选中后列表按 `updatedAt` **从新到旧**排；同 `updatedAt` 时仍落到既有的稳定兜底键
  （手工顺序 `sortOrder` → `id`），置顶优先规则不变。不引入「智能」档的语义变化。
- FR-3 偏好可持久化并回读：保存 `updatedAt` 后重新读取得到同一档；旧存量值（含未知值）
  仍按既有规则退回 `smart`，不做数据库迁移。
- FR-4 四件套：新菜单项让「...」比原来多一行 ⇒ 320px + 1.3 倍字体下菜单不溢出、
  该项是独立可读屏节点（文字即 label）、选中后回调把档位带出；
  「失败保留已加载数据」与「过期响应不覆盖新响应」在本切片**没有对应的异步链路**（排序是纯本地比较，
  偏好的读写复用已验收的 `TaskSortPreferenceRepository` 链路）⇒ 不为凑四件套编造判据。
- FR-5 不改服务端契约。但**记下一个相邻缺口**（不属本切片）：已保存过滤器（矩阵 #22）的
  `sortOrdersJson` 在服务端有字段白名单，
  `TodoFilterServiceImpl.java:487-500 resolveSortColumn` 只认
  `priority / due_at / create_time / sort_order / is_pinned / title`，
  **没有 `update_time`** ⇒ 想让「按修改时间」也进已保存过滤器，必须先按规则 5
  在 Service 加白名单映射（一行）再改客户端，不能由客户端硬发未支持字段。本轮另开 Issue 记这笔债。

## 取舍与被否方案

- **本轮只做「多一档」，不做方向切换**：嘀嗒页面写明创建时间/修改时间各有「从旧到新 / 从新到旧」，
  但**没说方向在界面上怎么选**（点同一项切换？二级菜单？独立图标？）；本端菜单是单层
  `PopupMenuButton`，加方向控件就是自创交互。
  被否：先猜一种交互做出来 —— 违反北极星「不自创交互」。要做需先在嘀嗒 App 上核一眼交互（人工）。
  因此本切片的验收边界只到「档位存在且排序正确」，方向作为仍缺写明。
- **不改 `smart` 档的行为**：智能档现在是 `bySelectedField => 0`（只靠置顶 + 手工顺序 + id）。
  被否：把修改时间塞进智能档 —— 会改变既有已验收档位的语义。
- **不在 `TaskSort` 里加 `updatedAtDesc/updatedAtAsc` 两个值**：方向未定就拆档，
  等方向定了又要改枚举与已存偏好。当前值 `priorityDesc` 的名字已暗示方向，
  但排序菜单里只有一档「优先级」⇒ 沿用「一档一字段、方向单档默认」的现状。
- **不动 `todo_filter.sortOrders` 多键链路**：矩阵 #20 那行还写着「BE 多键排序未接」，
  那是 #22/服务端侧的活，混进来会让本 PR 变大且需要 SQL/契约评审。
