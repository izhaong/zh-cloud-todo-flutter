# Tasks: Todo 海量任务组织与检索

## Phase 1: 本地契约与查询

- [x] T001 在 `test/task_organize_search_repository_test.dart` 写 1,000 条固定 UUID fixture 的任务、清单、文件夹、标签与 task-tag 数据，并断言关键词搜索、组合过滤、多键排序和结果 UUID 稳定。
- [x] T002 在 `lib/core/db/app_database.dart` 增加可重建的本地搜索索引、批量结果所需数据模型与升级迁移，使 T001 的文件型数据库重启断言通过。
- [x] T003 新建 `lib/state/repositories/task_query_repository.dart`，实现任务/清单/标签搜索、普通/高级过滤、智能清单读取与冻结的稳定排序，使 T001 的查询断言通过。
- [ ] T004 在 `test/task_organize_search_repository_test.dart` 写自引用、循环、六级层级、跨账户/只读任务和智能清单结构重排的失败测试。
- [ ] T005 修改 `lib/state/repositories/task_repository.dart`，实现五级层级验证、缩进、反缩进、移动、解除关联和手动排序的 Drift transaction 与 task outbox，使 T004 通过。

## Phase 2: 批量与同步

- [x] T006 在 `test/task_organize_search_repository_test.dart` 写清单、优先级、标签、日期、完成和置顶的批量编辑测试，并断言每个目标返回 success、skipped 或 failed，成功项均有 outbox。
- [x] T007 新建 `lib/state/repositories/task_batch_edit_repository.dart`，实现逐项批量编辑和部分失败保留，使 T006 通过。
- [ ] T008 在 `test/sync_coordinator_organize_search_test.dart` 写 folder、list、tag、task_tag、task、filter 与 view_preference 的 parent serverId 依赖、排序/层级回放和部分失败重试测试。
- [ ] T009 修改 `lib/core/sync/sync_coordinator.dart`、`folder_repository.dart`、`list_repository.dart` 与 `tag_repository.dart`，使 T008 通过且 folder REST 特例仍经 outbox 可重试。

## Phase 3: 交互与证据

- [ ] T010 在 `test/features/task/task_organize_search_test.dart` 写搜索定位、组合过滤、智能清单禁止结构拖拽、五级拖拽和批量结果反馈的 Widget 失败测试。
- [ ] T011 修改 `lib/features/task/tasks_by_list_page.dart`、`lib/features/filter/filter_bar.dart`、`lib/features/tag/tag_page.dart` 与 `lib/state/providers.dart` 接入 query/batch use-case，使 T010 通过且 Widget 不直接调用 API。
- [ ] T012 运行 `plan.md` 的低资源命令，把实际命令、fixture 规模、性能测量、失败恢复与未运行的双端旅程写入 Docs #51；未验证条目保持 `partial`。
- [ ] T013 与 Service #183 对齐请求/响应、分页、排序键、层级错误、批量逐项结果和 mutation 幂等键，并在 Docs #51 链接双方 PR。
- [x] T014 补齐总控 B3 的负责人过滤合同：Drift 保存 `assigneeUserId` 与可空展示名，sync pull 可回放，Repository 与高级筛选 UI 可按稳定用户 ID 过滤；Service #183 必须同步返回并校验同一字段后才能结项。

## 执行证据

