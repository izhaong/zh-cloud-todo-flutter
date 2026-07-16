# Implementation Plan: Todo 任务收集与完整详情

**Branch**: `feat/91-todo-task-capture-detail` | **Spec**: [spec.md](spec.md)

## Technical Context

Flutter/Dart、Drift、Riverpod、dio 与现有 `SyncChangeQueue`。任务聚合写入通过 Repository 与 outbox；技术 `inbox` 默认归属须作为物理“收集箱”清单先于任务同步，并在拉取时映射回同一内部 ID。仍须持续核验 `ChecklistApi`、`TagApi`、附件和评论/活动是否存在直连缺口。

## Design

1. 先与 Service #179 固定任务详情、checklist、attachment（含二进制文件资产引用与删除）与 activity 的请求、响应、幂等键和错误契约。私有任务活动以服务端为权威：Flutter 仅消费 `/sync/pull` 的 `activity` 变更，按服务端动态 ID 幂等缓存到既有 Drift 表；不得把 activity 加入 outbox、`syncable`、push、冲突写回或 tombstone 删除链路。既有 Activity REST 刷新只作为补充缓存入口。
2. 添加 Drift 子实体和迁移，令 TaskRepository 的聚合写入在同一事务完成并 enqueue；默认收集箱的物理清单变更必须与引用它的新任务保持同批、先清单后任务的顺序。
3. 用 Repository/use-case 替换详情/快速添加的直连调用，再接入既有视觉组件。
4. 以 Service、Repository、Widget、契约和离线重启旅程逐层验收；仅凭页面存在不关闭任务。

## Constitution Check

`.specify/memory/constitution.md` 是未填充模板；以 Flutter `CLAUDE.md`、B0 规格、总控 Plan 和 002 视觉规格为门禁。任何直连 HTTP、无 outbox 的核心写和未经批准的 golden 改动均为阻塞。

## Verification

`flutter analyze`；新增 Repository/Widget 测试；B1 完整 `flutter test`；模拟离线、重启、上传失败、恢复网络及 Service 契约 fixture。
