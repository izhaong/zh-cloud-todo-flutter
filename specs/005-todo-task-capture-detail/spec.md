# Feature Specification: Todo 任务收集与完整详情

**Feature Branch**: `feat/91-todo-task-capture-detail`
**Created**: 2026-07-12
**Input**: 总控 Plan B1、Docs 能力矩阵、B0 冻结契约。

## User Scenarios & Testing

### User Story 1 - 离线快速收集 (P1)

用户可输入标题或粘贴多行文本，查看并覆盖智能日期识别与默认值，然后立即在离线本地任务列表看到结果。

**Independent Test**: 断网创建含解析日期、默认清单和优先级的单条及多条任务，重启后不丢失；空行不产生任务。

### User Story 2 - 可完整编辑的任务详情 (P1)

用户可编辑 Markdown 正文、日期、清单、优先级、标签、检查事项和任务操作；保存后详情、列表和本地聚合一致。

**Independent Test**: 创建任务后离线编辑正文、标签和检查事项，离开再返回详情时全部回显，写操作无 Widget 直连 HTTP。

### User Story 3 - 可靠的附件与活动 (P2)

用户可添加附件，看到 queued/uploading/failed/uploaded，失败可重试或删除；复制、放弃、模板、分享和活动有可解释结果。

**Independent Test**: 模拟上传失败后重试或删除未上传附件，任务正文和检查事项保持不变；活动按发生顺序可见。

## Functional Requirements

- FR-001: 快速添加支持单条、批量粘贴、可撤销的日期解析和每项可覆盖默认值；空白标题不得落库。
- FR-002: 每个核心写入必须在 Drift 事务保存聚合和 outbox 变更，再由 Repository/use-case 返回 UI 结果。
- FR-003: 任务详情支持 Markdown 原文保存及安全预览，支持清单、优先级、标签和检查事项的离线编辑。
- FR-004: 检查事项、附件元数据、活动和任务操作必须有本地 ID、服务端映射、队列状态、失败重试或明确不可离线边界。
- FR-005: Widget 不直接调用 `TodoRestApi`、`ChecklistApi`、`TagApi` 或上传 API。
- FR-006: 不改变已批准 002 工作区结构或九张 golden；新增交互只进入既有内容区和移动详情入口。

## Success Criteria

- SC-001: 断网创建并编辑含 Markdown、标签、检查事项的任务，重启后 100% 从本地回显。
- SC-002: 批量粘贴不创建空标题，所有可创建项在一次确认中逐项报告结果。
- SC-003: 附件四态及重试/删除均有 Widget 与 Repository 测试；恢复网络后成功项只上传一次。
- SC-004: B1 目标能力均有 Service 契约、Drift、Repository、Flutter、sync 和测试证据，未验证项保持 partial。

## Assumptions and Boundaries

- 时间的全天、跨天、时区、提醒和重复深层规则由 B2 冻结；B1 只保留兼容的详情字段和入口。
- 微信、邮件、语音、小组件等为生态能力，不属于本规格。
- 服务端整数 ID 只在同步层映射；UI 与 Repository 使用本地 UUID。
