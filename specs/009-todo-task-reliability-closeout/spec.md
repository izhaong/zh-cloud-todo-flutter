# Feature Specification: Todo 推荐任务与可靠性收口

**Feature Branch**: `feat/99-todo-reliability-closeout`  
**Created**: 2026-07-15  
**Status**: 执行中；仅建立 B5 独立规格入口，未完成任何交付任务。  
**Input**: 总控 B5、Flutter #99、Service #187、Docs #55。

## Requirements

- 推荐任务覆盖最近添加、多次改期、长期未完成、即将到来；原因可见且不改原始排序。
- 核心 outbox 支持幂等、失败退避、重试、冲突分类和可恢复副本；Widget 只经 Repository/use-case。
- 固定性能、无障碍、离线恢复、第二设备、桌面/移动和九张视觉基准均需可复现证据。
- 只有 B0–B4 全部达到门槛后才可标记 B5 或任务模块完成。
