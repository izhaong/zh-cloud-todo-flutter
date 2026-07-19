# Tasks: Todo 海量任务组织与检索

## Phase 1: 本地契约与查询

- [ ] T001 在 `test/task_organize_search_repository_test.dart` 写 1,000 条固定 UUID fixture 的任务、清单、文件夹、标签与 task-tag 数据，并断言关键词搜索、组合过滤、多键排序和结果 UUID 稳定。
- [ ] T002 在 `lib/core/db/app_database.dart` 增加可重建的本地搜索索引、批量结果所需数据模型与升级迁移，使 T001 的文件型数据库重启断言通过。
- [ ] T003 新建 `lib/state/repositories/task_query_repository.dart`，实现任务/清单/标签搜索、普通/高级过滤、智能清单读取与冻结的稳定排序，使 T001 的查询断言通过。
- [ ] T004 在 `test/task_organize_search_repository_test.dart` 写自引用、循环、六级层级、跨账户/只读任务和智能清单结构重排的失败测试。
- [ ] T005 修改 `lib/state/repositories/task_repository.dart`，实现五级层级验证、缩进、反缩进、移动、解除关联和手动排序的 Drift transaction 与 task outbox，使 T004 通过。

## Phase 2: 批量与同步

- [ ] T006 在 `test/task_organize_search_repository_test.dart` 写清单、优先级、标签、日期、完成和置顶的批量编辑测试，并断言每个目标返回 success、skipped 或 failed，成功项均有 outbox。
- [ ] T007 新建 `lib/state/repositories/task_batch_edit_repository.dart`，实现逐项批量编辑和部分失败保留，使 T006 通过。
- [ ] T008 在 `test/sync_coordinator_organize_search_test.dart` 写 folder、list、tag、task_tag、task、filter 与 view_preference 的 parent serverId 依赖、排序/层级回放和部分失败重试测试。
- [ ] T009 修改 `lib/core/sync/sync_coordinator.dart`、`folder_repository.dart`、`list_repository.dart` 与 `tag_repository.dart`，使 T008 通过且 folder REST 特例仍经 outbox 可重试。

## Phase 3: 交互与证据

- [ ] T010 在 `test/features/task/task_organize_search_test.dart` 写搜索定位、组合过滤、智能清单禁止结构拖拽、五级拖拽和批量结果反馈的 Widget 失败测试。
- [ ] T011 修改 `lib/features/task/tasks_by_list_page.dart`、`lib/features/filter/filter_bar.dart`、`lib/features/tag/tag_page.dart` 与 `lib/state/providers.dart` 接入 query/batch use-case，使 T010 通过且 Widget 不直接调用 API。
- [ ] T012 运行 `plan.md` 的低资源命令，把实际命令、fixture 规模、性能测量、失败恢复与未运行的双端旅程写入 Docs #51；未验证条目保持 `partial`。
- [ ] T013 与 Service #183 对齐请求/响应、分页、排序键、层级错误、批量逐项结果和 mutation 幂等键，并在 Docs #51 链接双方 PR。

## 执行证据

- 2026-07-16：T004 的一个可独立回滚增量已验证——对不存在的子任务执行 `reparent` 会在任何 Drift 写入或 task outbox 入队前以 `StateError('任务不存在')` 拒绝。`nice -n 19 flutter test --concurrency=1 test/task_organize_search_repository_test.dart` 通过 15 项，`nice -n 19 flutter analyze` 无问题。T004 仍保持未勾选：跨账户/只读任务、智能清单结构重排和交互反馈尚未验证。
- 2026-07-19：T008/T009 的 folder REST 特例新增可回滚增量：`pull()` 在同步白名单实体后用 `/folder/list` 补水 Drift；create 遇业务错误或缺少 server ID 时不再把 outbox 误记为 synced。`test/sync_coordinator_folder_pull_test.dart` 通过，`flutter analyze` 无问题；受 `TODO_B3_LIVE` 保护的 A/B 用例在测试环境证明 A 创建+push、REST list 可见、B 空 Drift pull 后按 server ID/名称恢复。T008/T009 仍未勾选：folder 更新/删除、权限、离线重启、失败恢复及与 list 移动的完整回放尚未验证。
- 2026-07-19：同一 folder A/B 旅程继续覆盖改名和删除：A 改名后 B pull 得到新名称；A 删除后 B pull 删除陈旧本地 folder 并清除关联 list 的 `folderId`。此前新增的“服务端列表已不再返回 folder 但本地仍保留”测试先失败后通过。T008/T009 仍未勾选：权限、离线重启、失败恢复和移动 list 的完整回放尚未验证。
- 2026-07-19：T008/T009 新增清单归属闭环。`FolderApi.moveLists` 按 Service 契约发送 `POST /folder/move-list` 的 `{listIds, folderId}`；`ListRepository.moveToFolder` 在本地写入并以 list upsert outbox 回放。针对服务端 payload 明确携带 `folderId: null` 的 Drift pull 测试先失败后通过。测试环境 A/B Drift 实测：REST 移入 folder 后 B 恢复归属；A 经 outbox 显式清空后 B 恢复顶层。T008/T009 仍未勾选：权限、离线重启和失败恢复未验证。
- 2026-07-19：智能清单不变量与离线重启补证。`ListRepository.moveToFolder` 对 `smart:` 清单在写 Drift/outbox 前拒绝；该测试先失败（错误移动并产生 folderId=88）后通过。文件型 Drift 重开仍保留普通 list 的 folderId 与 list outbox；受保护的真实 A/B 用例进一步证明 A 离线移出 folder、关闭重开后恢复网络 push，B pull 回放为顶层。T008/T009 仍未勾选：真实跨账户 HTTP 与失败恢复未验证。
- 2026-07-19：folder REST failure recovery 修复。网络失败时旧 `_pushFolderChanges` 将 outbox 标为 `failed`，下一次 `push()` 不会读取；文件型数据库回归先失败（实际 `failed`）后改为 `retryable`。重开数据库后同一 mutation 自动重试、回写 folder serverId 并标记 synced；附件失败回归保持通过。T008/T009 仍未勾选：真实跨账户 HTTP 与失败反馈 Widget 未验证。
- 2026-07-19：为跨账户 B3 权限补入 `b3_live_cross_account_permission_test.dart`：账户 A 创建并同步任务后，账户 B 应既搜不到也不能经 `PUT /task/batch-update` 修改该任务，且 A 再次 pull 后优先级不变。Service 对应逐项失败契约 `TodoTaskBatchServiceTest` 7 项通过；Flutter 默认受保护用例可编译并跳过，`flutter analyze` 与 `git diff --check` 通过。真实执行尚未形成通过证据：测试环境的 `/todo-member/auth/send-sms-code` 返回“系统异常”，所以没有把认证失败写成跨账户通过；T008/T009、T012/T013 继续未勾选。
