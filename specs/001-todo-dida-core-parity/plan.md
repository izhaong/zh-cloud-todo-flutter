# Implementation Plan: 滴答清单核心能力对齐（Flutter 客户端重建）

**Branch**: `001-todo-dida-core-parity` | **Date**: 2026-07-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-todo-dida-core-parity/spec.md`；跨仓编排见 `zh-cloud/.cursor/plans/滴答清单对齐交付计划_7dae23b6.plan.md`

## Summary

将 `zh-cloud-todo-flutter` 从「登录真实、业务全本地演示」的脚手架，重建为离线优先、消费 `zh-cloud-service` `yudao-module-todo` 全部 `/app-api/todo/**` 能力的完整客户端：Riverpod 状态管理 + go_router 路由 + Drift 本地库（镜像 sync 白名单实体）+ dio 网络层 + SyncCoordinator 双向同步引擎，逐步替换现有 `main.dart` 单体，覆盖任务/组织/多视图/日历/四象限/番茄/习惯/倒数/提醒/重复/协作/账号安全/最小生态。

## Technical Context

**Language/Version**: Dart（SDK `^3.11.4`，Flutter stable）

**Primary Dependencies**（新增）：`flutter_riverpod`、`riverpod_annotation`、`go_router`、`dio`、`drift` + `sqlite3_flutter_libs`、`freezed` + `freezed_annotation`、`json_serializable`、`build_runner`、`flutter_local_notifications`、`table_calendar`（日历 UI）、`uuid`

**Storage**: Drift（SQLite）本地库，镜像 `list/task/reminder/repeat_rule/repeat_skip/view_preference/tag/task_tag/filter` 九类 sync 白名单实体 + `sync_outbox`/`sync_cursor` 表；效率域（habit/pomodoro/countdown/achievement）与协作域走 REST 直连 + 简单缓存表，不进 sync 引擎

**Testing**: `flutter_test`（widget/unit）+ Fake Repository/Dio adapter（`http_mock_adapter` 或手写 Fake），不连真实后端；契约层用 service 仓已导出的 OpenAPI（`/v3/api-docs/todo`）核对字段

**Target Platform**: iOS / Android / Web（H5）/ macOS / Windows / Linux（Flutter 多端不变）

**Project Type**: Mobile+Web+Desktop 单一 Flutter 工程（非前后端分离项目结构）

**Performance Goals**: 核心任务/清单操作本地响应 < 300ms；同步 pull/push 不阻塞 UI 主线程

**Constraints**: 后端契约以 `zh-cloud-service` 现状为准，不推翻既有表结构；本地通知不依赖远程推送；第三方日历深度集成不在本轮范围（仅 ICS URL）

**Scale/Scope**: 单用户多端离线优先场景；9 类 sync 实体 + 4 类效率域实体 + 协作/账号安全域

## Constitution Check

仓库尚无 `.specify/memory/constitution.md` 自定义条款（模板默认状态），沿用 `zh-cloud` 工作区级 `karpathy-guidelines`（审慎优先、最小改动、外科手术式修改、目标驱动）与本仓 `AGENTS.md`/`CLAUDE.md` 既有约定（Riverpod/go_router/Drift/dio/freezed 为既定目标栈，见仓库 `spec.md`）。无需额外门禁豁免。

## Project Structure

### Documentation (this feature)

```
specs/001-todo-dida-core-parity/
├── spec.md
├── plan.md
├── tasks.md
└── contracts/            # 可选：关键 sync/task 端点字段速记，来源于 service 仓 OpenAPI
```

### Source Code (repository root)

```
lib/
├── core/
│   ├── api/              # dio client、拦截器（Bearer + tenant-id）、各域 REST client
│   ├── db/               # Drift database、tables、daos
│   ├── sync/             # SyncCoordinator、outbox、冲突处理
│   └── storage/          # 会话/偏好本地存储（迁移自 shared_preferences 用法）
├── features/
│   ├── auth/             # 迁移现有 todo_member_auth_client + todo_auth_page
│   ├── task/             # 任务 CRUD、详情、子任务、检查事项
│   ├── organize/         # 清单/文件夹/标签/过滤器/智能清单
│   ├── views/             # 列表/看板/时间线
│   ├── calendar/         # 日历五视图
│   ├── quadrant/         # 四象限
│   ├── reminder/         # 提醒收件箱 + 本地通知
│   ├── repeat/           # 重复规则与实例
│   ├── focus/            # 番茄专注
│   ├── habit/            # 习惯打卡
│   ├── countdown/        # 倒数纪念日
│   ├── collaboration/    # 共享清单成员/评论/动态
│   ├── account/          # 账号安全（改密/2FA/导出）
│   └── calendar_sub/     # ICS 订阅与导出
├── app.dart              # go_router + ProviderScope 组装
└── main.dart             # 入口（瘦身为 bootstrap）
test/
├── core/
└── features/
```

**Structure Decision**: 采用 `lib/core` + `lib/features/*` 分层（对齐仓库既有 `spec.md` 目标架构），逐 feature 迁移替换现有单体 `main.dart`/`efficiency_dashboard.dart`/`system_entry_dashboard.dart`，每个 feature 迁移为一个可独立验证的增量，避免一次性大爆炸重写。

## Complexity Tracking

无宪法冲突，本节不适用。
