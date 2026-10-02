# Feature Specification: Todo 推荐任务与可靠性收口

**Feature Branch**: `feat/99-todo-reliability-closeout`  
**Created**: 2026-07-15  
**Status**: 执行中；T001–T003 本地契约与自动化证据已完成；T004 固定旅程与 T005 最终 DoD 尚未达到完整验收门槛。
**Input**: 总控 B5、Flutter #99、Service #187、Docs #55。

## Requirements

- 推荐任务覆盖最近添加、多次改期、长期未完成、即将到来；原因可见且不改原始排序。
- 推荐接口请求必须携带客户端本地日期，以及今天起点、明天起点、三天后起点三个 UTC epoch 毫秒值，精确表达 23/24/25 小时的本地日；服务端推荐范围只包含无重复、非今天、未完成任务，“即将到来”只含明天与后天。
- 每条推荐任务右侧提供独立且可读屏的“添加到今天”按钮；点击任务正文仍只打开详情。按钮经 `TaskViewActionRepository` 在同一 Drift 事务更新任务和 task outbox：已有截止时间保留其展示墙钟时刻与固定 IANA 时区语义，无截止时间任务设为今天全天。成功后立即从推荐缓存移除；失败时任务与缓存不得分裂，并提供可见、live-region 恢复反馈。
- 同一推荐任务的添加操作只允许一个进行中请求；重复点击不得产生重复 mutation。任务本来已经属于今天时按幂等成功处理，不新增 outbox，并清理过期推荐缓存。
- Todo Flutter CI/CD 只使用一个根级 Gitea Multibranch Job；Jenkinsfile 不声明 Generic Webhook Trigger、Folder Properties、pollSCM 或 cron，也不按 Job 名推断环境。`develop` 仅路由 test，`main` 仅构建候选，SemVer tag 在同 digest promotion 未实现时必须 fail-closed；新构建排队而不终止旧构建，固定使用 `built-in`、10 分钟超时及 10 次构建/制品保留，部署目录由 Job 参数显式提供，日志不得枚举全部环境变量或参数。
- 推荐刷新失败必须保留上一次成功缓存并给出可见且可被读屏实时感知的恢复反馈；刷新成功后清除失败状态。同一面板的刷新必须串行化，进行中的初始化或手动刷新复用同一请求，结束后才允许下一次刷新。推荐面板、刷新按钮与各任务项必须保持独立语义节点。
- 核心 outbox 支持幂等、失败退避、重试、冲突分类和可恢复副本；Widget 只经 Repository/use-case。
- 原生增强入口不得使用演示任务或伪造任务 ID；平台能力缺失时必须可见降级且不得崩溃。
- Android 与 iOS 必须关闭 Flutter 默认 deep-link 接管，由原生通道单独消费且只接受 `zhcloudtodo://task/add`；冷启动链接只消费一次，热启动链接通过事件通道回传，监听器未建立时只保留最新的合法链接。应用主壳必须作为唯一 URI 消费者，要求唯一非空 `title`，可选 `due` 只接受有效 `YYYY-MM-DD`；合法请求复用快速收集默认值并经 `TaskRepository` 的 Drift + outbox 原子链路串行创建，非法参数与创建失败给出可见反馈。Android 与 iOS 系统分享必须拒绝空文本；Android 便签参数必须拒绝空内容，且仅在 API 34+ 与系统存在处理器时报告成功。Android 今日任务小组件必须由真实 `AppWidgetProvider` 渲染最多五项当前账号 Drift 投影，原生持久化只保存显式更新的最小标题快照，登出、无有效会话或跨账号切换时清空；Android 锁屏重要任务必须只接收最多五项已同步任务的真实服务端 ID 与非空标题，使用 ongoing 私密通知渲染标题，并提供仅含数量的公开锁屏版本。显式空快照、登出、无有效会话或跨账号切换必须清除；非法任务或 Android 13+ 未授权通知时必须失败而非伪造成功。没有设备显示证据时不得把资源或编译成功冒充完整验收；iOS 未实现的 Today/WidgetKit、便签和锁屏能力继续显式降级。
- 固定性能、无障碍、离线恢复、第二设备、桌面/移动和九张视觉基准均需可复现证据。
- 只有 B0–B4 全部达到门槛后才可标记 B5 或任务模块完成。
