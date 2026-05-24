# zh-cloud-todo-flutter

Todo 应用 **Flutter 多端客户端**（iOS / Android / macOS / Windows / Linux）。

## 状态

| 项 | 说明 |
| --- | --- |
| 目录 | 已建立（monorepo 父目录 `zh-cloud/` 下） |
| 脚手架 | **待** `flutter create`（见架构文档 §3.1） |
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

## 初始化（Phase 2+ 首任务）

在**本目录**执行（与 beecount 风格对齐）：

```bash
flutter create . --org com.zh04 --platforms ios,android,macos,windows,linux
flutter pub get
```

依赖栈与 `lib/` 目录结构见 `11-前端架构.md` §3.1–3.2。

## Git 约定

- 若后续拆为独立 Gitea 仓库：从 `develop` 拉 `feature/todo-*` / `fix/todo-*`，PR 合入 `develop`
- 当前位于 `zh-cloud` 父仓时：与 Todo 其它仓 PR 互链（`Refs #n`）
