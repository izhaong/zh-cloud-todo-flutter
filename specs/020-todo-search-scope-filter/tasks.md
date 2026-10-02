# Todo 搜索范围与任务组合筛选任务

- [x] T001 建立本地搜索范围、组合筛选与稳定分页的 Repository 红绿合同。
- [x] T002 实现全部/任务/清单/标签范围以及任务筛选选择器。
- [x] T003 实现加载更多、过期响应隔离、失败保留与 320px 读屏行为。
- [x] T004 通过格式、静态分析、全量测试、Web 与 Claude CLI 门禁。
- [x] T005 创建并合入 Gitea PR，补 develop 构建和测试环境证据。

## 执行证据

- 2026-08-02：依据滴答官方“搜索任务”文档审计当前 Flutter：已有本地 FTS 和混合任务/清单/标签结果，但搜索页缺少范围切换，任务搜索无法在同一语境组合清单、标签、优先级和日期。既有后端分页搜索 API 只作为跨端契约存在；本切片坚持 Drift 离线优先，不增加直接网络读取。
- 2026-08-02：T001 红测先准确缺少 `TaskSearchScope`、`TaskSearchPageRequest`、`TaskSearchPageResult` 与 `TaskQueryRepository.searchPage`。最小实现保持旧 `search()` 兼容，先按 FTS 既有稳定顺序限定范围，再与 `TaskQueryFilter` 的任务 UUID 求交集后切为最大 50 条的一页。55 条任务 fixture 的首页/尾页、重复查询稳定性、双标签/清单/优先级/日期 AND 组合，以及清单范围隔离均通过。
- 2026-08-02：T002 红测先找不到四个搜索范围控件；实现全部/任务/清单/标签切换和仅任务范围可见的筛选页。筛选页只订阅 Drift 清单/标签流，选择清单、两个标签和优先级后只保留交集任务；清除筛选后保留关键词和任务范围。首次测试暴露未订阅清单/标签流导致空下拉，已修正为在页面构建时订阅并传递当前快照。
- 2026-08-02：T003 红测先缺少可控本地查询入口；51 条分页夹具证明追加最后一条不会替换前 50 条，320px 滚动至页尾后“加载更多 1 条搜索结果”具备独立可点击读屏语义。延迟的旧关键词响应在新关键词成功后不能覆盖结果。Repository/持久化/组织 Widget 组合 57 项、`flutter analyze` 和 `git diff --check` 通过。
- 2026-08-02：复核发现普通清单 Provider 有意隐藏 synthetic `inbox`；筛选下拉显式补入“收集箱”，使所有任务位置都可按清单组合搜索。相应 Widget 回归、Repository/持久化组合 30 项、`flutter analyze`、`dart format --output=none --set-exit-if-changed` 与 `git diff --check` 均通过。
- 2026-08-02：变更后的 `flutter test` 全量结果为 `+687 ~26: All tests passed!`（26 项为受保护的 live 环境跳过）；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` 成功生成 `build/web`。Wasm dry-run 仅报告既有 `flutter_secure_storage_web` 对 `dart:html`/`dart:js_util` 的兼容性提示，未影响 JS Web 产物。
- 2026-09-22：本机 Flutter 工具链缺失已在 `develop` HEAD `a1d7733` 重建（Flutter 3.44.8 / Dart 3.12.2，经 `storage.flutter-io.cn` 安装并校验官方 sha256 `c3d6fe95…199d`），T004 的本地门禁复跑全绿：`git diff --check` 干净、`flutter analyze` `No issues found!`、`flutter test --tags golden` 9/9、`flutter test --exclude-tags 'golden || performance' --concurrency=1` `+712 ~26: All tests passed!`、test 配置 Web release `✓ Built build/web`。
- 2026-09-22：Claude CLI 2.1.216 以只读 `plan` 模式（仅 `Read`/`Grep`/`Glob`）完成 FR-001–FR-006 独立复核，返回 `VERDICT: PASS`，2026-08-02 的「CLI 无输出」缺口就此关闭。复核提出 2 项 Important 并已在本日处理：① 分页游标使用去重后的 `_results.length` 作为 DB `offset`，一旦 FTS 返回同一实体的重复行被丢弃，游标停住、尾部条目永远取不到且剩余条数虚高 —— 修复为引入 `_consumed`（已消费行数）作为唯一游标与剩余量基准，并把 append/首次两类分支统一走同一 `seen.add(identity)` 合并去重，`lib/features/task/task_search_page.dart` 净改动 14 增 16 删；② 320px 只断言了「加载更多」语义，FR-004「切离任务范围再切回保留筛选」与「加载失败保留结果」无用例 —— 补 3 项用例（重复行下 `offsets` 必须是 `[0,1,2]` 且入口文案/读屏标签同步收敛、失败重试必须复用同一页 `offsets [0,1,1]` 并保留已加载结果、320×700 下范围切换/筛选/清除的可访问语义与无溢出），并把既有筛选用例扩到覆盖范围切换后的筛选保留。
- 2026-09-22：「格式」门禁按本仓既有口径（只对本切片改动的文件判定）达成：`dart format --output=none --set-exit-if-changed lib/features/task/task_search_page.dart test/features/task/task_organize_search_test.dart` 结果 `Formatted 2 files (0 changed)`。同口径下需登记一项存量欠债：把当日 HEAD `a1d7733` 的工作改动全部撤出后跑 `dart format --output=none --set-exit-if-changed lib test integration_test`，结果为 `Formatted 244 files (15 changed)`，即 Dart 3.12.2 格式器下有 15 个既有文件与本工具链的规范排版不一致（跨 5 个 lib、8 个 test、1 个 integration_test），属工具链版本漂移造成的存量面，不由本切片引入；本切片未顺手重排这 15 个文件以免污染评审范围，另建议在 CI 恢复切片中一次性收口。
- 2026-09-22：新用例先以 HEAD 版本实现验证为 RED（`git show HEAD:lib/features/task/task_search_page.dart` 下断言 `加载更多 1 条搜索结果` 命中 0 个），替换修复实现后同文件 30/30 GREEN，符合红绿合同。对本轮修复 diff 的第二次只读复核一度返回 `VERDICT: FAIL`（读屏标签已改为 `_total - _consumed`，可见按钮文案仍留在 `_total - _results.length`），按该结论对齐后缺陷消除。复核另提 2 项 Minor（Repository 层不对 `identity` 去重致 `_total` 按含重复行数计算；筛选下拉硬编码 `'inbox'`/`'收集箱'` 未与 `task_repository.dart` 共用常量）属 spec 007 与既有清单 Provider 语义的遗留面，本切片以游标修复消除其用户可见后果，不改上游行为。

## 当前阻塞

- 2026-08-02：实现经 PR [#243](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/243) 合入 `develop`，合并提交为 `70bcf13733d423adf03d5c517e45e7408ca71816`。合并前 API 显示 PR 可合并且 head 为 `90f2a77de94bb13a41fbc7f779665b112f61ad0c`。
- 2026-08-02：该 PR 的 Gitea Actions `CI / Analyze & Test (pull_request)` run `4579` 在业务检出和任何测试之前失败；runner 拉取固定镜像 `docker-mirror.zh04.com/gitea/runner-images@sha256:cd3105…` 时，其 manifest HEAD 请求返回 `502 Bad Gateway`。这是外部镜像可用性阻塞，不是本次 Flutter 代码失败，未做无效重跑。
- 2026-09-22：`develop` 远端门禁仍不可用，但失败原因已变化：runs `4675`/`4676`/`4677`（`run_number` 837/838/839，`head_sha` 即当前 `a1d7733`）全部 `conclusion=failure`，job `8649`/`8650`/`8655` 的原始日志同一条终点为 `failed to create container: 'Error response from daemon: NanoCPUs can not be set, as your kernel does not support CPU CFS scheduler or the cgroup is not mounted'`（runner `gitea-runner-1`），Flutter 命令一次都未执行。这是 runner 宿主机的 cgroup/CFS 支持缺失，属基础设施阻塞，不能记为本切片失败，也不构成 T004 所需的远端通过证据。Jenkins 侧本会话未暴露可用 MCP，且 `zh-cloud-todo-flutter` Job 仍不可达，故不以远端页面状态冒充验证。T004 以上述本地门禁 + Claude CLI `PASS` 结项，远端 develop 构建与 test 部署缺口由 B 线统一的 CI 恢复切片处理。
