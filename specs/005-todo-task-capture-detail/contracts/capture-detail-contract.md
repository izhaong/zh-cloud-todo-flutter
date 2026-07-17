# B1 客户端契约

- UI 调用 use-case，不持有服务端 ID 或 API client。
- `createCapture` 返回逐项 `created`、`skipped-empty`、`parse-rejected` 或 `failed`，不静默丢失输入。
- `saveTaskAggregate` 在一个本地事务内保存任务与修改过的子实体，并产生带 `clientMutationId` 的 outbox 记录。
- `TASK_CAPTURE/defaults` 复用 `view_preference` 的本地 UUID、`valueJson` 与 outbox；跨端仅传服务端可解析的默认清单编号，拉取后再映射回本地 UUID。
- 快速添加以当前显式清单和本次输入为最高优先级；未显式覆盖时才采用用户保存的默认清单和优先级。
- 详情中的清单选择只持有本地 UUID；点击保存时由 `TaskRepository.update` 在 Drift 更新 `listId` 并产生 task outbox，sync 层再把清单引用映射为服务端 ID。
- 检查事项改名或调整 `sortOrder` 只能经 `TaskRepository.updateChecklistItem`：先在 Drift 事务写本地聚合，再以 `isChecklistItem` task 载荷入 outbox；Widget 不直接访问 checklist API。
- `QuickAddRequest` 只携带本次输入、日期、优先级、标签和是否采用本地日期解析；UI 不自行写 API，任务与标签均由 Repository/outbox 处理。
- 附件 UI 必须显示本地状态及 retry/delete；上传错误不得回滚任务正文、标签或检查事项。附件上传后以基础 URL 登记，服务端将其关联到同一私有签名 URL 的文件资产；附件同步只接收已映射父任务的 `attachment` 变更，tombstone 只删除本地元数据且不产生新的 outbox。
- 私有任务模板是不可编辑的任务快照，只经标准 sync 的 `template` upsert/delete、accepted、pull 与 tombstone 传播；客户端不得回退到专用 REST 创建或手动刷新旁路。
- 活动仅由服务端成功应用任务写入后派生；客户端只接收 `activity` pull，必须在父任务之后按服务端活动 ID 幂等写入本地缓存。活动绝不进入 outbox、push、冲突写回或 tombstone 删除路径。
- B1 真实同步的可写实体为 task、list、view preference、checklist、attachment 与 template；activity 是只读 pull 实体。客户端不把本地 UUID 作为跨端业务引用传给服务端，accepted 后再回填服务端 ID。
- 所有 API 响应经 Repository 映射，冲突或不可恢复错误变为可显示的领域结果。
