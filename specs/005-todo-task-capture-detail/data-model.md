# B1 本地聚合模型

| 实体 | 主键与映射 | 核心字段 | 写入规则 |
| --- | --- | --- | --- |
| TaskAggregate | local UUID → serverId | title、Markdown、list、priority、schedule、状态 | Drift transaction 后 task outbox |
| ChecklistItem | local UUID → serverId | taskId、title、completed、sortOrder | 同事务 + checklist outbox |
| TaskAttachment | local UUID → serverId | taskId、localPath、remoteUrl、state、retryCount | 元数据 outbox；二进制独立队列 |
| TaskActivity | local UUID → serverId | taskId、kind、payload、createdAt | 本地可读；同步 append 幂等 |
| TaskTemplate | local UUID → serverId | name、aggregate snapshot | 明确保存/应用结果 |
| TaskCaptureDefaults | `TASK_CAPTURE/defaults` view preference | defaultListId、defaultPriority | Drift transaction + view_preference outbox；跨端清单使用 serverId 映射 |

附件状态仅允许 `queued` → `uploading` → `uploaded` 或 `failed`；failed 可回到 uploading，queued/failed 可删除。
