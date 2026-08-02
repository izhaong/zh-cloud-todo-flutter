# Todo 专注统计深化任务

- [x] T001 增加 PomodoroStatsDto 与 day/week/month API 红绿合同。
- [x] T002 实现周期切换与旧响应隔离。
- [x] T003 实现累计卡片、趋势柱和专注日历。
- [x] T004 覆盖失败保留、重试、语义、窄屏与全量门禁。
- [ ] T005 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：源码核对确认 Flutter 仍把 stats 当作 Map 且只渲染两个累计值；当前仅完成规格。
- 2026-08-02：API 红测先得到 `Map<String, dynamic>` 缺少 `totalSessions`、`totalMinutes`、`bestHour`、两类趋势和日均 getter 的 7 个编译错误；实现强类型 DTO 后合同测试转绿。
- 2026-08-02：Widget 覆盖 day/week/month、旧响应隔离、慢切换数据来源、失败保留/重试、首次失败不伪造、趋势/日历读屏语义与 320px；专注页最终 23 项通过，相关回归组 41 项通过。
- 2026-08-02：`flutter analyze` 零问题；全量 666 项通过、26 项受保护 live 用例按安全约定跳过；以 `https://todo-test.zh04.com` 和 tenant `1` 注入的 Web release 构建成功。Wasm dry-run 仅报告仓库既有 `flutter_secure_storage_web` 不兼容提示。
- 2026-08-02：Claude CLI Sonnet 首轮 `VERDICT: PASS` 后指出慢网切换可能误读旧周期数据；实现 `dataPeriod` 来源提示并移除旧统计 Provider，最终复核再次 `VERDICT: PASS`。
- 2026-08-02：Gitea/Jenkins 外部门禁仍沿用 `specs/016-todo-focus-record-management/tasks.md` 的原始错误与推荐恢复步骤；本阶段 T005 待连接恢复后补验，不阻断下一功能片继续。
