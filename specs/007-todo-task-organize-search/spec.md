# Feature Specification: Todo 海量任务组织与检索

**Feature Branch**: `feat/95-todo-task-organize-search`
**Created**: 2026-07-15
**Status**: 本地实现与 Flutter/Service 冻结契约已完成；固定双端 GUI、移动设备性能/弱网 P95 与 Jenkins 外部证据保持 `partial`。
**Input**: 父仓总控 Plan B3、B0 能力证据矩阵 CAP-25 至 CAP-29、Service #183、Docs #51。

## User Scenarios & Testing

### User Story 1 - 离线组织自己的任务 (P1)

用户可以离线创建和整理文件夹、普通清单、标签与任务层级，修改在重启后保留，并在网络恢复后按依赖顺序同步。

**Independent Test**: 在临时 Drift 数据库中创建文件夹、清单、两级标签和五层任务树；对子任务执行移动、缩进、反缩进、置顶和手动排序；重启数据库后验证相同本地 UUID、父子关系、排序与 outbox 依赖仍存在。

### User Story 2 - 从大量任务中稳定定位 (P1)

用户可以在离线状态搜索任务、清单和标签，并组合状态、日期、优先级、清单和标签条件；同一 fixture 的结果和排序在重启后稳定。

**Independent Test**: 导入 1,000 条固定 UUID fixture，使用标题、正文、清单和标签关键词以及多个过滤条件搜索；断言结果按冻结的多键排序、无重复 ID、结果可打开正确任务。

### User Story 3 - 批量处理且可解释 (P1)

用户可以选择多个任务并批量修改清单、优先级、标签、日期、完成状态或置顶状态；个别不可编辑任务不会使其它项目静默丢失。

**Independent Test**: 对包含有效、本地未同步、只读和不存在 ID 的选择集执行批量编辑，断言每个任务都有 success、skipped 或 failed 结果；成功项本地事务和 outbox 均存在，失败项不污染其它任务。

## Functional Requirements

- **FR-001**: Flutter Widget 只经 `Repository` 或 use-case 读取和写入组织、搜索、层级、排序和批量编辑；不得在页面中直接调用 Todo HTTP API。
- **FR-002**: 文件夹、普通清单、智能清单缓存、标签、任务标签关联、过滤器、视图偏好和任务层级都使用本地 UUID 作为关联键；任何依赖服务端 ID 的 push 必须等待 parent entity 的 serverId 映射。
- **FR-003**: 所有核心写入在一个 Drift transaction 内写本地实体和 outbox；任务树操作以 `task` mutation 表达，标签关联以 `task_tag` mutation 表达，列表/标签/过滤器/视图偏好使用各自 sync entity，文件夹 REST 特例仍通过 outbox 排队并提供失败重试状态。
- **FR-004**: 任务只能有一个 `parentTaskId`，父任务必须属于当前本地账户；禁止自引用、循环引用和超过五级深度。缩进、反缩进、拖拽移动、解除关联与删除父节点必须在本地先验证，并形成可重放 mutation。
- **FR-005**: 多键排序固定为：置顶、用户选择的字段序列、手动排序值、任务 UUID。相等键不得依赖当前列表索引；排序和分组偏好按 source type、source key 与用户隔离持久化。
- **FR-006**: 全局搜索返回 task、list 和 tag 三类结果，使用同一标准化关键词规则；结果必须可定位到本地聚合。B3 中搜索索引只存可离线读取的标题、正文摘要、清单名称和标签名称，不上传用户检索词。
- **FR-007**: 普通和高级过滤器支持 B0 已冻结的状态、日期、优先级、清单、标签与负责人条件；负责人使用服务端稳定 `assigneeUserId`，可空名称只作为本地展示缓存，不能作为关联键。日期比较复用 B2 的时区契约。过滤器组合、智能清单和搜索结果均为只读结果集，不允许以列表拖拽改变不确定归属的任务结构。
- **FR-008**: 批量操作返回逐项结果，至少区分 `success`、`skipped`、`failed`；部分失败保留已成功的本地事务和 outbox，并在 UI 中显示失败任务及可重试原因。
- **FR-009**: 新增或变更 Drift schema 必须有升级迁移与文件型数据库重启测试；不得删除用户任务正文、附件、检查事项或既有 B1/B2 数据。不得重新设计 `specs/002-todo-visual-fidelity/` 已批准的视觉结构或更新 golden 基线。

## Success Criteria

- **SC-001**: 1,000 条确定性 fixture 的搜索、组合过滤、多键排序和层级展开结果在同一平台上稳定；测试记录首个结果可交互的测量方式和实际值。
- **SC-002**: 文件夹、清单、标签、任务层级、排序和批量编辑各自有 Repository、SyncCoordinator 与 Widget 测试，测试均断言本地写入和 outbox。
- **SC-003**: 循环、六级层级、跨账户/只读任务、智能清单结构重排和未知筛选字段均有拒绝测试与可见反馈。
- **SC-004**: `flutter analyze`、本规格的定向测试和 `git diff --check` 使用低资源命令通过；设备、真实服务端和第二设备旅程未实际运行前维持 `partial`。

## Assumptions and Boundaries

- B1 仍未完成真实双端详情验收；B3 仅实施能独立回滚的组织/检索链路，不能以本地测试替代 B1/B3 集成结论。
- B2 的时区比较规则尚未完成 UI 端到端验收；需要日期过滤时只能复用其已冻结字段语义，并把真实时区旅程保留为跨切片门槛。
- 看板跨列编辑与时间线拖拽属于 B4；本规格只提供这些视图可复用的组织、排序和选择 use-case。
- 语音、微信、邮件、手表、小组件、位置提醒、Siri、Notion、MCP 和外部日历集成不属于 B3。
