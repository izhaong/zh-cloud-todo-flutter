# Todo 常用专注计时器任务

- [x] T001 增加 Timer DTO、CRUD、归档与一键启动 API 红绿合同。
- [x] T002 实现请求隔离的 Timer 列表、紧凑空态和一键启动。
- [x] T003 实现新增/编辑、任务/习惯关联、归档/恢复与删除。
- [ ] T004 实现真正 Stopwatch 的恢复、递增和暂停语义。
- [ ] T005 通过语义、320px、全量、Web 与 Claude CLI 门禁。
- [ ] T006 恢复 Gitea/Jenkins 后补 Issue、PR、合并、develop 构建和 test 证据。

## 执行证据

- 2026-08-02：滴答官方 Timer/How to Start Focus 对照确认当前缺少用户级 Timer、任务/习惯关联、一键启动、编辑/归档/删除和真正 Stopwatch；当前只完成规格与实施计划。
- 2026-08-02：跨设备 Service 实体方案已确定；Flutter-only 与 JSON/presets 方案因偏离跨设备事实源和实体约束而否决。
- 2026-08-02：API 红测在编译阶段准确缺少 `PomodoroTimerDto` 与 timers/create/update/archive/delete/start 方法；实现强类型 Timer DTO、FREE 空时长省略、完整 CRUD 路由、归档 query 参数、会话 `timerId/habitId` 解析及 Timer start 完整会话校验后，`efficiency_api_contract_test.dart` 7/7 通过。标量 Timer start 响应会抛出契约错误，不伪造活动会话。
- 2026-08-02：Timer 卡片红测先准确找不到“常用专注”；实现独立 Timer section、请求序号隔离、任务/习惯名称、读屏一键开始、失败保留上次成功列表后，新列表/启动、15 秒轮询不阻塞和失败保留用例通过，专注页全量 31/31 通过。成功且为空时保持原首屏紧凑，显式空态与新增入口在管理切片补齐。
- 2026-08-02：Timer 管理红测先准确找不到新增入口；实现名称 1–64 字符与 1–1440 分钟边界、正计时/固定/自定义模式、任务或习惯单一关联、稳定排序、编辑、归档/恢复与删除确认。写操作只在 API 确认后更新列表，失败保留原数据，归档/恢复/删除均明确保留历史专注。专注页 33/33、320px 用例和 `flutter analyze` 通过。
