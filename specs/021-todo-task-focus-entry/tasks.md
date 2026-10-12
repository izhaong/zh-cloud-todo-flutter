# Todo 从任务入口开始番茄专注任务

- [x] T001 建立任务列表的专注入口红绿合同。
- [x] T002 建立任务详情的专注入口红绿合同。
- [x] T003 通过格式、静态分析、全量测试、Web 与 Claude CLI 门禁。
- [x] T004 创建并合入 Gitea PR，并保留 CI/Jenkins 的真实证据。

## 执行证据

- 2026-08-02：依据滴答官方“如何开始专注”审计当前 Flutter。现有 `PomodoroPage` 已支持有效任务 serverId 关联，提醒收件箱已能用其进入专注；任务列表和任务详情尚无入口，因此新建 Issue #247 和本规格。
- 2026-08-02：列表与详情分别先跑出红测，再实现最小入口并转绿。覆盖桌面右键、移动端既有“更多”、详情窄屏/宽屏菜单，以及未同步、已完成、已放弃任务不出现入口；320px 回归通过。
- 2026-08-02：`dart format --output=none --set-exit-if-changed`、`flutter analyze`、受影响的 40 项回归、`flutter test --concurrency=1`（689 通过，26 个显式环境跳过）和测试配置的 Web release build 均成功。两张 selected workspace Golden 基准经人工核验，仅因“转为笔记”动作收纳至统一“更多任务操作”图标而更新；更新后全量 Golden 回归通过。
- 2026-08-02：PR [#248](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/248) 已从 `codex/247-todo-task-focus-entry` 合并至 `develop`（merge commit `9f23cc7`），远端特性分支已删除。Gitea Actions 对该分支返回 0 个 run；Jenkins MCP 显示控制器可构建、队列为空，但按本仓 SCM URL 和该分支搜索无匹配 Job。因此没有可等待或可判定的远程构建，不能把“无 Job”误记为构建成功。

## Claude CLI 交叉验证

- 初始两次 Claude Code 2.1.216 Sonnet 工具/plan 只读审查在 90 秒观察期内无 stdout；随后改用无工具模式，并通过标准输入按列表入口、详情入口和 Widget 测试三段提供实际已合入代码。三次均返回 `VERDICT: PASS`，分别确认状态/serverId 门禁、窄屏/宽屏详情路由和桌面/移动端/负向测试覆盖；因此 T003 已完成。长输入评审不稳定仍记录为 CLI 使用约束，但不再阻塞本规格。
