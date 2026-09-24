# Todo 常用专注计时器任务

- [x] T001 增加 Timer DTO、CRUD、归档与一键启动 API 红绿合同。
- [x] T002 实现请求隔离的 Timer 列表、紧凑空态和一键启动。
- [x] T003 实现新增/编辑、任务/习惯关联、归档/恢复与删除。
- [x] T004 实现真正 Stopwatch 的恢复、递增和暂停语义。
- [x] T005 通过语义、320px、全量、Web 与 Claude CLI 门禁。
- [ ] T006 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：滴答官方 Timer/How to Start Focus 对照确认当前缺少用户级 Timer、任务/习惯关联、一键启动、编辑/归档/删除和真正 Stopwatch；当前只完成规格与实施计划。
- 2026-08-02：跨设备 Service 实体方案已确定；Flutter-only 与 JSON/presets 方案因偏离跨设备事实源和实体约束而否决。
- 2026-08-02：API 红测在编译阶段准确缺少 `PomodoroTimerDto` 与 timers/create/update/archive/delete/start 方法；实现强类型 Timer DTO、FREE 空时长省略、完整 CRUD 路由、归档 query 参数、会话 `timerId/habitId` 解析及 Timer start 完整会话校验后，`efficiency_api_contract_test.dart` 7/7 通过。标量 Timer start 响应会抛出契约错误，不伪造活动会话。
- 2026-08-02：Timer 卡片红测先准确找不到“常用专注”；实现独立 Timer section、请求序号隔离、任务/习惯名称、读屏一键开始、失败保留上次成功列表后，新列表/启动、15 秒轮询不阻塞和失败保留用例通过，专注页全量 31/31 通过。成功且为空时保持原首屏紧凑，显式空态与新增入口在管理切片补齐。
- 2026-08-02：Timer 管理红测先准确找不到新增入口；实现名称 1–64 字符与 1–1440 分钟边界、正计时/固定/自定义模式、任务或习惯单一关联、稳定排序、编辑、归档/恢复与删除确认。写操作只在 API 确认后更新列表，失败保留原数据，归档/恢复/删除均明确保留历史专注。专注页 33/33、320px 用例和 `flutter analyze` 通过。
- 2026-08-02：Stopwatch 红测先证明 FREE 会话被错误按 25 分钟剩余时间显示；改为从 `startedAt/pausedAt/pausedSeconds` 恢复已用秒数，运行时递增、暂停时冻结、恢复后继续递增。FREE 启动不再要求或提交伪造目标分钟，也不显示无意义的时长调整；番茄恢复和递减回归保持通过。专注页与 API 联合 43/43，`flutter analyze` 无问题。
- 2026-08-02：T005 本地门禁中，活动/归档 Timer 过期响应隔离和 320px 精确读屏语义用例通过；指定文件格式检查、`flutter analyze`、全量 `flutter test` 和 test 配置 Web release 均退出 0，既有 live 用例仅按其显式 dart-define 开关跳过。Claude Code 2.1.216 以 safe-mode/plan/sonnet/low、3 美元上限对 FR-001–FR-008 只读审查，等待约 80 秒无任何正文，手动终止后仅返回 `Execution error`；未修改文件，本阻塞不覆盖本地门禁结论，T005 保持未完成。
- 2026-08-02：Gitea Issue #239 与 PR #240 已创建并与 Service 互链，PR 目标 `develop`且 `mergeable=true`。Actions run #4568 / job #8487 的 Analyze & Test 在 0 秒内失败，runner 未执行 Flutter 命令；原始日志为固定 `runner-images@sha256:cd31050d...` 向 `docker-mirror.zh04.com` 发起 manifest HEAD 时返回 502。手动 rerun 后 04:06:22 再次得到相同 502，归类为镜像代理外部阻塞，不覆盖本地 analyze/test/Web 门禁。
- 2026-08-02：PR #240 已以普通 merge commit `5df8497307de` 合入 `develop`、Issue #239 已关闭、远程与本地功能分支已删除，本地 `develop` 已 fast-forward 对齐。Jenkins 仅存已禁用的 `legacy-20260729-zh-cloud-todo-flutter-test` #53，没有新的可构建 Flutter Job；合并后无 Jenkins 编译/测试/部署证据，T006 继续保持未完成。
- 2026-09-22：T005 结项。缺口只剩 2026-08-02 记录「约 80 秒无正文后手动终止」的 Claude CLI 交叉复核：本机 Flutter 工具链重建后（Flutter 3.44.8 / Dart 3.12.2，`develop` HEAD `a1d7733`）以只读 `plan` 模式（仅 `Read`/`Grep`/`Glob`）对 FR-001–FR-008 完成复核，返回 `VERDICT: PASS`，并逐项定位到实现与测试行号（DTO/CRUD `efficiency_api.dart:88-121,629-724`、请求序号隔离 `pomodoro_page.dart:194-219`、Stopwatch 恢复 `:584-597`）。本地门禁同日复跑全绿：`git diff --check` 干净、`flutter analyze` `No issues found!`、全量 `flutter test --exclude-tags 'golden || performance' --concurrency=1` `+712 ~26: All tests passed!`、golden 9/9、test 配置 Web release `✓ Built build/web`。
- 2026-09-22：该复核提出 1 项 Important 与 2 项 Minor，逐条判定后**均未改动本切片代码**，理由如下。Important「`_timerActionPendingId = initial?.id ?? -1` 用 `-1` 阻塞新建窗口」——`-1` 是「尚无服务端 id」的有意哨兵值而非伪造服务端 ID：消费方只做 `!= null` 与 `== timer.id` 比较，写入列表的 `confirmed.id` 取自 `api.createTimer` 的真实返回值，`finally` 一定会清空 pending，`_showTimerEditor` 亦以同一字段作重入闸；改成 `null` 反而会让新建窗口期失去重入保护，故不采纳。Minor「FREE 已用时长在 15 秒轮询间隙存在客户端拖尾误差」——显示值仍由服务端 `startedAt/pausedAt/pausedSeconds` 计算，属既有单飞轮询设计的可接受代价，非静默降级。Minor「API 层不校验名称长度与分钟范围」——按规格边界由服务端（Service 规格 014）强制，客户端重复守门会形成双份真源，维持现状。
- 2026-09-22：T006 的远端部分仍不可证。`develop` 上 runs `4675`（`CI / Analyze & Test`）、`4676`（`Desktop / Resolve build env`）、`4677`（`Web / Resolve env`，`run_number` 837/838/839，`head_sha` 即 `a1d7733`）全部 `conclusion=failure`，job `8649`/`8650`/`8655` 原始日志同一条终点为 `failed to create container: 'Error response from daemon: NanoCPUs can not be set, as your kernel does not support CPU CFS scheduler or the cgroup is not mounted'`（runner `gitea-runner-1`），Flutter 命令一次都未执行；2026-08-02 的 `502 Bad Gateway` 镜像代理故障与今日的 cgroup 故障同为 runner 宿主侧问题。Jenkins `zh-cloud-todo-flutter` Job 在本会话仍不可达（凭据链无 `jenkins.zh04.com` 条目，MCP 未连接），故无 develop 构建与 test 部署证据可登记。
