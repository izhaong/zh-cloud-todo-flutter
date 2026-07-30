# Feature Specification: Todo 可工作的列表、看板与时间线

**Feature Branch**: `feat/97-todo-workable-views`
**Created**: 2026-07-15
**Status**: 执行中；列表、看板与时间线的本地真实拖拽、来源隔离、共享清单只读写链路与任务重排 REST 契约已完成独立红绿闭环；真实 HTTP、双设备与固定设备旅程仍使 B4 保持 partial。
**Input**: 父仓 B4、B0 能力矩阵、Flutter #97、Service #185、Docs #53。

## User Scenarios & Testing

### User Story 1 - 在列表中真实整理任务 (P1)

用户可以在既有列表中选择、拖拽和批量编辑任务；变更先保存到 Drift 和 outbox，切换视图、重启和同步恢复后仍指向同一任务 UUID。

**Independent Test**: 内存 Drift 中对同一批任务执行列表内重排、跨分组移动和批量操作；断言任务字段、排序值、逐项结果和 outbox mutation 一致。

### User Story 2 - 在看板跨列移动 (P1)

用户可以按冻结分组字段在看板创建任务、在列内/列间拖拽，并获得只读、非法分组或同步失败的可见反馈。

**Independent Test**: Widget 旅程拖动任务跨列，断言共享 use-case 收到明确字段变更，未出现看板内 HTTP 调用或只改局部排序。

### User Story 3 - 在时间线上调整时间 (P1)

用户可以创建带时间段任务、移动任务和调整时长；全天、跨天、时区与冲突反馈复用 B2 语义。

**Independent Test**: Repository 与 Widget 固定时钟测试覆盖移动、调整、无日期和非法时间段，断言本地写入、outbox 和可见错误状态。

## Functional Requirements

- **FR-001**: 列表、看板和时间线只调用共享 Repository/use-case；Widget 不得直接调用 Todo HTTP API 或复制 B2 时间算法。
- **FR-002**: 任务视图的选择、分组、排序、时间线日/周/月尺度、缩放和折叠偏好按用户、source type 与 source key 持久化；切换清单不得串用偏好。
- **FR-003**: 任务移动、重排、批量和时间编辑必须在 Drift transaction 内完成本地写入与 outbox 入队；失败、重试、冲突和只读反馈可见。
- **FR-004**: 看板跨列产生明确任务字段 mutation；列内排序使用独立拖拽手柄，不能与整卡长按跨列手势竞争。时间线移动/缩放产生 B2 兼容的时间字段 mutation，不以仅前端坐标作为真相；日尺度下非全天任务移动按小时解释，周/月尺度与全天任务按天解释。
- **FR-005**: 列表/看板/时间线对同一任务 UUID 保持选择和刷新规则；智能清单或筛选结果中的禁止结构操作有解释，不静默失败。
- **FR-006**: 不重做 `specs/002-todo-visual-fidelity/` 的工作区结构或九张基准；视觉变化需明确批准。
- **FR-007**: `PUT /task/reorder` 的直连契约仅用于 API 契约/真实 HTTP 对照，请求体固定为 `listId + items[{id, sortOrder}]`；Widget 的核心重排写路径仍必须经过共享 Repository/use-case 与 outbox。
- **FR-008**: 时间线空白时段创建必须产出明确 `startAt/endAt/dueAt/allDay`：日尺度为一小时非全天任务，周/月尺度为一天的全天任务；创建必须复用 `TaskRepository` 的 Drift/outbox 原子写链路。
- **FR-009**: 无开始、结束和截止日期的任务必须与远期任务分离到“安排任务（无日期）”；拖入时间格后通过共享 view-action Repository 原子写入完整时段、全天语义与 task outbox，只读拒绝不得产生部分写入。

## Success Criteria

- **SC-001**: 每个视图都有 Repository、outbox/sync、Widget 与 Service/API 定向证据，且使用同一任务 UUID 验证跨视图一致性。
- **SC-002**: 固定桌面与移动旅程覆盖创建、编辑、拖拽、离线恢复和失败反馈；未运行前保持 `partial`。
- **SC-003**: `flutter analyze`、本规格定向测试、`git diff --check` 通过；真实设备、服务端和第二设备证据单独记录。

## Boundaries

- B1/B2/B3 均未完成端到端验收；B4 只能先做独立可回滚的审计、契约、测试和最小实现，不得标为 verified。
- 推荐、冲突收口、性能和无障碍全量结论属于 B5；外部生态集成不属于 B4。
