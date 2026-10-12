# Agent 入口（zh-cloud-todo-flutter）

> 本文件内容与 `CLAUDE.md` 保持一致（同一份 Agent 指南，供 Codex / Cursor 读取）。修改约定时两份一起更新。

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

- 修改 Drift 表或生成模型后，运行 `dart run build_runner build --delete-conflicting-outputs` 并提交生成文件。
- **CI/CD**：GitHub Actions 负责 PR、Web/H5 与桌面交付；根目录 `Jenkinsfile` 是 Gitea webhook 备用入口。见 `docs/engineering/01-ci-jenkins.md`、`03-github-actions.md`。

## Architecture

当前为 Riverpod + go_router + Drift + dio 的离线优先客户端。业务写入先在 Drift 事务中落本地实体与 outbox，再由 `SyncCoordinator` 调用 `/app-api/todo/sync/{pull,push}`；视图只通过 Repository/Provider 读写，不直接拼同步请求。

```
UI（Flutter Widget / go_router）
  → State（Riverpod Provider / Notifier）
  → Repository（Drift 本地事实源 + 原子 outbox）
  → SyncCoordinator / dio ApiClient
  → zh-cloud 后端 /app-api/todo
```

- 账号会话经 `SessionStore` 持久化；业务数据按 tenant/user 使用独立 Drift 数据库，避免跨账号污染。
- 架构细则以父仓 `zh-cloud-docs` 的 Todo 前端架构与本仓 spec-kit 规格为准。

## Project Structure

```
lib/
  main.dart                     # bootstrap
  app.dart                      # ProviderScope、路由与应用生命周期
  core/
    api/                        # dio ApiClient 与业务契约
    db/                         # Drift 表、迁移与查询
    notification/               # 本地通知与持久调度
    storage/                    # 会话存储
    sync/                       # outbox、pull/push 与冲突处理
  features/                     # task/list/tag/filter/calendar/efficiency 等页面
  state/
    providers.dart              # 依赖装配
    repositories/               # 离线优先业务写链路
test/
  ...                           # 单元、Widget、迁移、同步与受保护真实环境测试
pubspec.yaml                    # 依赖与版本
```

## Tech Stack

- **运行时**：Flutter（Dart SDK `^3.11.4`）；Material 3。
- **状态/路由**：Riverpod、`go_router`。
- **数据/网络**：Drift SQLite + outbox、dio + Bearer + `tenant-id`。
- **系统能力**：`flutter_local_notifications`、`timezone`、`flutter_secure_storage`、文件与 URL launcher 插件。
- **模型/生成**：Drift generator、`freezed`、`json_serializable`、`build_runner`。
- **测试**：`flutter_test`；外部依赖以 Fake / mock 替身注入（见 Testing Safety）。

## Git Workflow

- **集成线 `develop`，发布线 `main`**；**禁止直推主干**，合并只走 PR；不要沿用上游 `master` 命名。
- 从 `develop` 拉 `feat/*` / `fix/*`（如 `feat/todo-*`、`fix/todo-*`），小步提交，PR 指向 `develop`，描述用 `Fixes #n` / 跨仓 `Refs #n`。
- **commit message 用中文**：`<type>(<scope>): <中文描述>`，`type` 英文小写。
- **Agent 默认不 commit / push，除非用户明确要求。**
- 完整闭环（开工核对分支、合并后 `pull --ff-only`、多仓互链）见 `zh-cloud/.cursor/rules/00-zh-cloud-core.mdc` 与 `git-flow-and-release.mdc`。

## Testing Safety

- **测试绝不能产生真实副作用。** 不连真实后端、不发真实网络请求。
- 网络网关在测试中用 Fake / mock 注入；Drift 使用内存或临时文件数据库，`shared_preferences` 使用内存替身。
- 用 `flutter test` 运行；产生的临时文件须在用例结束时清理。

## Key Conventions

- **登录态一体化**：已登录不重复弹登录表单；`Authorization: Bearer <token>` + `tenant-id` 头随请求注入；`async` 回调中操作 `BuildContext` 前先判 `mounted`（见 `.cursor/rules/ux-preferences.mdc`）。
- **后端契约**：登录走 `/app-api/todo-member/**`，业务走 `/app-api/todo/**`，离线同步走 `/app-api/todo/sync/{pull,push}`；响应信封 `{code,msg,data}`，`code != 0` 视为业务错误。后端契约变更须在 `zh-cloud-service`（`service-dev`）配套 PR。
- **规则路由**：`.cursor/rules/00-zh-cloud-core.mdc`（跨仓核心，常驻）、`.cursor/rules/ux-preferences.mdc`（编辑 `**/*.dart` 时）；斜杠命令见 `.cursor/COMMANDS.md`（`/gitea-ops`）；流程见 `.cursor/skills/`。
- **Subagent**：主 `todo-flutter-dev`；兜底 `flutter-dev`；测试/冒烟用 `qa-engineer`。定义在 `.cursor/agents/`。
- **MCP**：优先 `user-dart` MCP；契约对照 Apifox MCP。
- **Token 预算**：先 `rg` 定位再读片段；不要读 `build/`、`.dart_tool/`、`ios/Pods/`、`android/.gradle/` 等生成物目录。
- **安全**：不在对话/日志/代码/提交中泄露密码、Token、Cookie、私钥、AccessKey/Secret；示例用占位符。
