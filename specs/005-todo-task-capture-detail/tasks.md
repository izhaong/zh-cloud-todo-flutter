# Tasks: Todo 任务收集与完整详情

## Phase 1: 契约与基础

- [x] T001 对齐 Service #179 的 B1 契约并更新 `specs/005-todo-task-capture-detail/contracts/capture-detail-contract.md`。
- [x] T002 为 checklist、attachment、activity、template 的 Drift 表、迁移和 outbox 载荷写失败测试，目标 `test/task_capture_detail_repository_test.dart`。
- [x] T003 实现本地聚合 Repository/use-case，修改 `lib/state/repositories/task_repository.dart` 与新增子聚合 Repository；每个核心写均在事务后 enqueue。

## Phase 2: US1 离线快速收集

- [x] T004 [US1] 为批量粘贴、空标题、默认值与日期解析写 Widget/Repository 测试，目标 `test/features/shell/quick_add_bar_test.dart`。
- [x] T005 [US1] 通过 use-case 改造 `lib/features/shell/quick_add_bar.dart`，实现逐项结果和可撤销解析。

## Phase 3: US2 完整详情

- [x] T006 [US2] 为 Markdown、标签和检查事项离线回显写测试，目标 `test/features/task/task_detail_pane_test.dart`。
- [x] T006a [US2] 为检查事项补齐专用拖拽手柄和真实指针旅程；`TaskRepository.reorderChecklistItems` 原子校验完整 UUID 顺序、更新 Drift 并逐项入队，只读失败不产生局部写或 outbox，详情页保持原顺序并展示 Repository 原因。
- [x] T007 [US2] 改造 `lib/features/task/task_detail_pane.dart`，移除核心写直连 API，接入聚合 use-case。

## Phase 4: US3 附件与活动

- [x] T008 [US3] 为附件四态、重试、删除和活动顺序写测试，目标 `test/task_capture_detail_repository_test.dart`。
- [x] T008a [US3] 仅接收同账号私有任务的服务端 activity pull：任务先于活动应用，按 activity server ID 幂等写入现有 Drift 缓存；活动不得进入 outbox、push、冲突写回或 tombstone 删除。Mock pull 证据落在 `test/sync_coordinator_activity_test.dart`；真实 Service A/B 回放已记录在 Docs #47。
- [x] T008b [US3] 服务端 attachment pull 必须在父任务已映射后按 server ID 写入本地元数据，attachment tombstone 仅删除本地元数据且不创建 outbox；验证 `test/sync_coordinator_attachment_test.dart`、完整 `flutter test` 和 Docs #47 的真实 Service A/B 回放。
- [x] T009 [US3] 实现附件队列与详情状态 UI，保持 002 结构不变。

## Phase 5: 跨层验收

- [x] T010 增加离线重启、恢复网络、幂等上传和双端回显旅程；更新 Docs #47 的证据链接。
- [x] T011 运行 `flutter analyze`、完整 `flutter test` 和批准 golden；仅将有实际输出的条目标记完成。
- [x] T012 为固定移动验收增加稳定的登录、快速添加、详情保存和同步状态语义锚点，并跑通不影响宿主网络的离线恢复旅程。
- [x] T012c [US1] 固化隔离 macOS runner 的 Flutter `integration_test/b1_desktop_gui_journey_test.dart`，为既有桌面快速添加输入增加稳定 Key，并以 Widget 锚点测试与 `flutter analyze` 验证可执行性；测试账号可从进程环境读取，避免作为命令行参数暴露。
- [x] T012d [US1] 在 macOS target 实跑 `integration_test/b1_desktop_gui_journey_test.dart`，验证密码登录、桌面快速添加、Markdown 保存和详情回读；结果 `00:19 +1: All tests passed!`。
- [x] T012a [US1] 区分会话启动时的网络验证错误与明确令牌失效：离线时保留安全会话和本地 Drift 访问，明确拒绝仍清除会话；验证 `test/core/auth/auth_gateway_test.dart`、`test/state/session_state_test.dart`、`flutter analyze` 与完整 `flutter test`。
- [x] T012b [US1] 读取可注入的初始连接状态并用变化流仅在 `none → online` 时触发既有同步协调器；验证 `test/core/sync/connectivity_recovery_trigger_test.dart`、`flutter analyze` 与完整 `flutter test`，但不把该单测替代真实设备网络恢复验收。
