# Tasks: Todo 推荐任务与可靠性收口

- [x] T001 审计推荐、outbox、冲突、性能与无障碍现状并记录 Docs #55。
- [x] T002 写推荐与 outbox 幂等/冲突/退避失败测试。
- [x] T003 实现 Drift/Repository/SyncCoordinator 与可见恢复反馈。
- [ ] T004 写并实现桌面、移动、离线恢复、无障碍和视觉固定旅程。
- [ ] T005 执行完整测试与 DoD 审计；未满足项保持未勾选。

## 执行证据

- 2026-07-30：T004 的推荐并发刷新可靠性增量完成红绿闭环。可控阻塞 API 的 Widget 失败测试先复现初始化刷新未结束时连续点击会把请求数从 1 增至 3，存在旧响应覆盖新缓存/状态的风险；实现后同一 `RecommendationPanel` 复用进行中的刷新 Future，请求完成才释放下一次刷新，测试同时证明完成后仍可正常发起第 2 次请求。T004 保持未勾选：桌面/移动人工无障碍、真实断网、第二设备和完整固定旅程尚未执行。
- 2026-07-30：T004 的推荐恢复反馈与语义隔离增量完成红绿闭环。旧实现刷新失败仅静默保留 Drift 缓存，面板容器还会把标题、刷新按钮、失败状态和任务项合并成单一可点击语义节点；新增失败测试先分别复现“无恢复反馈”和“语义节点合并”。实现后刷新失败会继续显示缓存，并用独立 live region 播报“刷新推荐任务失败，已保留上次结果”；重试成功清除失败状态。面板声明显式子语义节点，刷新按钮和每条推荐任务可独立导航。`recommendation_panel_test.dart` 3 项通过。T004 仍未勾选：桌面/移动人工无障碍、真实断网、第二设备和完整固定旅程尚未执行。
- 2026-07-30：清理不可达的原生增强演示页并从设置页提供真实入口；今日、重要和置顶任务改为消费当前账号 Drift 数据，锁屏通道只接收已同步的服务端 ID，离线重要任务只显示数量而不伪造 ID。平台通道未注册时五类调用安全降级。Dart MCP 定向 5 项和全量 582 项测试通过，25 项受保护真实环境测试按条件跳过；全量静态分析无错误。Android/iOS 等平台侧真实 Widget、Share 与 URL Scheme handler 仍未实现，因此本次不把原生系统能力计作完成，T004/T005 保持未勾选。
- 2026-07-30：在 `develop` 当前代码上通过 Dart MCP 以单并发执行全量测试，560 项通过、25 项受保护真实环境测试按显式条件跳过；全量静态分析无错误。跳过项集中在 B1/B2 真实同步、附件与 B3 文件夹/标签/搜索/筛选/批量/排序/跨账户权限 A/B，不计作通过。结合 B2 仍缺可运行的固定 macOS 开发签名应用与 Android 设备、B4 仍缺时间线真实拖拽设计及真实 HTTP/双设备/固定设备证据，并且规格要求 B0–B4 先全部达到门槛，T004/T005 保持未勾选。本次只确认“本地完整测试与 DoD 审计已执行”，不声明 Jenkins、真实设备或最终 DoD 成功。
- 2026-07-30：只读核对 JDK 25 后端 `zh-cloud-service/develop`，推荐契约固定为 `REPEATEDLY_RESCHEDULED`、`DUE_SOON`、`LONG_UNFINISHED`、`RECENTLY_ADDED`；Flutter 的 Drift 推荐缓存测试覆盖四类原因、服务端分数排序、失败保留缓存及成功空结果清理。outbox 新增真实 `TaskRepository → SyncChangeQueue → SyncCoordinator` 失败旅程：首次网络异常进入指数退避，重试复用原 `idempotencyKey` 与 `clientMutationId`，服务端接受后回写 `serverId`，后续 push 不再重复发送。既有版本冲突原因保留、冲突副本事务恢复、同步恢复横幅与 live region 测试共同闭环 T002/T003。定向执行 `recommendation_repository_test.dart` 与 `sync_retry_policy_test.dart`，7 项通过；全量 analyze 无错误，全量测试 530 项通过、25 项受保护环境条件跳过。
- 2026-07-17：T004 的一个可独立回滚无障碍增量已验证——同步恢复横幅的冲突恢复说明会以独立 live region 公告，确保冲突状态在动态出现时不只依赖可见文本。先运行同名 Widget 测试，旧实现因冲突说明语义缺少 `isLiveRegion` 失败；实现后运行 `nice -n 19 flutter test --concurrency=1 test/features/home/sync_recovery_banner_test.dart test/sync_retry_policy_test.dart test/task_conflict_recovery_repository_test.dart test/recommendation_repository_test.dart test/features/home/recommendation_panel_test.dart test/core/sync/connectivity_recovery_trigger_test.dart test/visual/todo_workspace_golden_test.dart`（23 项通过，含九张既有 golden）、`nice -n 19 flutter analyze` 和 `git diff --check`。T004 保持未勾选：桌面/移动人工无障碍、真实断网恢复、第二设备和完整旅程尚未执行。
