# Todo 常用专注计时器任务

- [x] T001 增加 Timer DTO、CRUD、归档与一键启动 API 红绿合同。
- [x] T002 实现请求隔离的 Timer 列表、紧凑空态和一键启动。
- [x] T003 实现新增/编辑、任务/习惯关联、归档/恢复与删除。
- [x] T004 实现真正 Stopwatch 的恢复、递增和暂停语义。
- [ ] T005 通过语义、320px、全量、Web 与 Claude CLI 门禁。
- [ ] T006 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：滴答官方 Timer/How to Start Focus 对照确认当前缺少用户级 Timer、任务/习惯关联、一键启动、编辑/归档/删除和真正 Stopwatch；当前只完成规格与实施计划。
- 2026-08-02：跨设备 Service 实体方案已确定；Flutter-only 与 JSON/presets 方案因偏离跨设备事实源和实体约束而否决。
- 2026-08-02：API 红测在编译阶段准确缺少 `PomodoroTimerDto` 与 timers/create/update/archive/delete/start 方法；实现强类型 Timer DTO、FREE 空时长省略、完整 CRUD 路由、归档 query 参数、会话 `timerId/habitId` 解析及 Timer start 完整会话校验后，`efficiency_api_contract_test.dart` 7/7 通过。标量 Timer start 响应会抛出契约错误，不伪造活动会话。
- 2026-08-02：Timer 卡片红测先准确找不到“常用专注”；实现独立 Timer section、请求序号隔离、任务/习惯名称、读屏一键开始、失败保留上次成功列表后，新列表/启动、15 秒轮询不阻塞和失败保留用例通过，专注页全量 31/31 通过。成功且为空时保持原首屏紧凑，显式空态与新增入口在管理切片补齐。
- 2026-08-02：Timer 管理红测先准确找不到新增入口；实现名称 1–64 字符与 1–1440 分钟边界、正计时/固定/自定义模式、任务或习惯单一关联、稳定排序、编辑、归档/恢复与删除确认。写操作只在 API 确认后更新列表，失败保留原数据，归档/恢复/删除均明确保留历史专注。专注页 33/33、320px 用例和 `flutter analyze` 通过。
- 2026-08-02：Stopwatch 红测先证明 FREE 会话被错误按 25 分钟剩余时间显示；改为从 `startedAt/pausedAt/pausedSeconds` 恢复已用秒数，运行时递增、暂停时冻结、恢复后继续递增。FREE 启动不再要求或提交伪造目标分钟，也不显示无意义的时长调整；番茄恢复和递减回归保持通过。专注页与 API 联合 43/43，`flutter analyze` 无问题。
- 2026-08-02：T005 本地门禁中，活动/归档 Timer 过期响应隔离和 320px 精确读屏语义用例通过；指定文件格式检查、`flutter analyze`、全量 `flutter test` 和 test 配置 Web release 均退出 0，既有 live 用例仅按其显式 dart-define 开关跳过。Claude Code 2.1.216 以 safe-mode/plan/sonnet/low、3 美元上限对 FR-001–FR-008 只读审查，等待约 80 秒无任何正文，手动终止后仅返回 `Execution error`；未修改文件，本阻塞不覆盖本地门禁结论，T005 保持未完成。
