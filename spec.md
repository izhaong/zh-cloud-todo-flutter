# spec.md — zh-cloud-todo-flutter 设计/架构总览

> **范围说明**：本文件是**仓库级架构总览**，方便 Agent 与新人快速建立全局认知。
> **功能级规格（需求、契约、任务）以 spec-kit `specs/<NNN>/{spec,plan,tasks}.md` 为唯一事实源**（见 `zh-cloud/.cursor/rules/spec-kit-single-source.mdc`）：`001-todo-dida-core-parity` 负责功能能力，`002-todo-visual-fidelity` 负责视觉与响应式。本文件不替代、不与之竞争。
> 修改功能、命令、接口契约或输出格式后，须同步更新本文件与对应规格。

## 1. 定位

zh-cloud 平台 Todo 产品的 **唯一 C 端客户端**（**Web / H5**、iOS、Android、macOS、Windows、Linux，均为 Flutter 构建）。通过 `/app-api/todo-member` 完成会员登录，通过 `/app-api/todo` 与 `/app-api/todo/sync` 与后端 `zh-cloud-service` 联调。`zh-cloud-client/apps/todo`（React）**已废弃、不再维护**。当前处于功能能力与多端视觉持续交付阶段。

### 1.1 规格事实源

- `specs/001-todo-dida-core-parity/{spec,plan,tasks}.md`：功能能力事实源，定义任务、清单、同步、多视图、日历、效率、提醒、协作与账号能力。
- `specs/002-todo-visual-fidelity/{spec,plan,tasks}.md`：视觉与响应式事实源，定义工作区结构、视觉状态、布局档位、验收视口与 golden 基准。
- `specs/006-todo-task-time-semantics/{spec,plan,tasks}.md`：任务时间、提醒、三类重复模式（含自选日期）与 occurrence 动作的当前实现契约，定义 Drift/outbox、时区、锚点和提醒派发边界。
- `specs/008-todo-task-actionable-views/{spec,plan,tasks}.md`：列表、看板、时间线与共享视图写链路的当前契约，定义来源隔离偏好、任务 mutation 和失败反馈。
- `specs/010-todo-portable-task-import/{spec,plan,tasks}.md`：便携 JSON 任务导入、稳定请求 ID、批次历史与按批回滚的当前实现契约。
- `specs/011-todo-persistent-reminder-scheduling/{spec,plan,tasks}.md`：系统级持久提醒调度、改期撤销与 Android 重启恢复契约。
- `specs/013-todo-sidebar-navigation/{spec,plan,tasks}.md`：智能清单、文件夹/标签树与效率底栏的当前实现契约。
- 两套规格按职责互补；视觉规格不得改写账号、数据、同步、接口或权限语义，功能规格不得复制视觉契约正文。

### 1.2 桌面母版与响应式档位

第一视觉母版为 `1440×900` Web/PC 工作区：固定 56px 全局 rail、272px 任务 sidebar、弹性任务主区和 432px 固定详情区。任务主区保持视觉焦点；跨档位缩放时保留当前 section、listId 与有效 taskId，只切换容器结构。

| 档位      | 逻辑宽度    | 导航                            | 详情              | 主添加入口      |
| --------- | ----------- | ------------------------------- | ----------------- | --------------- |
| `wide`    | `>= 1366`   | 56px rail + 272px sidebar 固定  | 432px 固定右栏    | 主区 QuickAdd   |
| `compact` | `1100–1365` | 56px rail + 256px sidebar 固定  | end drawer        | 主区 QuickAdd   |
| `tablet`  | `600–1099`  | 56px rail 固定，sidebar 为 drawer | end drawer/覆盖层 | 主区 QuickAdd   |
| `mobile`  | `< 600`     | 顶栏 + bottom navigation + drawer | 独立全屏详情      | 单一移动添加入口 |

精确组件边界、状态转换和九个视觉场景见 `specs/002-todo-visual-fidelity/contracts/workspace-ui-contract.md`。

## 2. 技术栈

