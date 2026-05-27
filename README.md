# zh-cloud-todo-flutter

Todo 应用 **Flutter 多端客户端**（iOS / Android / macOS / Windows / Linux）。

## 状态

| 项 | 说明 |
| --- | --- |
| 目录 | 已建立（monorepo 父目录 `zh-cloud/` 下） |
| 脚手架 | 已初始化 Flutter 多端工程 |
| Subagent | 移动端开发委派 **`flutter-dev`**（`.cursor/agents/flutter-dev.md`） |
| Web 端 | `zh-cloud-client/apps/todo` — 委派 **`frontend-dev`** |

## 权威文档

- 前端架构（Flutter 栈、目录、离线同步）：[`docs/todo/03-architecture/11-前端架构.md`](../docs/todo/03-architecture/11-前端架构.md) §3
- 编排与委派：[`docs/todo/02-requirements/10-角色Subagent与Phase编排.md`](../docs/todo/02-requirements/10-角色Subagent与Phase编排.md)
- 父 Plan：`.cursor/plans/todo/202605232140_todo_core_app-architecture.plan.md`

## API 契约

- 认证：`/app-api/todo-member/**`
- 业务：`/app-api/todo/**`
- 同步：`/app-api/todo/sync/{pull,push}`

## 账号入口

客户端启动后，未登录状态会先进入 Todo 账号页：

- 密码登录：`POST /app-api/todo-member/auth/login`
- 短信验证码登录：`POST /app-api/todo-member/auth/send-sms-code`（`scene=1`）后调用 `POST /app-api/todo-member/auth/sms-login`
- 注册：复用短信验证码登录，新手机号由 todo-member 后端按“短信登录即注册”创建账号
- 忘记密码：`POST /app-api/todo-member/auth/send-sms-code`（当前后端 `MEMBER_RESET_PASSWORD` 为 `scene=4`）后调用 `PUT /app-api/todo-member/user/reset-password`

登录成功后会持久化 todo-member `accessToken` / `refreshToken` 到本地偏好缓存，后续 `/app-api/todo/**` 请求应使用该 token 和 `tenant-id`。

## 运行

默认 API 基址是 `http://127.0.0.1:48080`，默认租户是 `1`。联调其它环境时使用 Dart define：

```bash
flutter run \
  --dart-define=TODO_API_BASE_URL=http://127.0.0.1:48080 \
  --dart-define=TODO_TENANT_ID=1
```

## 初始化

在**本目录**执行（与 beecount 风格对齐）：

```bash
flutter pub get
```

依赖栈与 `lib/` 目录结构见 `11-前端架构.md` §3.1–3.2。

## Git 约定

- 若后续拆为独立 Gitea 仓库：从 `develop` 拉 `feature/todo-*` / `fix/todo-*`，PR 合入 `develop`
- 当前位于 `zh-cloud` 父仓时：与 Todo 其它仓 PR 互链（`Refs #n`）