- 2026-07-30：将 B3 的 1,000 条固定 UUID 基础 fixture 补齐为任务、清单、文件夹、标签与 task-tag 五类关联数据；关键词搜索稳定返回 task/list/tag，组合过滤复用真实 task-tag，多键排序以置顶、手工顺序和 UUID 冻结。现有 FTS5 索引、触发器、可重建迁移与 `TaskQueryRepository` 已覆盖普通/高级过滤、固定时区日期、负责人、倒置区间拒绝及文件型数据库重启后的稳定 UUID 定位，T001–T003 结项；Repository、文件型重启与迁移定向组 32 项通过。
- 2026-07-30：批量编辑逐项结果补齐三态断言：有效任务返回 `success`，重复 UUID 返回 `skipped/重复任务`，不存在任务返回 `failed/任务不存在`，后续有效项不受前两项影响；仅两个成功任务更新清单/优先级/标签/日期/完成/置顶相关字段并形成对应 task/task_tag outbox。结合既有部分失败保留、清空日期、非法清单和 Widget 可见重试测试，T006/T007 结项；Repository 与 Widget 定向组 45 项通过。
- 2026-07-16：T004 的一个可独立回滚增量已验证——对不存在的子任务执行 `reparent` 会在任何 Drift 写入或 task outbox 入队前以 `StateError('任务不存在')` 拒绝。`nice -n 19 flutter test --concurrency=1 test/task_organize_search_repository_test.dart` 通过 15 项，`nice -n 19 flutter analyze` 无问题。T004 仍保持未勾选：跨账户/只读任务、智能清单结构重排和交互反馈尚未验证。
- 2026-07-19：T008/T009 的 folder REST 特例新增可回滚增量：`pull()` 在同步白名单实体后用 `/folder/list` 补水 Drift；create 遇业务错误或缺少 server ID 时不再把 outbox 误记为 synced。`test/sync_coordinator_folder_pull_test.dart` 通过，`flutter analyze` 无问题；受 `TODO_B3_LIVE` 保护的 A/B 用例在测试环境证明 A 创建+push、REST list 可见、B 空 Drift pull 后按 server ID/名称恢复。T008/T009 仍未勾选：folder 更新/删除、权限、离线重启、失败恢复及与 list 移动的完整回放尚未验证。
- 2026-07-19：同一 folder A/B 旅程继续覆盖改名和删除：A 改名后 B pull 得到新名称；A 删除后 B pull 删除陈旧本地 folder 并清除关联 list 的 `folderId`。此前新增的“服务端列表已不再返回 folder 但本地仍保留”测试先失败后通过。T008/T009 仍未勾选：权限、离线重启、失败恢复和移动 list 的完整回放尚未验证。
- 2026-07-19：T008/T009 新增清单归属闭环。`FolderApi.moveLists` 按 Service 契约发送 `POST /folder/move-list` 的 `{listIds, folderId}`；`ListRepository.moveToFolder` 在本地写入并以 list upsert outbox 回放。针对服务端 payload 明确携带 `folderId: null` 的 Drift pull 测试先失败后通过。测试环境 A/B Drift 实测：REST 移入 folder 后 B 恢复归属；A 经 outbox 显式清空后 B 恢复顶层。T008/T009 仍未勾选：权限、离线重启和失败恢复未验证。
- 2026-07-19：智能清单不变量与离线重启补证。`ListRepository.moveToFolder` 对 `smart:` 清单在写 Drift/outbox 前拒绝；该测试先失败（错误移动并产生 folderId=88）后通过。文件型 Drift 重开仍保留普通 list 的 folderId 与 list outbox；受保护的真实 A/B 用例进一步证明 A 离线移出 folder、关闭重开后恢复网络 push，B pull 回放为顶层。T008/T009 仍未勾选：真实跨账户 HTTP 与失败恢复未验证。
- 2026-07-19：folder REST failure recovery 修复。网络失败时旧 `_pushFolderChanges` 将 outbox 标为 `failed`，下一次 `push()` 不会读取；文件型数据库回归先失败（实际 `failed`）后改为 `retryable`。重开数据库后同一 mutation 自动重试、回写 folder serverId 并标记 synced；附件失败回归保持通过。T008/T009 仍未勾选：真实跨账户 HTTP 与失败反馈 Widget 未验证。
- 2026-07-19：为跨账户 B3 权限补入 `b3_live_cross_account_permission_test.dart`：账户 A 创建并同步任务后，账户 B 应既搜不到也不能经 `PUT /task/batch-update` 修改该任务，且 A 再次 pull 后优先级不变。Service 对应逐项失败契约 `TodoTaskBatchServiceTest` 7 项通过；Flutter 默认受保护用例可编译并跳过，`flutter analyze` 与 `git diff --check` 通过。真实执行尚未形成通过证据：测试环境的 `/todo-member/auth/send-sms-code` 返回“系统异常”，所以没有把认证失败写成跨账户通过；T008/T009、T012/T013 继续未勾选。
- 2026-07-27：T010/T011 的批量失败恢复新增 Widget 红绿证据。先让选中的任务在执行前消失，断言旧 Snackbar 没有“重试失败项”而失败；实现后恢复同一任务并点击该入口，只重放失败 task ID，显示“已重试 1 项；失败 0 项”，且优先级写为 3。`task_organize_search_repository_test.dart` 20 项、`sync_coordinator_organize_search_test.dart` 5 项、`task_organize_search_test.dart` 16 项、`flutter analyze` 与 `git diff --check` 全通过。此条只证明本地 Drift/Widget 的可见重试，真实 HTTP、跨账户、设备性能和双端 GUI 仍未验证，T010/T011/T012/T013 保持未勾选。
- 2026-07-27：按 Keychain 既有测试账户、一次性大陆格式第二账户与授权的 `9999` 短信码重新执行 `TODO_B3_LIVE=true test/b3_live_cross_account_permission_test.dart`；认证第一步返回 HTTP 502，测试在创建 list/task 前终止，未执行任何跨账户搜索或批量写断言，也没有待清理的资源。该结果只证明当前测试环境认证入口不可用，不能替代 T012/T013 的真实 HTTP 通过证据。
- 2026-07-27：测试环境恢复后重新执行同一受保护跨账户用例，实际输出 1 项通过。账户 A 创建并同步的任务在 B 的全局搜索中为空；B 的 `PUT /task/batch-update` 返回逐项 `failed`，A pull 后任务优先级仍为 0；`finally` 仅按本次服务端 ID 删除任务与清单。账号只从 Keychain 读取，第二账户是一次性大陆格式号码和授权 `9999`，未记录任何值。该通过只覆盖 CAP-25/28 的真实 HTTP 权限契约；设备性能、完整双端 GUI、批量产品 HTTP 消费等其余 B3 门槛仍缺，T012/T013 保持未勾选。
- 2026-07-27：在本机 macOS Todo 客户端按授权完成桌面 GUI 冒烟：验证码登录成功；在收集箱创建一条验收任务后打开筛选面板与批量编辑状态，并通过界面撤销该任务，最终收集箱回到 0，未留下任务数据。此条只证明桌面固定交互可达，不等同于移动真机、千条设备性能、完整检索旅程或 Jenkins 通过；T012/T013 保持未勾选，B3 继续 `partial/in_progress`。
- 2026-07-27：当前 Draft head 复核：`task_organize_search_repository_test.dart`、文件型搜索重启、组织 sync、filter、view preference、组织 Widget、TagPage 与快速添加共 50 项通过，`flutter analyze` 与两端 `git diff --check` 通过。随后尝试补“创建→全局搜索定位→筛选/批量→清理”桌面旅程时，本机存在另一套 Todo Flutter 实例，辅助功能窗口捕获无法可靠定向本隔离实例；未把该次尝试计作 GUI 通过。移动真机、千条设备性能、完整桌面/移动固定旅程及 Jenkins 仍未满足，T012/T013 保持未勾选。
- 2026-07-27：工作区布局 21 项单独通过，覆盖了 Jenkins #49 于 2026-07-19 报出的 `ListTile`/`ColoredBox` 历史断言；但完整 `nice -n 19 flutter test --concurrency=1` **未通过**：7 张 workspace golden 均仅在顶部图标字形上出现 756px 级差异（0.06%–0.26%），差异文件已清理且没有更新基准。该结果不能被写作全量回归通过；默认开关下的 13 项受保护 live 用例也仍是 skip。Jenkins #49 仍是旧构建且当前未见新队列/运行实例；T012/T013 保持未勾选。
- 2026-07-27：为保持 002 已批准的空闲工作区视觉结构，将批量编辑入口收敛到既有“排序”弹出菜单的显式“批量编辑/退出批量编辑”项；批量模式、Drift/use-case/outbox 写链路未改变，且没有更新任何 golden。`test/features/task/task_organize_search_test.dart` 16 项、B3 Repository/文件型重启/sync/filter/视图偏好/TagPage/快速添加共 50 项、九张 workspace golden、`flutter analyze` 与 `git diff --check` 均通过。随后完整 `flutter test --concurrency=1` 仍稳定失败于不在本次 diff 的既有 `task_selection_test.dart` 排序位置断言和 `sync_coordinator_template_test.dart` 失败状态断言；因此不将全量回归或 Jenkins 写为通过，T012/T013 保持未勾选，B3 继续 `partial/in_progress`。
- 2026-07-27：系统化复现后校正两条过期测试契约：智能排序的冻结键为置顶、手工 `sortOrder`、UUID，`updatedAt` 不会使任务移动；标准 `/sync/push` 网络异常进入 `retryable`，`failed` 只用于冲突。两项先单独通过，再执行 `nice -n 19 flutter test --concurrency=1`，实际输出 `348` 项通过、`23` 项受保护 live 用例跳过、`All tests passed!`；未更新 golden。完整本地测试门槛现已满足，但 Jenkins 新构建、移动真机、性能与完整固定 GUI 仍未满足，T012/T013 继续未勾选，B3 保持 `partial/in_progress`。
- 2026-07-27：T012 补入本机 macOS 文件型 SQLite 的 1,000 条固定任务性能证据。搜索首个结果、优先级过滤排序和三项批量反馈各执行三次，实际为搜索 `1/1/1ms`、过滤 `17/17/17ms`、批量 `14/15/14ms`，均低于 B0 本地优先 `300ms` 预算；测试断言稳定结果、逐项成功及每项上限。完整组织/检索 Repository 21 项、`flutter analyze`、差异检查通过。此条不替代移动端渲染、网络或 Service P95，T012/T013 仍保持未勾选，B3 继续 `partial/in_progress`。
- 2026-07-30：T014 的 Flutter 可独立回滚增量按红绿闭环补齐：Drift schema 14 保存稳定 `assigneeUserId` 与可空展示名，13→14 文件型迁移保留既有任务；sync pull 兼容驼峰/下划线负责人字段，Repository 与高级筛选 UI 均按稳定用户 ID 过滤。负责人 Repository、sync、Widget 与迁移 47 项通过；随后 `flutter test --fail-fast -r expanded` 实际输出 `353` 项通过、`23` 项受保护 live 用例跳过、`All tests passed!`，未更新 golden。Service #183 尚未返回并消费同一字段，Gitea/PR/Jenkins 与真实双端同步也未验证，因此 T014、T012、T013 保持未勾选，B3 继续 `partial/in_progress`。
- 2026-07-30：在 JDK 25 `zh-cloud-service/develop` 复核 Service #183 的后续合并结果：PR #184 已把 `assigneeUserId` 纳入 task sync payload，push 兼容 camelCase/snake_case，允许清单 owner、active member 与显式清空，并拒绝非 active 成员。执行 `./mvnw -pl yudao-module-todo -am -Dtest=TodoSyncServiceHierarchyTest -Dsurefire.failIfNoSpecifiedTests=false test`，JDK 25 reactor 21 个模块成功，10 项测试通过；Flutter 负责人 Repository、sync、Widget 与迁移定向组 59 项通过。至此 Flutter 与 Service 的稳定负责人 ID 返回、校验、缓存、回放和筛选合同均满足，T014 结项；Service #183 的其它 B3 范围及 T012/T013 外部旅程仍保持未完成。
- 2026-07-30：高级截止日期过滤与 `dueDate` 排序补充固定时区红绿测试。日期范围按任务 IANA 墙钟的日历日做包含式比较，排序按用户实际看到的墙钟时刻稳定执行；不再用原始 UTC 瞬时与日期选择器的本地零点直接比较。此增量不替代真实双端同步、移动设备和 Service 查询契约，T012/T013 保持未勾选。
- 2026-07-30：T010/T011 的智能清单结构保护补入桌面 Widget 红绿证据：旧实现仍创建 `ReorderableListView` 并显示“拖动排序”入口，失败测试复现后改为仅普通清单传递重排回调；智能清单现在使用不可重排列表且不渲染拖拽手柄，普通清单真实拖拽与只读回滚用例保持通过。此增量只结清智能清单禁止结构拖拽这一项，五级层级交互、完整固定旅程和外部证据仍未满足，T010/T011/T012/T013 保持未勾选。
- 2026-07-30：T004/T005 的层级写保护补入两条 Repository 红绿证据：只读共享清单的 `reparent` 在任何任务写入或 task outbox 前以明确原因拒绝；移动已有子树时同时计算目标父链与最深后代，避免只校验被移动节点而把后代推进六级以上。组织、详情与受保护 live 层级定向组实际为 41 项通过、1 项 live 跳过。任务创建/编辑等其余只读写入口、五级层级 Widget 交互和完整外部旅程仍需继续审计，T004/T005/T010–T013 保持未勾选。
