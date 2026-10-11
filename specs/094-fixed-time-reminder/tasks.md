# 094 tasks

- [x] 设计定案：客户端换算（B 面服务端契约属 service #312）；生产路径
      `DateTime.toLocal()` 两趟固定点，`deviceZone` 仅测试注入
- [x] 红测：task_time_mode_test.dart「提醒触发瞬间」组 6 条（先红：函数不存在编译错）
- [x] 实现：`reminderTriggerDateTime`（task_time_formatter.dart）
- [x] 绿：6/6
- [x] 接线 poller：任务先取（timeMode/timeZone）→ trigger 换算 → 去重/
      isFuture/payload/fireAt/dispatchState 全键 trigger
- [x] poller 红测 2 条（调度 + 换区重排）；now 取最坏下界之前修测试场景误红
- [x] 探针：语义变异（首行 return remindAt）→ 红 3 条可归因；cp 还原全绿
- [x] 门禁：format 0 changed / analyze No issues / 全量 All tests passed
- [x] selfscan：specs/094-fixed-time-reminder 失项 0
- [ ] PR → 合并 → 关 #371 → 矩阵 #12 面④ 追记 → 父仓 pin
