# Feature Specification: Todo 提醒、重复与时间语义

**Feature Branch**: `feat/93-todo-task-time-semantics`
**Created**: 2026-07-13
**Status**: 执行中；独立契约与本地链路可并行，B1 真实双端集成仍保持未完成。
**Input**: 总控 Plan B2、B0 冻结的 `Schedule` 边界、Docs `todo/02_技术设计/任务模块/B2-提醒、重复与时间语义验收.md`。

## User Scenarios & Testing

### User Story 1 - 离线编辑确定的时间语义 (P1)

用户可以离线设置日期、开始和结束时间、全天、跨天与固定时区；离开、重启和恢复网络后，本地任务仍表示同一个时间语义。

**Independent Test**: 在 UTC+8 创建 23:30 至次日 01:00 的任务、全天任务和 `America/Los_Angeles` 固定时区任务；关闭重开 Drift 数据库后，Repository 返回相同字段，outbox 只保留一条任务变更。

### User Story 2 - 管理多个可恢复提醒 (P1)

用户可以为一个任务管理单提醒、多提醒、结束提醒、持续提醒和稍后提醒；离线操作先落库并在恢复网络后同步，失败时保留可重试状态。

**Independent Test**: 为同一任务写入两个不同 `fireAt` 的提醒，执行稍后 10 分钟和持续提醒确认；验证 `TodoReminders`、outbox 与 UI 状态一致，重复 push 不重复创建远端提醒。

### User Story 3 - 配置可解释的重复、跳过和补做 (P1)

用户可以设置每天、每周、每月、每年、工作日和自定义重复，并对一个 occurrence 执行跳过或补做，不改变其它 occurrence。

**Independent Test**: 对每种频率生成本地规则载荷，写入一个跳过和一个补做记录；同步映射后验证规则 UUID、serverId 与 occurrence 标识不混淆。

## Functional Requirements

- **FR-001**: `TaskRepository` 的时间写入必须在同一 Drift 事务更新任务的 `dueAt`、`startAt`、`endAt`、`allDay`、`timeZone` 和 `fixedTimezone`，然后 enqueue 一个 `task` 变更；Widget 不得直接调用时间 API。
- **FR-002**: 全天任务只表达日期范围；有 `startAt` 与 `endAt` 的非全天任务必须满足 `endAt` 晚于 `startAt`；跨午夜以次日 `endAt` 表达，禁止隐式截断为同一天。
- **FR-003**: 固定时区任务保留 IANA 时区标识与墙上时间；非固定时区任务保留创建时区但允许显示层按设备时区转换，转换不得修改 Drift 原值。
- **FR-004**: 每个提醒规则都有本地 UUID、可空 `serverId`、任务本地 UUID、`fireAt`、`anchorType`、`offsetMinutes`、`status`、`firedAt` 与 `clientMutationId`；创建、修改、删除和持续提醒确认均先落库再进入 `reminder` outbox。收件箱的完成、忽略和稍后是派发动作，必须使用独立的本地 UUID、派发 serverId、动作类型、可选 minutes 与 `clientMutationId`，不得把派发 ID 写入提醒规则实体。
- **FR-005**: 一个任务可有多个提醒；同一任务的同一 `clientMutationId` 只对应一个本地提醒，失败、等待、同步成功和删除状态必须在详情与提醒收件箱显示一致。
- **FR-006**: 重复规则支持 `DAILY`、`WEEKLY`、`MONTHLY`、`YEARLY`、`WEEKDAY` 与 `CUSTOM`，并保存 interval、weekdays、monthDay、startAt、untilAt、countLimit、repeatMode 与时区；未知频率不得写入 outbox。
- **FR-007**: 跳过和补做记录以规则 UUID 与 occurrence 时间为键；跳过不生成补做，补做不删除原 occurrence，重复执行同一动作必须幂等。
- **FR-008**: `SyncCoordinator` 必须在任务 serverId 已映射后推送提醒和重复规则，在重复规则 serverId 已映射后推送跳过/补做；拉取顺序必须先任务、再规则、再 occurrence 动作。
- **FR-009**: 详情与提醒收件箱只能经 Repository/use-case 读取和写入；派发 ID 用于完成、忽略和稍后，提醒规则 ID 只用于持续提醒配置。保留 `specs/002-todo-visual-fidelity/` 的工作区与九张批准 golden，不重新设计视觉结构。

## Success Criteria

- **SC-001**: UTC+8 的跨午夜、全天和固定时区 fixture 在 Drift 重启、Repository 读取与 sync payload 中字段完全一致。
- **SC-002**: 单提醒、多提醒、结束提醒、持续提醒和稍后提醒各有 Repository、SyncCoordinator 和 Widget 测试，所有核心写测试均断言 outbox 状态。
- **SC-003**: 六类重复频率、跳过和补做各有有效与无效输入测试；重复 push 不产生重复本地或服务端映射。
- **SC-004**: `flutter analyze` 与本规格列出的定向测试在低资源命令下通过；未执行的桌面/移动/测试环境旅程保持未完成。

## Assumptions and Boundaries

- B1 的详情保存、附件和第二设备回放仍在独立 Draft PR 中；本规格只使用 B0 已冻结的任务 UUID、serverId、revision 与 mutation 边界。
- OS 级跨重启通知调度、位置提醒、日历 OAuth、语音、手表和小组件不属于 B2。
- Gitea Actions runner 当前不可执行；`queued` 不是通过或阻塞结论，所有 B2 结论必须引用本地命令、mock 契约测试或测试环境 API 结果。
