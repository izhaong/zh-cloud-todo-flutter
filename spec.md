# spec.md — zh-cloud-todo-flutter 设计/架构总览

> **范围说明**：本文件是**仓库级架构总览**，方便 Agent 与新人快速建立全局认知。
> **功能级规格（需求、契约、任务）以 spec-kit `specs/<NNN>/{spec,plan,tasks}.md` 为唯一事实源**（见 `zh-cloud/.cursor/rules/spec-kit-single-source.mdc`），本文件不替代、不与之竞争。
> 修改功能、命令、接口契约或输出格式后，须同步更新本文件与对应规格。

## 1. 定位

zh-cloud 平台 Todo 产品的 **唯一 C 端客户端**（**Web / H5**、iOS、Android、macOS、Windows、Linux，均为 Flutter 构建）。通过 `/app-api/todo-member` 完成会员登录，通过 `/app-api/todo` 与 `/app-api/todo/sync` 与后端 `zh-cloud-service` 联调。`zh-cloud-client/apps/todo`（React）**已废弃、不再维护**。当前处于**早期脚手架**阶段。

## 2. 技术栈

| 维度          | 当前（`pubspec.yaml`）                  | 目标（规划，尚未引入）     |
| ------------- | --------------------------------------- | -------------------------- |
| 运行时        | Flutter，Dart SDK `^3.11.4`，Material 3 | 同左                       |
| 状态管理      | `StatefulWidget` State                  | Riverpod                   |
| 路由          | `MaterialApp` home                      | `go_router`                |
| 网络          | `http` + Bearer + `tenant-id`           | `dio` + 拦截器             |
| 本地存储      | `shared_preferences`                    | Drift（SQLite）+ outbox    |
| 模型/代码生成 | 手写                                    | `freezed` + `build_runner` |
| 测试          | `flutter_test` + `flutter_lints`        | 同左                       |

## 3. 目录结构

```
lib/
  main.dart                     # 入口 + TodoHomePage（日历/效率/系统入口、本地状态与同步队列雏形）
  todo_member_auth_client.dart  # todo-member 登录网关与会话模型
  efficiency_dashboard.dart     # 效率工具（四象限 / 番茄 / 习惯 / 倒数）
  system_entry_dashboard.dart   # 系统入口面板
test/
  widget_test.dart              # widget 测试（Fake 网关 + 内存版 SharedPreferences）
web/                            # Web / H5（index.html、manifest、PWA 图标）
pubspec.yaml
```

- **目标结构**（随功能迭代逐步落地，尚未建立）：`lib/features/{auth,task,list,calendar,focus,habit,...}`、`lib/core/{api,db,sync,storage}`。

## 4. 关键流程

### 4.1 登录（todo-member）

- `TodoMemberAuthClient`（实现 `TodoMemberAuthGateway`）支持：密码登录、发送短信验证码、短信登录、重置密码、登出。
- 请求头：`Content-Type: application/json`、`tenant-id`、登录时附 `terminal: 30`，鉴权接口附 `Authorization: Bearer <token>`。
- 响应信封 `{code,msg,data}`，`code != 0` 抛 `TodoMemberAuthException`；登录成功解析出 `TodoAuthSession`（userId / accessToken / refreshToken / expiresTime / mobile）。
- 会话当前以 `shared_preferences` 持久化（键 `zh_cloud_todo_flutter_state_v2`），已登录不重复弹登录表单。

### 4.2 离线同步与 LWW（目标）

- 当前：本地状态变更入 `_SyncQueueItem` 同步队列雏形，随状态一并持久化。
- 目标：Drift 本地库 + outbox，由 `SyncCoordinator` 驱动 `/app-api/todo/sync/{pull,push}` 增量同步；冲突按 **LWW（Last-Write-Wins，以更新时间为准）** 合并。离线优先、恢复网络后增量推送/拉取。

## 5. 对外契约

- 登录：`/app-api/todo-member/auth/{login,sms-login,send-sms-code,logout}`、`/app-api/todo-member/user/reset-password`。
- 业务：`/app-api/todo/**`。
- 同步：`/app-api/todo/sync/{pull,push}`。
- 默认 API `http://127.0.0.1:48080`、租户 `1`，可用 `--dart-define=TODO_API_BASE_URL`、`--dart-define=TODO_TENANT_ID` 覆盖。
- 后端契约变更须在 `zh-cloud-service`（`service-dev`）配套 PR 并互链。

## 6. 构建与发布

- 常用命令：`flutter pub get`、`flutter analyze`、`flutter test`、`flutter run -d chrome|macos|windows|linux|<device>`；发布构建含 `flutter build web`（产物 `build/web/`）。
- 引入 `freezed` / `drift` 后改注解须跑 `dart run build_runner build --delete-conflicting-outputs`（当前未启用）。
- 分支：`develop` 集成、`main` 发布；合并只走 PR，禁止直推主干；commit 用中文 Conventional Commits。

## 7. 相关文档入口

- Agent 指南：`AGENTS.md` / `CLAUDE.md`；运行与账号：`README.md`。
- 架构文档（父仓）：`zh-cloud-docs` 的 `todo/03-architecture/11-前端架构.md`（并列克隆 `../zh-cloud-docs/todo/...`）。
- 跨仓核心规则：`.cursor/rules/00-zh-cloud-core.mdc`；UX：`.cursor/rules/ux-preferences.mdc`。
- 斜杠命令：`.cursor/COMMANDS.md`；Skills：`.cursor/skills/`；Subagent：`.cursor/agents/`。
