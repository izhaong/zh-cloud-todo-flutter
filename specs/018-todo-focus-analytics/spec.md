# Todo 专注分析完整度

**状态**：设计完成
**创建日期**：2026-08-02
**后端依赖**：`zh-cloud-service/specs/013-todo-focus-analytics/spec.md`

## 背景

现有专注统计只消费日级趋势与日历。滴答清单官方统计还提供年趋势、每日专注时间段和按任务时间分布，用户才能回答“长期节奏怎样、一天何时专注、时间花在哪些任务上”。

参考：

- [Focus Statistics](https://help.ticktick.com/articles/7055781966800486400)
- [Timer](https://help.ticktick.com/articles/7055781980423585792)

## 需求

- **FR-001**：统计周期增加最近 12 个月；强类型 DTO 解析 `taskDistribution`，月桶标签不得按日格式误显示。
- **FR-002**：按任务分布以真实服务端分钟渲染比例条，显示任务标题、分钟和会话数；空分布明确提示，不伪造“其它”比例。
- **FR-003**：页面提供可键盘操作的日期选择，调用 timeline 合同展示当天已完成专注时间段、模式、任务与备注。
- **FR-004**：timeline 使用独立请求序号隔离旧响应；切换慢、失败和重试时保留并标明上次成功日期，不把旧日期记录误标为新日期。
- **FR-005**：记录新增、编辑、删除或完成后刷新当前统计周期与当前 timeline 日期；失败不清空已有分析。
- **FR-006**：320px 无溢出；任务分布条与时间轴项分别提供任务/分钟/会话和起止时间的读屏语义。

## 验收

- API 测试覆盖 year、任务分布和 timeline 解析/参数。
- Widget 测试覆盖年切换、月标签、分布语义、timeline 日期竞态、失败保留/重试与 320px。
- `flutter analyze`、全量测试、test 配置 Web release 与 Claude CLI 通过。
- Gitea/Jenkins 恢复后补真实 PR、develop 构建与 test 环境证据。
