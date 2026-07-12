# Implementation Plan: Todo 任务收集与完整详情

**Branch**: `feat/91-todo-task-capture-detail` | **Spec**: [spec.md](spec.md)

## Technical Context

Flutter/Dart、Drift、Riverpod、dio 与现有 `SyncChangeQueue`。现有 `TaskRepository` 仅覆盖任务主记录；`ChecklistApi`、`TagApi`、附件和评论/活动仍有直连缺口。

## Design

1. 先与 Service #179 固定任务详情、checklist、attachment 与 activity 的请求、响应、幂等键和错误契约。
2. 添加 Drift 子实体和迁移，令 TaskRepository 的聚合写入在同一事务完成并 enqueue。
3. 用 Repository/use-case 替换详情/快速添加的直连调用，再接入既有视觉组件。
4. 以 Service、Repository、Widget、契约和离线重启旅程逐层验收；仅凭页面存在不关闭任务。

## Constitution Check

`.specify/memory/constitution.md` 是未填充模板；以 Flutter `CLAUDE.md`、B0 规格、总控 Plan 和 002 视觉规格为门禁。任何直连 HTTP、无 outbox 的核心写和未经批准的 golden 改动均为阻塞。

## Verification

`flutter analyze`；新增 Repository/Widget 测试；B1 完整 `flutter test`；模拟离线、重启、上传失败、恢复网络及 Service 契约 fixture。
