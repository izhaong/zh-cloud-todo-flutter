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

## 执行证据

- 2026-07-30：T002/T003 的来源隔离增量完成红绿闭环。旧实现固定写入 `task_view/tasks_by_list`，切换清单会继承上一来源的视图模式；现在按 `list:<local UUID>` 或稳定智能来源键经 `TaskViewActionRepository → Drift + view_preference outbox` 保存和恢复，并为默认收集箱保留旧键只读回退。SyncCoordinator 在协议边界把普通清单键转换为 `list-server:<server ID>`，入站再映射回本地 UUID，避免跨设备泄漏本机标识；单调恢复 revision 阻止 A→B→A 快速切换时旧异步结果覆盖新状态。遗留 `TaskViewModeTabs` 已改为纯展示/回调组件，不再由 Widget 直接写同步队列。来源隔离、兼容读取、跨端映射、竞态与既有任务视图定向测试均通过；T002/T003 仍未勾选，因为只读/非法任务 mutation、完整偏好字段和其余 B4 门槛尚未全部验证。
- 2026-07-30：T002/T003/T005/T006/T007 的共享清单权限增量完成红绿闭环。Drift schema 19 为清单保存服务端派生的 `accessRole/writable`，18→19 与全部历史迁移路径保留既有数据；SyncCoordinator 只入站保存权限并剥离出站派生字段。`TaskViewActionRepository` 在同一 transaction 内先校验任务存在、同一清单与 `writable`，viewer 的列表重排、看板移动、时间线调整均零本地写入、零 outbox；跨清单重排整笔拒绝。三个视图会回滚乐观排序并显示“当前清单为只读，无法修改任务”，看板不提供无效重试。Service #185 同步返回 `accessRole/membershipStatus/writable`，仅 active owner/editor 可写，角色变化、加入、退出和移除写入成员自己的增量同步流。定向 Flutter 31 项、Service 12 项与静态检查通过；任务仍未勾选，因为完整偏好字段、冲突回放、列表 Widget 专项、OpenAPI 和固定设备旅程尚未完成。
- 2026-07-30：T002/T004/T005/T006 的时间线偏好增量完成红绿闭环。工作区偏好现在按稳定 source key 原子保存 `viewType/timelineZoom/collapsedTimelineGroupIds`，部分更新会合并服务端 `valueJson` 并保留未知字段，不会因切换视图擦除时间线设置；时间线提供 75%–150% 缩放、分组折叠和失败回滚，跨清单偏好保持隔离。SyncCoordinator 冲突测试实际覆盖服务端 revision 覆盖本地后，用户新选择按最新 revision 重放并维持本地 UUID/服务端清单 ID 映射。定向 44 项与相关静态检查通过；T002/T004/T005/T006 仍未勾选，因为完整看板列偏好、列表 Widget 专项、真实双设备/HTTP、固定设备和视觉基准旅程尚未全部完成。
- 2026-07-30：T002/T004/T005/T006 的看板布局偏好增量完成红绿闭环。`BoardPreferenceRepository` 将四列稳定 ID、顺序和折叠集合编码到既有 `board_preference.columnsJson`，保留 `groupDimension`、清单隔离、Drift/outbox 原子写和冲突恢复链路；历史字符串数组安全补齐缺失列。看板可折叠/展开列并通过列菜单左右调整顺序，Widget 只回调父级保存偏好，不直接改 Drift 或同步队列。任务仍未勾选，因为列内任务排序、完整列表 Widget 专项、真实 HTTP/双设备、固定设备和视觉基准旅程尚未全部完成。
- 2026-07-30：T002/T003/T005/T006 的看板列内排序增量完成红绿闭环。每个展开列改为稳定任务 UUID key 的 `ReorderableListView`，重排遵循 Flutter 索引语义并只把 UUID 顺序回调到 `TasksByListPage → TaskViewActionRepository.reorderListTasks`，复用既有同清单/只读校验、单事务 Drift 更新与逐任务 outbox；失败显示明确提示，受控任务流负责恢复服务端/本地最终顺序。任务仍未勾选，因为真实拖拽手势专项、完整列表 Widget、真实 HTTP/双设备、固定设备和视觉基准旅程尚未全部完成。
- 2026-07-30：T002/T003/T005/T006 的桌面列表真实拖拽增量完成红绿闭环。Widget 测试通过鼠标悬停显示手柄、按下、跨任务移动与释放的真实 `ReorderableListView` 手势，断言共享 use-case 收到 UUID 顺序、Drift 持久化新顺序且逐任务写入 outbox；只读拒绝会恢复原视觉顺序并显示服务端权限原因。测试同时发现并修复合成收集箱没有 `todo_lists` 行时被误判为“清单不存在”的缺口，只对保留 ID `inbox` 的缺行场景视为本地可写，真实清单仍严格执行 `writable`。任务仍未勾选，因为 Service/OpenAPI、真实 HTTP/双设备、固定设备和视觉基准旅程尚未全部完成。
- 2026-07-30：T007 的任务重排 REST 契约增量完成红绿闭环。审计发现未被 Widget 核心路径调用的 `TaskRestApi.reorder` 仍发送历史字段 `orderedTaskIds`，与 Service `AppTodoTaskReorderReqVO` 的 `listId + items[{id, sortOrder}]` 不一致；现在以 `TodoTaskReorderItem` 显式表达服务端 ID 和排序值，冻结完整请求体并校验成功信封。定向 API 契约测试、全量 496 项测试通过，25 项真实环境测试按既有条件跳过，静态分析无错误；Widget 仍只走 Repository/use-case 与 outbox，不因修正直连帮助类而绕过离线真相源。T007 保持未勾选，因为真实 HTTP 和双设备联调尚未执行。
