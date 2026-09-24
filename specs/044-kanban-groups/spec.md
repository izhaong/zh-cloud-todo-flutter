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

---

# 后半轮（Issue #313 / PR 见 Gitea）：看板列已绑定 `TodoTaskSection`

上面那张表里「分组可按主题/按进度自定义」那一行，本轮从**半**变成**已实现（待合并）**。
锚点一律用符号名而不是行号：新代码不在这页写作时的 `origin/develop` 上，写行号必漂。

## 改了什么（四处，全是客户端接线）
| 面 | 源页行 | 落地 |
| --- | --- | --- |
| 列集合=分组集合、列名=分组名 | `:99`-`:101` | `KanbanView.sections` 非空 ⇒ `KanbanView._sectionColumns`：一列一个分组，列标题取 `TodoTaskSection.name` |
| 跨列拖动换分组 | `:64` | 该模式下列的 `DragTarget` 走 `KanbanView.onTaskSectionMove` ⇒ `TaskViewActionRepository.moveKanbanTaskToSection`，**只写 `sectionId`，不碰 priority/completed** |
| 拖动分组排序 | `:129` | `KanbanView.onSectionOrderChanged` ⇒ 既有的 `TaskSectionRepository.reorder`（不新增仓储方法） |
| 分组内「+」新建任务 | `:141`/`:148` | 分组模式每列都给「+」，`TaskQuickAddSheet.sectionId` → `TaskRepository.create(sectionId:)`（`_requireSectionInList` 已在校验） |
| 拖到「未分组」 | 源页**没写** | `sectionId = NULL`。措辞沿用 app 内既有说法：`TasksByListPage._deleteTaskSection` 的确认文案「分组内任务不会删除，将回到“未分组”」 |

清单**没有**分组时仍是 priority 四列：列集合、列名、"拖进/拖出归档会写 `completed`" 的语义都没动
（正向对照用例：`没有分组时仍是 priority 四列`）。
**但有一处固定四列路径上的可见改动，不能含糊过去**：「+」的 tooltip 从 `新建任务` 变成 `在未开始新建任务`。
它不是分组模式专属 —— 因为读屏要求同一屏里多个同形按钮可分辨，而 develop 上同列头其它 tooltip
本来就是 `调整${列名}列`/`折叠${列名}`/`展开${列名}` 这种带列名的写法，这次是向那个既有写法对齐。
用例 `固定四列的「+」tooltip 也带上列名（本轮确实改了这一处）` 把它钉住。

## 取舍要写在台面上
1. **切换条件是推断的**：嘀嗒 `:217`-`:219`「需要先在清单右上角的「排序」中将「分组」改为「自定义」，才可以管理分组」
   ⇒ 分组只是"当前分组方式"的一种。本仓还没有可选的分组轴（那是矩阵 #20 的缺口），
   所以这里用「该清单有没有分组」当开关。**这不是嘀嗒原文的交互**，等 #20 补上分组轴后应改成显式选轴。
2. **分组模式没有折叠能力，但菜单项不消失**：`BoardViewPreference` 的列 id 词汇被
   `board_preference_repository.dart` 的 `defaultColumnIds.contains` 锁死 ⇒ 分组列的折叠状态存不进去，
   所以这一模式**不给** `onColumnCollapsedChanged` 回调。
   列头菜单里的「折叠<列名>」仍按 develop 的形态**灰显**（`enabled: onCollapsedChanged != null`），
   而不是整项删掉 —— 第 1 轮复核抓到"删掉"会连带改掉智能清单（`listId == null` 时该回调本就是 null）
   那条老路径的菜单形态，而同菜单里的「左移/右移」仍是灰显保留，删一项会自相矛盾。
   两条用例分别钉住：`分组模式忽略折叠：偏好里塞分组 id 也不会收起该列`（列宽仍是 260）、
   `分组模式的列头菜单仍列出「折叠」项但不可用（与固定四列一致）`（折叠 enabled=false、右移 enabled=true）。
3. **分组模式没有「归档」列，已完成任务留在自己的分组列**。这是这条分组方式的必然结果，
   不是漏实现：priority 四列里的「归档」= `completed || priority >= 3` 的聚合，
   而按分组开列时列就是分组，没有"归档"这个分组。
   **代价要说清**：分组模式下**看板上改不了完成状态**（拖出归档列曾是唯一入口），
   只能回卡片勾选。嘀嗒原文没写"按分组开列时已完成任务去哪"，所以这里不猜它有归档列，
   只把本实现的选择记下来；`分组模式已完成任务留在自己的分组列，不聚合成归档列` +
   仓储用例 `已完成任务拖进分组列后 completed 仍为 true（分组模式不改完成状态）` 钉住现状。
4. **`sectionId` 悬空（分组被删/属于别的清单）不算异常**：这类任务落到「未分组」列而不是从看板上消失。
   用例 `指向不存在分组的任务落在未分组列而不是消失` 钉住它。
   （`TaskSectionRepository.delete` 本来就会把任务清空回未分组，这里是防脏数据兜底。）
5. **过期顺序不覆盖新数据是"拒绝"而不是"合并"**：`TaskSectionRepository.reorder` 要求提交
   清单内的**全部**分组 id，否则抛 `必须包含清单内的全部分组`。所以"点左移时列表里已经多了一个新分组"
   这种竞态会以 `分组排序失败，请重试` 可见失败收场（沿用 `_moveTaskSection` 的既有措辞），
   而不是把新分组悄悄排到最后。
6. **列头读屏**：三个分组的「+」如果都叫 `新建任务`，读屏分不出是哪一列 ⇒ tooltip 改为 `在<列名>新建任务`
   （嘀嗒源页只写「点击「分组」右上角的「+」」，没有给出标签文案，所以这里不冲突）。
7. **仍然不需要改契约**（重申前半轮否掉 Issue #282 的结论，这次是正面确认）：
   push 侧 `SyncCoordinator._resolvePayloadRefs` 已把 task payload 的本地 `sectionId` 换成服务端 id；
   服务侧 `TodoSyncServiceImpl.applySyncTaskSection` + `resolvePayloadEntityRef(…, "sectionId", "section_id")`
   接收并校验，`TodoTaskMapper.clearSectionId` 负责删分组时清空任务。

## 一处实测出来的溢出（改动把它从潜伏变成可达）
`320px + 1.3 倍字号` 下分组列头 `Row` **溢出 141px**（`RenderFlex overflowed by 141 pixels on the right`）。
priority 四列时代列名是固定短词（未开始/进行中/紧急/归档）所以看不出来，分组名由用户输入、长度不受控。
⇒ 列标题改成 `Expanded` + `maxLines: 1` + `TextOverflow.ellipsis`，
用例 `320px + 1.3 倍字号下分组列头不溢出` 钉住（先红后绿，红测原文就是上面那句 141px）。

## 仍缺（不谎称完成）
- 看板**列头没有「···」→ 重命名/新建/删除分组**入口（`:108`/`:115` 的看板侧）。
  现在只能在清单的「管理分组」里改，改完列标题会跟着变（列名直接读 `TodoTaskSection.name`），
  但"在看板上就地建列"这一步还没有。
- 「未分组」列的位置固定在最后，嘀嗒没说该在哪，也没说要不要这一列 —— 见上面取舍 1。
