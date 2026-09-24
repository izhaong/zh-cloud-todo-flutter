# 044 看板分组：逐面判定与一处注释纠错 — 规格

源：`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/07-不同的视图查看任务/02-看板视图：分类管理任务.md`。
矩阵行 #15「看板视图：分类管理任务」本轮**不翻状态**（本轮无新实现，只做判定与注释纠错）。

## 逐面判定（引号内均为源页原文）
| 面 | 源页行 | 原文要点 | develop 现状（`origin/develop` = `a1d7733`） |
| --- | --- | --- | --- |
| 看板是清单的一种显示方式 | `:14` | 「看板并不是独立的功能模块，它是清单的一种显示方式。」 | 一致：看板是 `task_view_mode_tabs.dart` 的一个视图，任务数据走同一份清单过滤 |
| 跨列拖动调整分组 | `:64` | 「如果计划出现变动时，你可以点击任务直接拖动到其他分组中，方便你灵活地调整任务。」 | **已实现**：`kanban_view.dart:540` `LongPressDraggable` + `:398` `DragTarget`，写操作经 `onTaskMove`→`tasks_by_list_page.dart:380`；测试 `test/features/task/task_workable_views_test.dart:14`「看板拖到进行中列会请求共享任务写操作」、`:56`「看板跨列写入失败时显示可见反馈」 |
| 分组可按主题/按进度自定义 | `:99`-`:101` | 「当然，你还可以根据需求创建不同类别的分组：」「- 按主题：英语、政治、专业课…」「- 按进度：未开始、进行中、已完成…」 | **半**：分组实体本身有（`TodoTaskSection`，含 name/sort），但看板列**不读它** —— 列只认 `kanban_view.dart:33` 的构造参数 `orderedColumnIds`（默认 `['todo','doing','urgent','archive']`，语义是 `priority` 0/1/2/3）。注意不是「完全写死」：`tasks_by_list_page.dart:338` 传的是 `boardPreference.orderedColumnIds`，用户可**重排这四列的顺序**；但 `board_preference_repository.dart:58`/`:226` 用 `BoardViewPreference.defaultColumnIds.contains` 过滤，列 id 词汇锁死在四个 ⇒ 建不出「英语/政治」这种新列 |
| 管理分组入口（mobile） | `:115` | 「在任意清单中点击右上角「...」-「管理分组」进行重命名、新建和删除等操作。」 | 清单侧**已有**：`tasks_by_list_page.dart:1829`-`:1862`（`todo-section-create` + `rename`/`up`/`down`/`delete`，tooltip 原文「管理分组 <名称>」在 `:1849`）。看板侧**无**：列名不可改、不可新建列 |
| 管理分组入口（desktop） | `:108` | 「点击「分组」右上角的「···」，你可以对分组进行重命名、新建和删除等操作。」 | 同上：入口只挂在清单的分组条上，看板列头没有这个「···」 |

## 本轮改了什么
只改 `kanban_view.dart` 的文件头注释：旧注释写「拖拽改 priority 暂不实现（commit c2 摘要注明）」，
与 develop（`a1d7733`）上同文件的 `:398` `DragTarget` / `:540` `LongPressDraggable`
和 `tasks_by_list_page.dart:380` 直接矛盾 ⇒ 留着会让下一个人重新实现已存在的能力。
（本 PR 在文件头加了注释，同一位置在 PR 分支上已漂到 `:409`/`:551`，所以新注释里
**不再引用本文件的行号**，只引用符号名 `KanbanView.orderedColumnIds`。）
无行为改动：`kanban_view.dart` 的 diff 只落在 `///` 行。

## 取舍与被否方案
- **不在本轮做「列绑 TodoTaskSection」**：这是能做的（纯客户端），但它是**新界面行为**（列名、列集合、空列、
  拖到未分组列的落库语义都要定），按 objective「一轮只推一个可验证门槛」单独立轮，配红测与四件套自查。
  本轮只把它写成可执行的判定，避免下轮重新调研。
- **否掉「需要后端契约」的初判**：我一开始按「看板分组要新建 `todo_board_group` 实体」立了
  `zh-cloud-service` Issue #282，那是错的 —— 分组实体与同步通道在 develop 上都已经有了：
  `TodoTaskSection`（`app_database.dart:51` 表 + `:1048` `taskSectionByServerId`）与
  `sync_entities.dart:5` 的 `taskSection = 'task_section'`（`:31` 注册在同步实体列表里，文件头注明
  与后端 `TodoSyncServiceImpl.normalizeEntityType` 白名单一致）；`tasks_by_list_page.dart:1829`-`:1862`
  那套按 Key `todo-section-create` 索引的 rename/up/down/delete 分支就是它的 CRUD 入口。
  再立一份 `todo_board_group` 就是重复契约。已撤回该 Issue。
  （注意措辞：`todo-section-*` 是 Flutter `Key` 与 Drift 实体，不是 HTTP 端点名。）
- **否掉「只做注释纠错不开 PR」**：注释错误会误导实现，但改动虽小仍要走 PR（禁止直推主干）。

## 四件套自查
本轮**不新增界面能力**（只改注释 + 写 spec），四件套不适用；
下一轮做「列绑分组」时必须按四件套补齐，已在「仍缺」里点名。