| 维度          | 当前实现                                                   |
| ------------- | ---------------------------------------------------------- |
| 运行时        | Flutter，Dart SDK `^3.11.4`，Material 3                    |
| 状态管理      | Riverpod Provider / Notifier                               |
| 路由          | `go_router` + 响应式详情容器                               |
| 网络          | dio + Bearer + `tenant-id` 拦截器                          |
| 本地存储      | Drift（SQLite）+ 原子 outbox；账号会话使用安全/偏好存储    |
| 模型/代码生成 | Drift generator、`freezed`、`json_serializable`、build_runner |
| 测试          | `flutter_test`、内存/文件 Drift、Fake API 与受保护真实环境用例 |

## 3. 目录结构

```
lib/
  main.dart                     # bootstrap
  app.dart                      # ProviderScope、go_router 与生命周期
  core/
    api/                        # dio 客户端与 REST 契约
    db/                         # Drift 表、迁移与查询
    notification/               # 本地通知与持久调度
    storage/                    # 会话存储
    sync/                       # outbox、pull/push、冲突恢复
  features/                     # task/list/tag/filter/calendar/efficiency 等功能
  state/
    providers.dart              # 依赖装配
    repositories/               # 离线优先业务写链路
test/
  ...                           # 单元、Widget、迁移、同步与受保护真实环境测试
web/                            # Web / H5（index.html、manifest、PWA 图标）
pubspec.yaml
```

## 4. 关键流程

### 4.1 登录（todo-member）

- `AuthGatewayImpl`（实现 `AuthGateway`，复用 dio `ApiClient`）支持：密码登录、发送短信验证码、短信登录、重置密码、登出与会话校验。
- 请求头：`Content-Type: application/json`、`tenant-id`、登录时附 `terminal: 30`，鉴权接口附 `Authorization: Bearer <token>`。
- 响应信封 `{code,msg,data}`，`code != 0` 抛 `TodoMemberAuthException`；登录成功解析出 `TodoAuthSession`（userId / accessToken / refreshToken / expiresTime / mobile）。
- 会话通过 `SessionStore` 持久化并由 Riverpod 会话控制器恢复；业务 Drift 数据库按 tenant/user 隔离，已登录不重复弹登录表单。
- 登录表现层按 900px 断点适配：宽屏使用“今日节奏 + 表单”双栏并垂直居中，窄屏使用表单优先单栏；密码、验证码、注册与重置密码四种模式保持同一卡片层级。
- 表单支持密码显示/隐藏、手机号/密码/验证码自动填充提示、键盘焦点、动态错误播报，以及 320px / 200% 文本缩放 / 深色主题无溢出回归。设计与验收见 [`specs/003-todo-auth-visual-polish/`](specs/003-todo-auth-visual-polish/)。
- 账号启用 RFC 6238 TOTP 后，密码与短信登录会根据后端业务码展示独立的 6 位动态码字段并保留原表单内容；账户安全页通过 `setup → confirm` 完成认证器绑定，关闭时必须提交当前动态码。
- 账户安全页可生成服务端不可变 JSON 数据快照；READY 记录通过当前会员登录态和租户头下载字节，再交给系统保存对话框落盘，不暴露或跳转无鉴权裸链接。
- 设置页可选择上述导出文件或根级 `tasks` 便携 JSON，将标题、说明、截止时间、优先级与完成状态导入到本人已同步清单；同一文件的忙碌重试复用请求 ID，并提供当前用户批次历史与按批回滚。

### 4.2 离线同步与 LWW

