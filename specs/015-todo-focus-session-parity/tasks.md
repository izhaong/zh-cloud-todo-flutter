# Todo 专注会话对齐任务

- [x] T001 增加 service presets 与 complete remark/clientEndAt 的 Flutter API 合同。
- [x] T002 用服务端预设替换硬编码模式，补 CUSTOM 1–1440 分钟与已同步任务关联。
- [x] T003 补专注备注、动作失败保留和 15 秒多端状态收敛。
- [x] T004 通过定向、全量、静态分析、Web release 与 Claude CLI 聚焦复核。
- [ ] T005 恢复 Gitea/Jenkins 后补 Issue、PR、合并、真实 develop 构建及 test 部署证据。

## 执行证据

- 2026-08-02：官方帮助与源码对照确认当前页面硬编码模式、只在初始化恢复会话、无 CUSTOM 输入/模块内任务选择/专注备注；service 已有 presets/CUSTOM/active 合同，但备注字段只存在于 VO 并未持久化。当前只完成规格，T001–T005 保持未勾选。
- 2026-08-02：API 增加服务端 presets、`pausedAt` 解析及完成时裁剪备注与 `clientEndAt`；页面增加服务端模式、自定义 1–1440 分钟、仅已同步未完成任务关联、512 字符笔记和动作失败保留。
- 2026-08-02：活跃会话改为 15 秒单飞轮询并拒绝过期响应，能收敛其它设备暂停/结束；任务选择改为受控下拉，远端或清除动作不会保留过期内部选择。
- 2026-08-02：API + Widget 定向 11 tests PASS，覆盖成功/失败完成、远端暂停/结束、预设重试、自定义边界和 320px 无溢出；`flutter analyze` No issues。全量测试、Web release 与 Claude CLI 尚待执行。
- 2026-08-02：`flutter test --concurrency=1` 全量 650 tests PASS、26 个显式 live 用例按开关跳过；test API 配置 Web release 构建成功。Wasm dry-run 仅提示既有 `flutter_secure_storage_web` 不兼容，不影响当前 JavaScript Web 产物。
- 2026-08-02：Claude Code 2.1.216 Sonnet 对完整函数上下文只读复核，逐项确认 presets、自定义边界、任务关联、备注、单飞同步、`pausedAt`、Timer、窄屏与测试合同无阻断，`VERDICT: PASS`。
- 2026-08-02：外部门禁复查仍阻塞：Jenkins MCP `getStatus` 等待约 45 秒后以 `HTTP request failed` 结束；Gitea `git ls-remote origin refs/heads/develop` 超过 20 秒无响应后人工终止。按推荐路径保留本地已验证提交，继续下一功能切片，T005 不勾选。
- 2026-09-22：Gitea 侧已恢复并可查：本切片的 Issue/PR/合并三项由 [Issue #239](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/239) 与 [PR #240](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/240) 覆盖（API `merged=true`，base `develop`，合并提交 `5df8497307de`，Issue 已关闭）；服务端 presets、CUSTOM 1–1440、任务关联、512 字符备注与 15 秒单飞轮询均在当前 `develop` HEAD `a1d7733` 内，并由该提交的只读交叉复核逐项定位确认。本地门禁同日复跑全绿（`flutter analyze` 无问题、全量 `+712 ~26: All tests passed!`、golden 9/9、test 配置 Web release 成功）。
- 2026-09-22：T005 的「真实 develop 构建 + test 部署」仍不可证，保持未勾选：`develop` runs `4675`/`4676`/`4677`（`head_sha` 即 `a1d7733`）全部 `conclusion=failure`，job `8649`/`8650`/`8655` 的日志终点同为 runner 宿主机容器创建失败 `NanoCPUs can not be set, as your kernel does not support CPU CFS scheduler or the cgroup is not mounted`，Flutter 命令未执行；Jenkins `zh-cloud-todo-flutter` Job 本会话不可达（无 `jenkins.zh04.com` 凭据、MCP 未连接）。
