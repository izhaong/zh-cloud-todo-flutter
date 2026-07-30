# Tasks: Todo 推荐任务与可靠性收口

- [x] T001 审计推荐、outbox、冲突、性能与无障碍现状并记录 Docs #55。
- [x] T002 写推荐与 outbox 幂等/冲突/退避失败测试。
- [x] T003 实现 Drift/Repository/SyncCoordinator 与可见恢复反馈。
- [ ] T004 写并实现桌面、移动、离线恢复、无障碍和视觉固定旅程。
- [ ] T005 执行完整测试与 DoD 审计；未满足项保持未勾选。

## 执行证据

- 2026-07-30：只读核对 JDK 25 后端 `zh-cloud-service/develop`，推荐契约固定为 `REPEATEDLY_RESCHEDULED`、`DUE_SOON`、`LONG_UNFINISHED`、`RECENTLY_ADDED`；Flutter 的 Drift 推荐缓存测试覆盖四类原因、服务端分数排序、失败保留缓存及成功空结果清理。outbox 新增真实 `TaskRepository → SyncChangeQueue → SyncCoordinator` 失败旅程：首次网络异常进入指数退避，重试复用原 `idempotencyKey` 与 `clientMutationId`，服务端接受后回写 `serverId`，后续 push 不再重复发送。既有版本冲突原因保留、冲突副本事务恢复、同步恢复横幅与 live region 测试共同闭环 T002/T003。定向执行 `recommendation_repository_test.dart` 与 `sync_retry_policy_test.dart`，7 项通过；全量 analyze 无错误，全量测试 530 项通过、25 项受保护环境条件跳过。
- 2026-07-17：T004 的一个可独立回滚无障碍增量已验证——同步恢复横幅的冲突恢复说明会以独立 live region 公告，确保冲突状态在动态出现时不只依赖可见文本。先运行同名 Widget 测试，旧实现因冲突说明语义缺少 `isLiveRegion` 失败；实现后运行 `nice -n 19 flutter test --concurrency=1 test/features/home/sync_recovery_banner_test.dart test/sync_retry_policy_test.dart test/task_conflict_recovery_repository_test.dart test/recommendation_repository_test.dart test/features/home/recommendation_panel_test.dart test/core/sync/connectivity_recovery_trigger_test.dart test/visual/todo_workspace_golden_test.dart`（23 项通过，含九张既有 golden）、`nice -n 19 flutter analyze` 和 `git diff --check`。T004 保持未勾选：桌面/移动人工无障碍、真实断网恢复、第二设备和完整旅程尚未执行。
