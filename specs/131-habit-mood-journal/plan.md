# 131 计划

- T1 服务端（zh-cloud-service）：`GET /habit/check-in/list` 端点 +
  Resp VO + service/impl + 测试 3 条。
- T2 客户端仓储：`checkIn(note:)` 参数 + `listCheckIns` +
  `HabitCheckInEntry`（moodAndJournal 拆分约定）。
- T3 客户端 UI：打卡弹层（心情五档 + 日志文本）+ 详情页
  「打卡日志」时间轴段；列表行一键打卡保持直达。
- T4 用例（纯函数 5 + widget 3）。
- T5 台账与门禁回写。
