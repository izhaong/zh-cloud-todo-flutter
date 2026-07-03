# zh-cloud-todo-flutter

Todo 应用 **唯一 C 端客户端**（**Web / H5**、iOS、Android、macOS、Windows、Linux，均为 Flutter）。

## 状态

| 项       | 说明                                                           |
| -------- | -------------------------------------------------------------- |
| 目录     | 已建立（monorepo 父目录 `zh-cloud/` 下）                       |
| 脚手架   | Flutter 六端工程（含 `web/`）                                  |
| Subagent | **`todo-flutter-dev`**（`.cursor/agents/todo-flutter-dev.md`） |
| 已废弃   | `zh-cloud-client/apps/todo`（React）— 不再维护                 |

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

**Cursor / VS Code**：安装 Dart + Flutter 扩展后，在 **Run and Debug** 选择 `.vscode/launch.json` 中的配置（如 `todo-flutter (macOS · local)`），**F5** 启动；调试工具栏支持 Hot Reload / Hot Restart。

```bash
# Web / H5（Chrome）
flutter run -d chrome \
  --dart-define=TODO_API_BASE_URL=http://127.0.0.1:48080 \
  --dart-define=TODO_TENANT_ID=1

# 桌面 / 移动端：将 -d chrome 换为 macos、windows、linux 或已连接设备
flutter run -d macos \
  --dart-define=TODO_API_BASE_URL=http://127.0.0.1:48080 \
  --dart-define=TODO_TENANT_ID=1
```

## 构建

### Web / H5

```bash
flutter build web --release \
  --dart-define=TODO_API_BASE_URL=https://client-todo-test.zh04.com \
  --dart-define=TODO_TENANT_ID=1
```

### 桌面端（macOS / Linux / Windows）

**正式打包在 GitHub Actions**（非本机、非 Jenkins），见 `docs/engineering/03-github-actions.md`：

- 仓库：https://github.com/izhaong/zh-cloud-todo-flutter
- Workflow：`.github/workflows/desktop.yml`（推送 `v*` tag 或 Actions 手动触发）

本地仅用于调试（与 `desktop.yml` 内步骤一致，直接跑 Flutter 命令）：

```bash
flutter pub get
flutter build macos --release \
  --dart-define=TODO_API_BASE_URL=https://client-todo-test.zh04.com \
  --dart-define=TODO_TENANT_ID=1
# linux / windows 将 macos 换成对应平台
```

CI 产物目录：`.gha-dist/desktop/`（zip 或 tar.gz）。

## CI / 部署

| 交付物                     | 流水线                                                          |
| -------------------------- | --------------------------------------------------------------- |
| **Web/H5** 构建 + 部署更新 | **GitHub Actions** `web.yml`（步骤全在 YAML 内，无 shell 脚本） |
| **桌面** 安装包            | **GitHub Actions** `desktop.yml`                                |
| PR 质量检查                | GitHub `ci.yml`                                                 |
| Gitea webhook 备用         | `Jenkinsfile`（同样无 `scripts/` 依赖）                         |

- **GitHub**：https://github.com/izhaong/zh-cloud-todo-flutter/actions
- **桌面自动更新**：GitHub Release（`docs/engineering/04-desktop-github-release-update.md`）
- **合并后推送**：`git push github develop`（触发 test Web 更新 + 桌面包）
- 文档：`docs/engineering/03-github-actions.md`
- Jenkins 备用：`docs/engineering/01-ci-jenkins.md`
- 部署模板：`deploy/README.md`

## 初始化

在**本目录**执行（与 beecount 风格对齐）：

```bash
flutter pub get
```

依赖栈与 `lib/` 目录结构见 `11-前端架构.md` §3.1–3.2。

## Git 约定

- 若后续拆为独立 Gitea 仓库：从 `develop` 拉 `feature/todo-*` / `fix/todo-*`，PR 合入 `develop`
- 当前位于 `zh-cloud` 父仓时：与 Todo 其它仓 PR 互链（`Refs #n`）
