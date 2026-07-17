# Tasks: Todo 任务收集与完整详情

## Phase 1: 契约与基础

- [ ] T001 对齐 Service #179 的 B1 契约并更新 `specs/005-todo-task-capture-detail/contracts/capture-detail-contract.md`。
- [ ] T002 为 checklist、attachment、activity、template 的 Drift 表、迁移和 outbox 载荷写失败测试，目标 `test/task_capture_detail_repository_test.dart`。
- [ ] T003 实现本地聚合 Repository/use-case，修改 `lib/state/repositories/task_repository.dart` 与新增子聚合 Repository；每个核心写均在事务后 enqueue。

## Phase 2: US1 离线快速收集

- [ ] T004 [US1] 为批量粘贴、空标题、默认值与日期解析写 Widget/Repository 测试，目标 `test/features/shell/quick_add_bar_test.dart`。
- [ ] T005 [US1] 通过 use-case 改造 `lib/features/shell/quick_add_bar.dart`，实现逐项结果和可撤销解析。

## Phase 3: US2 完整详情

- [ ] T006 [US2] 为 Markdown、标签和检查事项离线回显写测试，目标 `test/features/task/task_detail_pane_test.dart`。
- [ ] T007 [US2] 改造 `lib/features/task/task_detail_pane.dart`，移除核心写直连 API，接入聚合 use-case。

## Phase 4: US3 附件与活动

- [ ] T008 [US3] 为附件四态、重试、删除和活动顺序写测试，目标 `test/task_capture_detail_repository_test.dart`。
- [ ] T008a [US3] 仅接收同账号私有任务的服务端 activity pull：任务先于活动应用，按 activity server ID 幂等写入现有 Drift 缓存；活动不得进入 outbox、push、冲突写回或 tombstone 删除。Mock pull 证据落在 `test/sync_coordinator_activity_test.dart`，真实 Service A/B 与设备旅程完成前保持未勾选。
- [ ] T009 [US3] 实现附件队列与详情状态 UI，保持 002 结构不变。

## Phase 5: 跨层验收

- [ ] T010 增加离线重启、恢复网络、幂等上传和双端回显旅程；更新 Docs #47 的证据链接。
- [x] T011 运行 `flutter analyze`、完整 `flutter test` 和批准 golden；仅将有实际输出的条目标记完成。
- [ ] T012 为固定移动验收增加稳定的登录、快速添加、详情保存和同步状态语义锚点，并跑通不影响宿主网络的离线恢复旅程。
