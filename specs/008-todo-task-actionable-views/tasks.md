# Tasks: Todo 可工作的列表、看板与时间线

## Phase 1: 审计与共享写链路

- [x] T001 审计现有列表、看板、时间线、拖拽和偏好代码，记录真实字段、直连调用和 B2/B3 依赖到 Docs #53。
- [ ] T002 在 `test/task_view_action_repository_test.dart` 写列表重排、跨列移动、时间调整、只读/非法输入和偏好隔离的失败测试。
- [ ] T003 实现共享 Repository/use-case 的 Drift transaction、outbox 与逐项失败语义，使 T002 通过。
- [ ] T004 为 view preference 与 task mutation 增加 SyncCoordinator 顺序、重试和冲突测试并实现回放。

## Phase 2: 真实视图交互

- [ ] T005 写列表、看板和时间线 Widget 失败测试，断言拖拽产生共享 use-case mutation 与可见反馈。
- [ ] T006 最小修改既有视图接入 use-case，不改变已批准工作区结构，使 T005 通过。
- [ ] T007 与 Service #185 完成契约/权限/幂等对齐，记录双方定向命令和 API 结果。
- [ ] T008 执行固定桌面、移动、离线恢复与视觉基准旅程，把实际证据写入 Docs #53；未执行项保持未勾选。