- Drift 本地库 + outbox 已落地，由 `SyncCoordinator` 驱动 `/app-api/todo/sync/{pull,push}` 增量同步；临时网络失败保留原 `clientMutationId`，以最早 outbox mutation 作为稳定批次 `idempotency_key` 并标记为 `retryable`，在下次同步继续推送；冲突按 **LWW（Last-Write-Wins，以更新时间为准）** 合并并保持 `failed` 供用户恢复。任务完成统一以 `status` 与 `completedAt` 推送；拉取将 `completedAt`、重复父任务、重复规则和 occurrence 映射为本地 UUID，离线完成后能回放 `ON_COMPLETE` 生成的下一实例。
- 提醒规则由 `ReminderRepository` 在同一 Drift 事务中写本地规则与 `reminder` outbox；详情页可编辑已有规则并保持 UUID，四类锚点严格区分指定时间 `ABSOLUTE`、开始 `START`、截止 `DUE` 和时间段结束 `END`。相对提醒以任务锚点减去提前分钟数计算 `fireAt`，派发后的完成、忽略、开始专注和稍后动作使用独立 outbox 实体；收件箱以同一派发 ID 的最新本地动作覆盖远端旧待处理状态，避免离线期间重复提交。
- 提醒收件箱中的未来派发由操作系统持久调度；同一派发 ID 的时间变化会覆盖旧调度，派发撤销会取消本地通知。Android 注册开机恢复接收器，设备重启或应用升级后由通知插件恢复尚未触发的提醒。
- 任务工作区的视图模式以 `list:<local UUID>` 或稳定智能来源键隔离保存；Widget 只上报选择，由 `TaskViewActionRepository` 在同一 Drift 事务写入 `view_preference` 与 outbox。切换清单或智能来源时先恢复该来源偏好，不复用其它来源的看板、时间线或列表模式。
- 看板整卡长按用于跨列移动，独立“拖动排序”手柄用于列内顺序；两个命中区域不得互相竞争，列内结果仍通过共享 Repository 写入 Drift 与 outbox。
- 时间线提供按来源隔离并跨端同步的日/周/月尺度，可按当前尺度浏览前后窗口并随时回到今天；有完整起止时间的任务按当前尺度绘制为横向连续任务条，任务条位置代表开始时间、长度代表持续时间，跨越当前可见日/周/月的部分按边界裁剪，重叠任务分行展示。无开始、结束和截止日期的任务独立显示在“安排任务（无日期）”，可拖入当前尺度的小时或日期格。日尺度空白小时可创建一小时非全天任务，周/月尺度空白日期可创建一天的全天任务，创建通过 `TaskRepository` 原子写入 Drift 与 task outbox。安排、移动和时长调整统一通过 `TaskViewActionRepository` 写入 Drift 与 outbox：日尺度下非全天任务本体按小时横向移动，周/月尺度按天移动，全天任务始终按天移动；右边缘对非全天任务按小时、全天任务按天调整。按钮入口继续作为键盘与无障碍替代操作。
- 任务详情的检查事项使用独立拖拽手柄；完整 UUID 顺序由 `TaskRepository` 原子写入 Drift 并逐项进入 task outbox，只读拒绝保持原顺序并显示服务端权限原因。

### 4.3 效率工具

- 四象限、番茄专注、习惯打卡、倒数纪念日和成就勋章均消费当前会员的真实 `/app-api/todo/**` 数据，不使用本地演示状态。
- 成就墙只读展示服务端计算的成就值、等级进度以及已获得和未解锁勋章；加载失败可重试，不在客户端伪造积分或授予规则。

### 4.4 原生增强

- 设置页的“原生增强”入口只消费当前账号 Drift 中的真实任务：今日任务用于应用内小组件预览、系统分享和桌面便签草稿，已完成或已取消任务不参与投影。
- 锁屏投影包含优先级不低于 2 或已置顶的活动任务；只向平台通道传递已同步的服务端任务 ID，离线任务显示未同步数量且不伪造 ID。
- 未注册 `zh_cloud_todo/native` 平台通道时，URL Scheme、系统分享、桌面便签、锁屏任务和小组件接口必须安全返回“不支持”或空结果。Android/iOS 等平台侧真实 Widget、Share 与 URL Scheme handler 尚未实现，不计作系统原生能力完成。

### 4.5 清单协作

- 清单 owner 按会员手机号邀请成员，并显式选择 `editor`（可编辑）或 `viewer`（只读）；客户端不得把 owner 当作可分配角色，也不得使用本地用户 ID 代替后端 `userMobile` 契约。
- 成员列表展示后端 `owner/editor/viewer` 角色、`invited/active/exited/removed` 状态以及可用的用户名、邮箱或脱敏手机号。owner 可将非 owner 成员切换为 editor/viewer 或移除。
- 被邀请成员通过 `/list/{listId}/member/join` 接受邀请；active 非 owner 成员可退出协作。角色更新严格使用后端 `PATCH /list/{listId}/members/{userId}` 契约。
- 任务指派查询解析服务端 `assigneeUserId/assigneeUserName/assigneeUserEmail`，设置时提交 `{assigneeUserId}`；界面只列出所属清单的 active 成员，且仅 owner 或 active editor 可修改或移除执行人。
- 评论列表解析后端 `userName/userEmail/createTime/updateTime` 并展示真实作者；owner/active editor 可新增评论，作者可编辑自己的评论，owner 还可删除其他成员评论，viewer 只读。删除使用带任务归属校验的 `DELETE /task/{taskId}/comments/{commentId}`。
- 任务动态消费后端 `createTime` 与 actor 用户资料，并覆盖任务增删改、时间调整、完成状态、执行人和评论的全部现行动作标签；网络失败时继续展示 Drift 缓存。

