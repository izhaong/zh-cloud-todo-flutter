# Tasks: Todo 任务契约审计与冻结

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、Docs #45、Service #177。

## Phase 1: 审计基线

- [x] T001 核对 `lib/core/db/app_database.dart` 的任务、提醒、重复、标签、过滤器、偏好和 outbox 字段，并将缺少的 checklist/attachment/activity 实体登记到 Docs 矩阵。证据：Docs `CAP-10`、`CAP-11`、`CAP-13` 与 B0 领域基线。
- [x] T002 核对 `lib/state/repositories/task_repository.dart` 与 list/folder/tag Repository 的本地事务和 enqueue 行为，列出直连 API 缺口。证据：Docs `CAP-02`、`CAP-09`、`CAP-10`、`CAP-14`、`CAP-19`。
- [x] T003 核对 `lib/core/sync/sync_entities.dart`、`lib/core/sync/sync_coordinator.dart` 的白名单、ID 映射、冲突与重试边界。证据：Docs B0 领域基线与冻结边界第 1–4 条。

## Phase 2: 跨仓契约冻结

- [x] T004 将 TaskAggregate、Schedule、Content、Organization、SyncChange 的字段归属与 B1–B5 迁移顺序写入 Docs 证据矩阵。证据：Docs B0 领域基线、CAP-01 至 CAP-29、冻结边界。
- [x] T005 将 Flutter #89、Service #177、Docs #45 的实际规格和证据路径回填到三个 Issue。证据：三个 Issue 已互链；提交与 PR 创建后补充不可变链接。

## Phase 3: 验证与关闭

- [x] T006 运行 `flutter analyze` 与 B0 指定的定向测试，记录实际结果到 Issue #89。证据：2026-07-12 `flutter analyze` 无问题；定向 21 项通过。
- [x] T007 复核九张视觉基准未变，并确认 B0 没有修改 `lib/`、`test/` 或 golden。证据：2026-07-12 九项 golden 定向测试通过；本分支仅新增 `specs/004-*`。
- [ ] T008 仅在 Docs 矩阵、Flutter/Service Spec 与 Issue 互链完整后关闭 B0；否则保持本文件和总控 Plan 未完成。
