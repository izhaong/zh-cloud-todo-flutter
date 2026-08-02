# Todo 常用专注计时器

**状态**：设计完成
**创建日期**：2026-08-02
**后端依赖**：`zh-cloud-service/specs/014-todo-focus-timers/spec.md`

## 背景

当前专注页只允许从固定 presets 或临时 CUSTOM 输入启动，每次都要重新选择时长和任务，且所谓 FREE 仍是倒计时。滴答清单 Timer 允许保存高频专注项，绑定任务或习惯，选择番茄/Stopwatch 后一键开始，并支持编辑、归档和删除。

参考：

- [Timer](https://help.ticktick.com/articles/7055781980423585792)
- [How to Start Focus?](https://help.ticktick.com/articles/7055782010496745472)

## 需求

- **FR-001**：增加强类型 `PomodoroTimerDto` 与 list/create/update/archive/delete/start 合同；不得用固定 presets 或本地缓存伪造服务端 Timer。
- **FR-002**：专注页在临时专注控制区之前展示未归档 Timer；卡片显示名称、番茄分钟或“正计时”、当前可见任务/习惯名称，并提供可读屏的一键开始按钮。
- **FR-003**：新增/编辑表单支持 1–64 字符名称、番茄/正计时模式、番茄 1–1440 分钟、任务或习惯二选一及排序值；无关联合法。任务来自当前 Drift 可见未完成且已同步任务，习惯来自当前未归档后端列表。
- **FR-004**：Timer 一键启动只提交 Timer id，并以返回会话进入现有暂停、恢复、调整、完成、取消和多端同步链路；失败保留 Timer 列表和当前会话，不产生乐观假会话。
- **FR-005**：编辑成功更新服务端结果；归档、恢复和删除必须二次确认，失败保留原卡片并显示可重试反馈。归档列表可显式进入，不能与活动列表混淆。
- **FR-006**：`FREE` 使用真正正计时：从服务端 `startedAt/pausedAt/pausedSeconds` 恢复已用秒数，运行时递增、暂停时冻结；不得显示伪造目标分钟或剩余时间。番茄仍倒计时。
- **FR-007**：Timer 加载使用请求序号隔离过期响应；新增、编辑、归档、恢复、删除后刷新当前列表，失败不清空上次成功内容，也不阻塞 15 秒活动会话轮询。
- **FR-008**：320px 无横向溢出；卡片、模式、关联、开始和菜单具备键盘/读屏语义；删除/归档确认文案明确说明历史专注记录不会删除。

## 验收

- API 红绿测试覆盖所有 Timer 路由、字段、归档参数、nullable Stopwatch 分钟与 start 返回会话。
- Widget 红绿测试覆盖列表/空态、任务与习惯关联、一键启动、表单边界、正计时恢复、归档/恢复/删除失败保留、旧响应隔离及 320px。
- `flutter analyze`、全量测试、test 配置 Web release 与 Claude CLI 通过。
- Gitea/Jenkins 恢复后补 Issue、PR、合并、develop 构建和 test 环境证据。

## 后续切片

Timer 详情统计、白噪音、沉浸/全屏、屏幕常亮、悬浮窗、翻转开始、严格模式/允许列表和 iOS Live Activity 分别实施；本规格不得将这些能力记为完成。
