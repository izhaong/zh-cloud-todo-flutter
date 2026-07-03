# Claude Code 入口（zh-cloud-todo-flutter）

> 本文件内容与 `AGENTS.md` 保持一致（同一份 Agent 指南，供 Claude Code 直接读取）。修改约定时两份一起更新。

Todo 应用 **唯一 C 端客户端**（**Web / H5**、iOS、Android、macOS、Windows、Linux，均为 Flutter），通过 `/app-api/todo-member` 登录、`/app-api/todo` 与 `/app-api/todo/sync` 与 zh-cloud 后端联调。`zh-cloud-client/apps/todo`（React）**已废弃、不再维护**；后端在 `zh-cloud-service`。

## Coding Principles

已作为全局 `alwaysApply` 规则生效（`zh-cloud/.cursor/rules/karpathy-guidelines.mdc`）。审慎优先于速度；琐碎任务自行判断。

1. **Think Before Coding** — 显式陈述假设；多种解读时摆出来再确认，不要默默选一个；有更简单做法就说；不清楚就停下提问。
2. **Simplicity First** — 用最少代码解决问题；不做没要求的特性、抽象、可配置项；不为不可能的场景写错误处理。
3. **Surgical Changes** — 只动该动的；不顺手"优化"相邻代码、不重构没坏的东西、匹配既有风格；发现无关死代码只提醒不删。
4. **Goal-Driven Execution** — 把任务转成可验证目标（"修 bug" → "先写复现测试再让它通过"），多步任务先列"步骤 → 验证"计划。

## Spec

设计/架构总览见 [spec.md](./spec.md)。**功能级规格以 spec-kit `specs/<NNN>/{spec,plan,tasks}.md` 为唯一事实源**（见 `zh-cloud/.cursor/rules/spec-kit-single-source.mdc`），`spec.md` 仅做仓库级总览，不替代功能规格。

**修改功能、命令、接口契约或输出格式后，须在同一 PR 内同步更新 `spec.md` 与相应规格。**

## Development

仓库根（含 `pubspec.yaml`）执行；Dart SDK `^3.11.4`（见 `pubspec.yaml`）。

```bash
flutter pub get                 # 拉取依赖
flutter analyze                 # 静态分析（flutter_lints）
flutter test                    # 运行 test/ 下的 widget / 单元测试
flutter run -d chrome           # Web / H5；也可 -d macos、windows、linux 或真机
```

联调指定后端环境（默认 `http://127.0.0.1:48080`、租户 `1`）：

```bash
flutter run \
  --dart-define=TODO_API_BASE_URL=http://127.0.0.1:48080 \
  --dart-define=TODO_TENANT_ID=1
```

- 引入 `freezed` / `drift` 等代码生成依赖后，改注解/模型须跑 `dart run build_runner build --delete-conflicting-outputs`（当前脚手架尚未启用）。
- **CI**：根目录 `Jenkinsfile`（GWT `zh-cloud-todo-flutter`）；Jenkins Job 与 MCP 索引见 **`docs/engineering/01-ci-jenkins.md`**。

## Architecture

当前为早期脚手架：Flutter `MaterialApp` + `StatefulWidget` 页面，状态用 `shared_preferences` 持久化（含同步队列雏形 `_SyncQueueItem`），登录通过 `TodoMemberAuthClient`（裸 `http` + Bearer + `tenant-id`）。

```
UI（Flutter Widget / 页面）
  → 业务逻辑（当前：StatefulWidget State；目标：Riverpod Provider/Notifier）
  → 数据层（当前：shared_preferences + http；目标：Drift 离线 + dio + outbox/SyncCoordinator）
  → zh-cloud 后端 /app-api
```

- **目标分层**：UI（go_router 路由） → Logic（Riverpod） → Data（Drift 本地库 + dio 网络 + sync 协调），离线优先、在线增量同步。
- 目标架构细则以父仓 `zh-cloud-docs` 的 `todo/03-architecture/11-前端架构.md` 与 spec-kit 规格为准。

## Project Structure

