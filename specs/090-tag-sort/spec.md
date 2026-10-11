# 规格：任务按标签排序（矩阵 #21 面⑦，FL Issue #330）

- 判据源：嘀嗒帮助中心镜像《02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md》
  `:120`「## 标签排序」、`:122`「另外，你也可以在任务列表 -『···』-『排序』中，将任务按标签进行排序」。
  （develop 镜像里该页在 `02-功能指南/` 下；矩阵 #21 行引的 `01-任务/…` 是旧路径。）
- 纯客户端轮：排序是本地 Drift 行序，服务端无契约改动、零 SQL、零 DDL。

## 契约

1. `TaskSort` 追加 `tag` 档（枚举按 name 序列化，追加在末尾与存量偏好行兼容；
   未知档位名退回智能排序是既有行为，`tag` 成为合法名后不再触发退回）。
2. 排序键 = **标签在侧栏的展示顺序**（`isPinned DESC, sortOrder DESC, createdAt ASC`，
   与 `TagRepository.watchAll` 同序；TaskQueryRepository.filter 里自建位次表，两处口径必须同改，
   否则侧栏顺序与标签档排序会分叉）。
3. 任务取其**所有标签里侧栏位次最小者**（多标签任务跟着它最靠前的标签走）。
4. 「无标签 / 位次表缺该标签 / 两张表没到位」都记**末位哨兵**（`1 << 62`），
   与 `TaskSort.dueDate` 对空截止时间的处理同形；哨兵并列的任务回落既有兜底键
   （手工 `sortOrder`，再 `id`）。
5. 标签档**没有方向**：`hasDirection` 不含它，方向参数对它是 no-op（嘀嗒原文只给两档时间轴方向）。
6. 数据来源：页面用 `taskTagIndexProvider`（taskId → 标签集合）与 `tagsStreamProvider`
   （有序标签）；索引未就位时 `valueOrNull` 为 null ⇒ 全并列 ⇒ 兜底键接管，不转圈也不崩。
   （与服务端不同：这里不需要「标签条件生效才等索引」的强就位语义，排序退化是可接受的临时序。）

## 落点（锚点在 FL `origin/develop@d2d96bd` 基础上的本分支新字节）

- `lib/state/repositories/task_query_repository.dart`：`TaskSort.tag` 枚举值、
  `_tagRankOfTask`、`compareTodoTasks` 的 `taskTags` / `tagRank` 可选参数、
  `TaskQueryRepository.filter` 在 `sort == TaskSort.tag` 时自建位次表。
- `lib/features/task/widgets/task_workspace_header.dart`：
  `_TaskWorkspaceHeaderCommand.tag`、`sort` 映射、`TaskSortX.label` 的 `'标签'`、
  onPressed 空分支补 `tag` case。
- `lib/features/task/tasks_by_list_page.dart`：build 里由 `tagsStreamProvider` 建位次表，
  穿线到 `_visibleTasksInListOrder` 与 `_buildModeBody` → `_ListBody` → `_sortedItems`。

## 测试台账（test/task_sort_direction_test.dart，标签档组）

- 用例 6 条：侧栏序与无标签末位（1）、方向 no-op（1）、置顶优先压过标签档（1）、
  位次缺失与两表未到位的哨兵兜底（1）、菜单含「标签」且无方向行并带出 `TaskSort.tag`（1）、
  页面级按侧栏序重排（1，种子偏好直读绕开「标签」文案与快速添加栏撞车）。
- 变异探针：把比较器 tag 档临时改为恒 0 后，仓库级与页面级两条排序用例转红
  （`Some tests failed`，rc=1），还原后 15 条全绿——判据非恒假。
- 种子纪律：兜底键（sortOrder）与标签位次**反着种**，比较器被摘成 `=> 0` 时
  兜底排出的顺序与期望不同，断言不会假绿。
- 门禁：`flutter analyze` rc=0（0 issues）；`flutter test`（全仓）rc=0。

## 不在本轮范围

- 其他视图（看板 / 日历 / 象限）的排序语义不变：标签档与既有各档一样只在
  `compareTodoTasks` 的消费面（列表模式）生效。
- 标签档不新增服务端字段；`todo_tags.sort_order` 与置顶已在矩阵 #21 面⑥（FL !529）落地。
