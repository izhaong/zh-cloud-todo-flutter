# Todo 专注计时调整与记录管理任务

- [x] T001 增加 adjust/backfill/page/updateDuration/deleteRecord API 红绿合同。
- [x] T002 实现活动会话 ±5 分钟且失败不漂移。
- [x] T003 实现真实记录列表、新增、编辑/追加和确认删除。
- [x] T004 覆盖失败保留、重试、窄屏、全量门禁与 Claude CLI。
- [ ] T005 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：官方帮助与源码对照确认 Flutter 缺少活动时间调整和完整记录管理；当前仅完成规格。
- 2026-08-02：API 红测先得到 adjust/backfill/page/updateDuration/deleteRecord 五个缺失方法的编译错误；实现后 API 与 Widget 最终定向共 20 个测试通过。
- 2026-08-02：`flutter analyze` 零问题；全量 659 个测试通过、26 个显式 live 用例按安全约定跳过；test 地址配置的 Web release 构建成功。Wasm dry-run 仅报告仓库既有 `flutter_secure_storage_web` 不兼容提示。
- 2026-08-02：Claude Code 2.1.216 Sonnet 首轮终审 `VERDICT: PASS`；其建议的 adjust 后刷新、成功编辑 UI 断言与 0 分钟边界均已落实。第二轮终审超过约 4 分钟无输出后进程结束，未形成新的 verdict；最终新增的轮询/调整竞态由专门回归测试覆盖。
- 2026-08-02：Jenkins MCP `getStatus` 再次约 70 秒后因 `https://jenkins.zh04.com/mcp-server/stateless` 传输失败；Gitea `ls-remote develop` 约 30 秒无响应后主动中止。T005 继续保留，未把本地验证等同于远端闭环。
