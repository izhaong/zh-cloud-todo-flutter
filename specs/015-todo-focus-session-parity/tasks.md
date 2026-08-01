# Todo 专注会话对齐任务

- [ ] T001 增加 service presets 与 complete remark/clientEndAt 的 Flutter API 合同。
- [ ] T002 用服务端预设替换硬编码模式，补 CUSTOM 1–1440 分钟与已同步任务关联。
- [ ] T003 补专注备注、动作失败保留和 15 秒多端状态收敛。
- [ ] T004 通过定向、全量、静态分析、Web release 与 Claude CLI 聚焦复核。
- [ ] T005 恢复 Gitea/Jenkins 后补 Issue、PR、合并、真实 develop 构建及 test 部署证据。

## 执行证据

- 2026-08-02：官方帮助与源码对照确认当前页面硬编码模式、只在初始化恢复会话、无 CUSTOM 输入/模块内任务选择/专注备注；service 已有 presets/CUSTOM/active 合同，但备注字段只存在于 VO 并未持久化。当前只完成规格，T001–T005 保持未勾选。