```
lib/
  main.dart                     # 入口 + TodoHomePage（日历/效率/系统入口、本地状态与同步队列雏形）
  todo_member_auth_client.dart  # todo-member 登录网关（TodoMemberAuthGateway / TodoMemberAuthClient / TodoAuthSession）
  efficiency_dashboard.dart     # 效率工具（四象限 / 番茄 / 习惯 / 倒数）
  system_entry_dashboard.dart   # 系统入口面板
test/
  widget_test.dart              # widget 测试（Fake 网关 + 内存版 SharedPreferences）
pubspec.yaml                    # 依赖与版本
```

- **目标结构**（随功能迭代逐步落地，尚未建立）：`lib/features/{auth,task,list,calendar,focus,habit,...}`、`lib/core/{api,db,sync,storage}`。

## Tech Stack

- **运行时**：Flutter（Dart SDK `^3.11.4`）；Material 3。
- **当前依赖**（`pubspec.yaml`）：`http`（网络）、`shared_preferences`（本地持久化）、`cupertino_icons`；dev：`flutter_test`、`flutter_lints ^6.0.0`。
- **目标技术栈**（规划，尚未引入）：Riverpod（状态）、`go_router`（路由）、Drift（离线 SQLite）、`dio` + Bearer + `tenant-id`（网络）、`freezed` + `build_runner`（模型/代码生成）。
- **测试**：`flutter_test`；外部依赖以 Fake / mock 替身注入（见 Testing Safety）。

## Git Workflow

- **集成线 `develop`，发布线 `main`**；**禁止直推主干**，合并只走 PR；不要沿用上游 `master` 命名。
- 从 `develop` 拉 `feat/*` / `fix/*`（如 `feat/todo-*`、`fix/todo-*`），小步提交，PR 指向 `develop`，描述用 `Fixes #n` / 跨仓 `Refs #n`。
- **commit message 用中文**：`<type>(<scope>): <中文描述>`，`type` 英文小写。
- **Agent 默认不 commit / push，除非用户明确要求。**
- 完整闭环（开工核对分支、合并后 `pull --ff-only`、多仓互链）见 `zh-cloud/.cursor/rules/00-zh-cloud-core.mdc` 与 `git-flow-and-release.mdc`。

## Testing Safety

- **测试绝不能产生真实副作用。** 不连真实后端、不发真实网络请求。
- 网络网关（`TodoMemberAuthGateway`）在测试中用 Fake / mock 实现注入；`shared_preferences` 用 `SharedPreferences.setMockInitialValues` 提供内存版（现有 `test/widget_test.dart` 即如此）。
- 用 `flutter test` 运行；产生的临时文件须在用例结束时清理。

## Key Conventions

- **登录态一体化**：已登录不重复弹登录表单；`Authorization: Bearer <token>` + `tenant-id` 头随请求注入；`async` 回调中操作 `BuildContext` 前先判 `mounted`（见 `.cursor/rules/ux-preferences.mdc`）。
- **后端契约**：登录走 `/app-api/todo-member/**`，业务走 `/app-api/todo/**`，离线同步走 `/app-api/todo/sync/{pull,push}`；响应信封 `{code,msg,data}`，`code != 0` 视为业务错误。后端契约变更须在 `zh-cloud-service`（`service-dev`）配套 PR。
- **规则路由**：`.cursor/rules/00-zh-cloud-core.mdc`（跨仓核心，常驻）、`.cursor/rules/ux-preferences.mdc`（编辑 `**/*.dart` 时）；斜杠命令见 `.cursor/COMMANDS.md`（`/gitea-ops`）；流程见 `.cursor/skills/`。
- **Subagent**：主 `todo-flutter-dev`；兜底 `flutter-dev`；Web Todo 用 `client-dev`；测试/冒烟用 `qa-engineer`。定义在 `.cursor/agents/`。
- **MCP**：优先 `user-dart` MCP；契约对照 Apifox MCP。
- **Token 预算**：先 `rg` 定位再读片段；不要读 `build/`、`.dart_tool/`、`ios/Pods/`、`android/.gradle/` 等生成物目录。
- **安全**：不在对话/日志/代码/提交中泄露密码、Token、Cookie、私钥、AccessKey/Secret；示例用占位符。
