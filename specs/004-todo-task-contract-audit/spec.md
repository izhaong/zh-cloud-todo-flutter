# Feature Specification: Todo 任务契约审计与冻结

**Feature Branch**: `feat/89-todo-task-contract-audit`

**Created**: 2026-07-12

**Status**: B0 审计完成；远端 Action #3401 因仓库 Runner 队列未启动，未作为通过结果声明。

**Input**: 总控 Plan B0：以当前代码与测试为准，建立 Flutter 本地任务聚合与服务端契约的可审计基线；不交付新业务功能。

## User Scenarios & Testing

### User Story 1 - 可追溯能力判定 (Priority: P1)

产品与工程人员需要判断一个参考任务能力在唯一 Flutter 客户端是否真的可用，而非只看到历史矩阵或某个后端接口。

**Why this priority**: 后续所有任务功能的范围与验收都依赖这一基线。

**Independent Test**: 从 Docs 证据矩阵抽查快速添加、检查事项、多提醒、重复、搜索、看板、时间线，均可定位 Flutter 代码、服务端线索和明确缺口。

**Acceptance Scenarios**:

1. **Given** 某参考能力只有 REST 帮助类，**When** 审计该能力，**Then** 它被标为 `partial` 而非已完成。
2. **Given** 某能力具有当前测试，**When** 测试不覆盖离线与同步，**Then** 矩阵仍指出缺失层和目标 B 切片。

---

### User Story 2 - 稳定任务聚合边界 (Priority: P2)

开发人员需要使用一份明确契约，将 B1–B5 的任务、时间、组织和视图能力接入同一离线优先聚合。

**Why this priority**: 不冻结 ID、字段与同步边界会继续产生部分直连和数据漂移。

**Independent Test**: 对任务、提醒、重复、标签、检查事项、附件、活动和视图偏好逐一写明本地归属、服务端归属、同步策略与缺口。

**Acceptance Scenarios**:

1. **Given** Flutter 创建离线任务，**When** 该任务首次同步，**Then** 规格明确本地 UUID、服务端 ID 和幂等变更 ID 的职责。
2. **Given** 检查事项或附件需要写入，**When** B1 实施，**Then** 规格能指出必须新增的本地聚合与 outbox 边界。

### Edge Cases

- 历史 Plan 或废弃 React Todo 只提供线索，不能改变 Flutter 端到端状态。
- 服务端字段存在而 Drift 没有对应字段时，状态必须是 `partial`。
- 已批准视觉 golden 只证明视觉结构；不能证明数据与同步行为。

## Requirements

### Functional Requirements

- **FR-001**: 审计必须以 Docs 19 篇任务参考文档作为原子能力来源，并使每项映射唯一 B 切片或生态台账。
- **FR-002**: 每项能力必须分别记录服务端、Drift、Repository/use-case、Flutter、同步和测试证据。
- **FR-003**: Flutter Widget 不得被定义为直接调用后端 API 的合法核心写路径。
- **FR-004**: 本地任务聚合必须规定 UUID、`serverId`、revision 与 `clientMutationId` 的职责边界。
- **FR-005**: 检查事项、附件元数据、活动、提醒动作和重复动作的直连现状必须被列为明确缺口或有冻结的迁移策略。
- **FR-006**: 审计不得要求修改业务行为、重新设计视觉工作区或重建已批准 golden。

### Key Entities

- **TaskAggregate**: 用户可编辑的任务及其时间、组织、内容和状态。
- **Schedule**: 任务的全天、开始、结束、截止、时区、提醒与重复语义。
- **SyncChange**: 一个可重试、可幂等的本地变更及其服务端映射结果。
- **EvidenceRecord**: 一个参考能力的当前证据、缺口和后续交付归属。

## Success Criteria

### Measurable Outcomes

- **SC-001**: 19 篇任务参考文档的所有原子能力均有一条证据记录和明确归属。
- **SC-002**: 七类抽查能力均能在五分钟内定位到当前实现证据或明确缺口。
- **SC-003**: B1–B5 不再因字段、ID 或同步归属不明确而新增长期直连路径。
- **SC-004**: 已批准九张视觉基准在本 B0 中零变更。

## Assumptions

- Flutter 是唯一 C 端；废弃 React Todo 只作为历史线索。
- B0 只冻结契约和证据，不改变服务端数据库或 Flutter 运行时行为。
- `dida-task-capability-evidence.md` 是能力状态的 Docs 证据面，功能实现细节仍归本仓 Spec Kit。
