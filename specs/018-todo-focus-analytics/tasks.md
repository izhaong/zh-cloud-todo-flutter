# Todo 专注分析完整度任务

- [x] T001 增加 year、taskDistribution 与 timeline API 红绿合同。
- [x] T002 实现 12 个月趋势与按任务分布。
- [x] T003 实现按日 timeline、旧响应隔离和失败保留。
- [ ] T004 覆盖语义、月标签、窄屏、全量与 Claude CLI 门禁。
- [ ] T005 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：滴答官方 Focus Statistics/Timer 对照确认当前缺少年趋势、每日时间轴与按任务分布；当前仅完成规格。
- 2026-08-02：Service 已在 JDK 25 下通过 25/25 定向与 Todo reactor 295/295；Claude CLI 两次只读交叉复核均无正文并返回 `Execution error`。按推荐继续 Flutter 红测，待 CLI/provider 恢复后补复核，不把外部通道阻塞误记为功能失败。
- 2026-08-02：Flutter API 红测先因缺少 `year`/`taskDistribution`/`timeline` 合同编译失败，完成 DTO、请求和页面实现后聚焦合同 32/32 通过。追加“时间轴请求悬挂不得阻塞活跃会话轮询”回归时先得到 `Expected: <2>, Actual: <1>`，解耦初始化请求后该用例转绿。
- 2026-08-02：Claude Code 2.1.216 使用只读 `Read/Grep/Glob` 对规格、实现与测试进行第三次聚焦复核，约 75 秒无任何正文，主动结束后仅返回 `Execution error`。T004 保留未勾选，待 CLI/provider 恢复后重跑；按推荐继续本地全量门禁和后续切片。
- 2026-08-02：最终新鲜门禁为 `dart format --output=none --set-exit-if-changed` 4 文件无改动、`git diff --check` 通过、专注 API/Widget 聚焦 33/33、`flutter analyze` 无 issue、全量 801 通过/26 个受保护真实环境用例跳过/0 失败；test 配置 Web release 构建成功。Wasm dry run 仅报告既有 `flutter_secure_storage_web` 的 `dart:html`、`dart:js_util` 与 `package:js` 兼容警告，不影响当前 JavaScript Web 产物。