## 5. 对外契约

- 登录：`/app-api/todo-member/auth/{login,sms-login,send-sms-code,logout}`、`/app-api/todo-member/user/reset-password`；已启用双重验证的登录请求携带可选 `twoFactorCode`。
- 业务：`/app-api/todo/**`；任务重排 `PUT /task/reorder` 使用 `listId + items[{id, sortOrder}]`，任务完成与取消完成 `POST /task/{complete,uncomplete}` 通过查询参数提交数值 `id`，这些直连助手仅作为 API 契约/真实 HTTP 对照，Widget 核心写路径仍走 Repository/outbox；检查事项直连助手使用 `/task-hierarchy/checklist` 及其 `create/update/delete` 子路由，请求字段对齐后端 `taskId/name/assigneeUserId/sortOrder` 与 `id/name/done`，删除通过 `DELETE` 查询参数提交；标签直连助手使用 `POST /tag/task-bind` 批量提交数值 `taskId + tagIds[]`，解绑使用 `DELETE /tag/task-unbind` 提交数值 `taskId + tagId`；自然语言解析使用 `POST /nlp/parse` 提交 1–200 字符的 `text`，读取后端 `planDate/reminderTime/priority`，兼容截止时间助手以 `planDate` 为准；提醒完成、忽略和延后直连 `/reminder-action/{complete,dismiss,snooze}` 时提交派发记录字段 `reminderDispatchId`，持续提醒路由才使用提醒规则 ID；效率域成就墙使用 `/achievement/wall`；双重验证使用 `/security/2fa/{status,setup,confirm,disable}`，setup 返回 Base32 密钥与标准 `otpauth` URI；数据导出使用 `/security/export`、`/security/export/list`、`/security/export/{id}/download`，下载请求复用会话鉴权；任务导入使用 `/import-health/tasks`、`/import-health/task-batches` 与 `/import-health/rollback`。
- 同步：`/app-api/todo/sync/{pull,push}`。
- 默认 API `http://127.0.0.1:48080`、租户 `1`，可用 `--dart-define=TODO_API_BASE_URL`、`--dart-define=TODO_TENANT_ID` 覆盖。
- 后端契约变更须在 `zh-cloud-service`（`service-dev`）配套 PR 并互链。

## 6. 构建与发布

- 常用命令：`flutter pub get`、`flutter analyze`、`flutter test`、`flutter run -d chrome|macos|windows|linux|<device>`；发布构建含 `flutter build web`（产物 `build/web/`）。
- Gitea 共享 runner 的功能门禁执行 `flutter test --exclude-tags 'golden || performance'`；golden 与文件型 SQLite 微基准在匹配的本地/专用环境单独执行，避免共享机器负载把绝对耗时阈值变成随机门禁。
- Web 发布工作流复用同一共享 runner 测试门禁；Linux 桌面 runner 需安装 Flutter secure storage CMake 配置依赖 `libsecret-1-dev`。
- 修改 Drift 表或生成模型后，运行 `dart run build_runner build --delete-conflicting-outputs` 并提交生成文件。
- 分支：`develop` 集成、`main` 发布；合并只走 PR，禁止直推主干；commit 用中文 Conventional Commits。

## 7. 相关文档入口

- Agent 指南：`AGENTS.md` / `CLAUDE.md`；运行与账号：`README.md`。
- 功能能力规格：`specs/001-todo-dida-core-parity/`；视觉与响应式规格：`specs/002-todo-visual-fidelity/`。
- 架构文档（父仓）：`zh-cloud-docs` 的 `todo/03-architecture/11-前端架构.md`（并列克隆 `../zh-cloud-docs/todo/...`）。
- 跨仓核心规则：`.cursor/rules/00-zh-cloud-core.mdc`；UX：`.cursor/rules/ux-preferences.mdc`。
- 斜杠命令：`.cursor/COMMANDS.md`；Skills：`.cursor/skills/`；Subagent：`.cursor/agents/`。
