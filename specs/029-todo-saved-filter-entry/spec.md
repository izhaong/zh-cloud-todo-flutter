# 已保存过滤器可用（矩阵 #22 核心功能）

范围裁定（2026-09-23，产品拍板）：**只做核心功能**，付费/升级、教育优惠（教师·学生认证）、
课表导入、服务端 NLP 与 MCP 等 AI 生态**不纳入对齐范围** ⇒ 本切片是裁定后的第一个核心项。

对齐矩阵 #22「过滤器：随心所欲筛选你想看的任务」。

## 嘀嗒口径（先读了对应那一页）

`02-功能指南/01-任务/08-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md`：

- 入口是**侧栏**：移动端「侧边栏左下角『添加』→ 选择『过滤器』」；桌面端在侧栏「过滤器」分组上
  悬停点 + 号新建（未在侧栏显示时，去「设置 → 智能清单 → 过滤器 = 显示」）。
- 普通筛选维度：**清单名称、标签、日期、优先级、关键词**；高级筛选才有「且 / 或」布尔分组。
- 术语就叫「过滤器」，不叫「智能清单」⇒ 本仓原来的「保存为智能清单」是自造同义词，本切片改回嘀嗒叫法。

## 现状（实地证据，2026-09-23，基线 = develop `a1d7733`）

- **真表与同步链路早就齐了，只有 UI 零消费**：
  `lib/core/db/app_database.dart` 定义 `todoFilters`（`conditionJson` / `sortOrdersJson` /
  `isSmart` / `isPinned` / `sortOrder`），第 13 号迁移补齐列（`:579-587`，`schemaVersion` 现为 22）；
  出站本地化 `lib/core/sync/sync_coordinator.dart`、入站 `_upsertLocalFilter` `:1975-2016`、
  tombstone `:1346-1349`；远端契约 `lib/core/api/todo_api.dart` `POST /filter/apply`。
  ⇒ **服务端已有的过滤器今天就在往本地库里落，只是没人渲染**。
- 仓库层 `lib/state/repositories/filter_repository.dart` 只有 `save()`，无 list/watch/delete；
  `providers.dart` 里没有 `filterRepositoryProvider`（`grep -rn "FilterRepository" lib` 除自身声明外零命中）。
- 侧栏早就有一行入口：`lib/features/shell/sidebar.dart`（`Key('todo-sidebar-row-filters')`、
  文案「筛选器」）→ `home_shell.dart:451` push 的 `_FiltersPage` 是**写死 3 条假条目的静态占位**
  （`今日任务 / 已完成 / 已过期`，无 `onTap`、不读任何 repository）。
- 另一条「智能清单」路是**半成品死链路**（本切片不复用它，理由见下）：
  `list_repository.dart:190-219` 的 `saveSmart()` 把条件**只塞进 outbox payload**，本地没有任何列存条件；
  `SmartListFilter.fromListName`（`:260-275`）在 `lib`+`test` 里**零调用**，且 `default` 分支对自定义名返回空条件；
  `list_page.dart:197-201` 点已存智能清单**只弹 SnackBar**；侧栏「智能清单」分组是 7 个硬编码 `_SmartRow`
  （`sidebar.dart:89-196` + `section.dart:42` 的封闭枚举），不渲染 `smart:` 行。

## 为什么不复用「智能清单」而接真表

复用要同时修四处断点（条件无本地列、解析函数是死码、侧栏不渲染、点击不跳转），还要跟封闭枚举与
`smart:` 前缀较劲；而真表的 schema、迁移、双向同步、`/filter/apply` **全都已经在了**，缺的只有
「仓库补两个方法 + 一个 provider + 一处 UI」。嘀嗒口径也要求过滤器是**可命名、可删、可同步的一等数据行**，
不是清单名里的一个前缀 hack。

## 功能需求

- **FR-001** 筛选面板的保存动作改为「保存为过滤器」，条件写入 `todoFilters`（含 outbox `filter/upsert`），
  不再创建 `smart:` 清单。
- **FR-002** 条件形状对齐服务端契约（`TodoFilterConditionsDO`：`listIds / tagIds / dateRange{preset,from,to} /
  priorities / statuses / keyword`）。**存不下的维度必须在对话框里点名**（文件夹、负责人、
  已过期与将来这两个 preset），不得静默存成半个过滤器。
- **FR-003** 「筛选器」页从静态占位换成真列表：名称 + 可读条件摘要；一条都没有时给空态；
  原来的 3 条假条目必须消失。
- **FR-004** 点一条过滤器 → 忠实还原成筛选条件并**真的作用到任务列表**；无法忠实还原的条件
  （多优先级 / 未知 preset / 契约外的键）标成「本机暂不支持套用」且该行不可点，不套一半。
- **FR-005** 删除要二次确认（取消不写库），确认后删本地行并入 outbox `filter/delete`。
- **FR-006** 四件套：320px + 1.3 倍字体长名称不溢出（档位要在页面自己的 context 上自检）、
  读屏能读到名称与摘要、删除按钮有**独立可聚焦**的语义名（不能只靠垃圾桶图标）、加载失败有错误态。

## 边界与非目标

- **「且 / 或」高级筛选不在本轮**：`applyTaskFilter`（`features/task/tasks_by_list_page.dart`）与
  `TaskQueryRepository.filter` 都是硬编码 AND，`TodoFilterConditions` 也没有布尔分组字段 ——
  做它要改条件 schema + 新迁移 + 服务端同步改，单开切片。
- 过滤器的**重命名与改条件**不在本轮（只有新建 / 列出 / 套用 / 删除）。
- `lib/features/efficiency/efficiency_hub_page.dart` 与「智能清单」旧链路本切片都不删（只登记）。
