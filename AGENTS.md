# Agent 入口（zh-cloud-todo-flutter）

Todo 应用 **Flutter 多端客户端**（iOS / Android / macOS / Windows / Linux）。默认只读本文件与当前任务相关 `lib/`；架构与契约在父仓 **`docs/todo/`**，Web 端在 **`zh-cloud-client`**。

## Token 预算

- 先用 `rg` / `rg --files` 定位，再读取目标文件片段。
- 不要读取 `build/`、`.dart_tool/`、`ios/Pods/`、`android/.gradle/`、生成物目录。
- 功能改动优先限制到 `lib/features/`、`lib/core/` 中与任务相关的子目录。

## 工程事实

- 产品：Todo 多端客户端；Web 端见 `zh-cloud-client/apps/todo`。
- 技术栈：Flutter 3.6+、Riverpod、`go_router`、Drift 离线、`dio` + Bearer + `tenant-id`、`freezed` + `build_runner`。
- API：`/app-api/todo-member/**`、`/app-api/todo/**`、`/app-api/todo/sync/{pull,push}`。
- 默认 API：`http://127.0.0.1:48080`，租户 `1`（`--dart-define` 可覆盖）。
- 架构文档：`zh-cloud-docs` 仓库 `todo/03-architecture/11-前端架构.md`（并列克隆：`../zh-cloud-docs/todo/...`）。
- 执行计划：本仓或 `zh-cloud-docs/todo/00_项目管理/项目计划与排期/执行计划/`。

## 规则路由

- **常驻核心**：`.cursor/rules/00-zh-cloud-core.mdc`。
- **UX**：`.cursor/rules/ux-preferences.mdc`（编辑 `**/*.dart` 时）。
- **斜杠命令**：`.cursor/COMMANDS.md`（`/gitea-ops`）。
- **Skills**：`.cursor/skills/`（`flutter-apply-architecture-best-practices` 等）。
- 后端契约变更：标注需 **`zh-cloud-service`**（`service-dev`）PR。

## 命令

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d macos   # 或 chrome / 真机
```

联调其它环境：

```bash
flutter run \
  --dart-define=TODO_API_BASE_URL=http://127.0.0.1:48080 \
  --dart-define=TODO_TENANT_ID=1
```

## 开发约定

- 目录目标结构：`lib/features/{auth,task,list,...}`、`lib/core/{api,db,sync,storage}`。
- 改注解/模型后须跑 `build_runner`。
- Git：从 `develop` 拉 `feat/todo-*` / `fix/todo-*`；commit 中文 Conventional Commits；用户未要求不 push。
- MCP：优先 **`user-dart` MCP**；契约对照 Apifox MCP。

## Subagent

本仓 Subagent 定义在 **[`.cursor/agents/`](.cursor/agents/README.md)**（随本仓库 Git 提交）。

| 优先级 | `name`             | 场景                           |
| ------ | ------------------ | ------------------------------ |
| **主** | `todo-flutter-dev` | Flutter Todo、Drift、sync 联调 |
| 兜底   | `flutter-dev`      | 通用 Flutter / Dart MCP        |
| 关联   | `client-dev`       | Web Todo（`zh-cloud-client`）  |
| 协作   | `qa-engineer`      | `flutter test`、多端冒烟       |

后端 todo 模块变更标注 **`service-dev`** PR。
