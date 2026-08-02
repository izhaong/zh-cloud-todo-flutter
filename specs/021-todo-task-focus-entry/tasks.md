# Todo 从任务入口开始番茄专注任务

- [x] T001 建立任务列表的专注入口红绿合同。
- [x] T002 建立任务详情的专注入口红绿合同。
- [ ] T003 通过格式、静态分析、全量测试、Web 与 Claude CLI 门禁。
- [ ] T004 创建并合入 Gitea PR，并保留 CI/Jenkins 的真实证据。

## 执行证据

- 2026-08-02：依据滴答官方“如何开始专注”审计当前 Flutter。现有 `PomodoroPage` 已支持有效任务 serverId 关联，提醒收件箱已能用其进入专注；任务列表和任务详情尚无入口，因此新建 Issue #247 和本规格。
- 2026-08-02：列表与详情分别先跑出红测，再实现最小入口并转绿。覆盖桌面右键、移动端既有“更多”、详情窄屏/宽屏菜单，以及未同步、已完成、已放弃任务不出现入口；320px 回归通过。
- 2026-08-02：`dart format --output=none --set-exit-if-changed`、`flutter analyze`、受影响的 40 项回归、`flutter test --concurrency=1`（689 通过，26 个显式环境跳过）和测试配置的 Web release build 均成功。两张 selected workspace Golden 基准经人工核验，仅因“转为笔记”动作收纳至统一“更多任务操作”图标而更新；更新后全量 Golden 回归通过。

## 当前阻塞

- Claude CLI 只读审查未给出可验证的输出或 `VERDICT`：两次启动 Claude Code 2.1.216 Sonnet 高强度、仅授予 Read/Glob/Grep 后，均在 90 秒观察期内无 stdout；第二次已显式终止，避免留下无界后台进程。它既不是代码否决也不是审查通过，因此 T003 保持未完成；本地验证结果不受影响。
- Gitea PR、远程 CI 与 Jenkins 证据尚未创建，T004 保持未完成。
