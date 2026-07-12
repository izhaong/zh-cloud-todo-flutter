# B1 客户端契约

- UI 调用 use-case，不持有服务端 ID 或 API client。
- `createCapture` 返回逐项 `created`、`skipped-empty`、`parse-rejected` 或 `failed`，不静默丢失输入。
- `saveTaskAggregate` 在一个本地事务内保存任务与修改过的子实体，并产生带 `clientMutationId` 的 outbox 记录。
- `TASK_CAPTURE/defaults` 复用 `view_preference` 的本地 UUID、`valueJson` 与 outbox；跨端仅传服务端可解析的默认清单编号，拉取后再映射回本地 UUID。
- 快速添加以当前显式清单和本次输入为最高优先级；未显式覆盖时才采用用户保存的默认清单和优先级。
- 附件 UI 必须显示本地状态及 retry/delete；上传错误不得回滚任务正文、标签或检查事项。
- 所有 API 响应经 Repository 映射，冲突或不可恢复错误变为可显示的领域结果。
