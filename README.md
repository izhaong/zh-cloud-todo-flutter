# zh-cloud-todo-flutter

Todo 应用 **唯一 C 端客户端**（**Web / H5**、iOS、Android、macOS、Windows、Linux，均为 Flutter）。

## 状态

| 项         | 说明                                                                 |
| ---------- | -------------------------------------------------------------------- |
| 产品实现   | Flutter 六端工程（含 Web/H5），核心功能、离线存储与同步合同已落地    |
| 数据与会话 | Drift + 原子 outbox；会话使用 Android Keystore / Apple Keychain 加密 |
| 验收状态   | 本地合同与自动回归已通过；真实双设备、物理设备与 iOS 原生设备旅程仍为外部门禁 |
| Subagent   | **`todo-flutter-dev`**（`.cursor/agents/todo-flutter-dev.md`）       |
| 已废弃     | `zh-cloud-client/apps/todo`（React）— 不再维护                       |

## 权威文档

- 产品需求与对照矩阵：`zh-cloud-docs/todo/01_需求阶段/`
- 系统架构 / DB / API：`zh-cloud-docs/todo/02_技术设计/`
- 功能能力事实源：`specs/001-todo-dida-core-parity/{spec,plan,tasks}.md`
- 视觉与响应式事实源：`specs/002-todo-visual-fidelity/{spec,plan,tasks}.md`

## 能力与验收状态

| 门槛 | 已有事实 | 仍未替代的外部证据 |
| ---- | -------- | ------------------ |
| B0 核心能力 | 任务、清单、组织、提醒、重复、协作、效率工具与账号安全均有实现和合同测试 | `zh-cloud-docs/todo` 对照矩阵独立仓同步 |
| B1 离线同步 | Drift/outbox、幂等、重试、冲突、附件与受保护 live 旅程已实现 | 真实账号凭据下的完整 HTTP 与双设备执行 |
| B2 时间提醒 | 固定时区时间、重复、提醒派发、持久调度与 Android 重启恢复合同已实现 | 物理设备到点通知、后台/重启和 iOS 旅程 |
| B3 组织查询 | 文件夹、标签、筛选、搜索、批量、排序和权限隔离已实现 | 真实双账号、测试环境 A/B 固定旅程 |
| B4 可工作视图 | 列表/看板/时间线真实拖拽、Repository/outbox 与 Service 合同已实现 | 显式测试账号下的真实 HTTP、第二设备和固定视觉旅程 |
| B5 可靠性 | 推荐、恢复反馈、TalkBack 键盘、Android 小组件/URL Scheme/分享/锁屏模拟器旅程，以及 iOS URL Scheme/分享编译合同已验证 | 物理设备、其它辅助技术、iOS 设备旅程/锁屏组件、真实断网与完整 DoD |

“实现存在”“本地测试通过”“真实设备/服务端验收通过”是三类独立结论；各规格未勾选项不得由构建成功替代。

## 视觉与响应式基线

Todo 工作区以 `1440×900` Web/PC 桌面视口为第一视觉母版，同时显示全局 rail、任务 sidebar、任务主区和固定详情区。窄屏沿用同一任务流与稳定任务身份，只改变导航和详情容器：

| 档位      | 逻辑宽度      | 导航                               | 详情             |
| --------- | ------------- | ---------------------------------- | ---------------- |
| `wide`    | `>= 1366`     | 固定 56px rail + 272px sidebar     | 固定 432px 右栏  |
| `compact` | `1100–1365`   | 固定 56px rail + 256px sidebar     | end drawer       |
| `tablet`  | `600–1099`    | 固定 56px rail + sidebar drawer    | end drawer/覆盖层 |
| `mobile`  | `< 600`       | 顶栏 + bottom navigation + drawer | 独立全屏详情     |

完整布局、状态与验收矩阵见 `specs/002-todo-visual-fidelity/contracts/workspace-ui-contract.md`。

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

登录成功后会把 todo-member `accessToken` / `refreshToken` 与账号范围写入 `FlutterSecureStorage`（Android Keystore / Apple Keychain），后续 `/app-api/todo/**` 请求使用该 token 和 `tenant-id`；Drift 业务库按 tenant/user 隔离。

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
  --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com \
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
  --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com \
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

## 架构与规格

- 功能能力事实源：`specs/001-todo-dida-core-parity/{spec,plan,tasks}.md`（spec-kit）
- 视觉与响应式事实源：`specs/002-todo-visual-fidelity/{spec,plan,tasks}.md`（spec-kit）
- 目录分层：`lib/core/{api,db,sync,storage}` + `lib/features/*`（Riverpod + go_router + Drift + dio 离线优先架构）
- 响应式 UI 契约：`specs/002-todo-visual-fidelity/contracts/workspace-ui-contract.md`

## Git 约定

- 从 `develop` 拉 `feat/*` / `fix/*`（分支名带 Issue 编号），PR 合入 `develop`
- 与 Todo 其它仓 PR 互链（`Refs #n`）
