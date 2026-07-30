# Implementation Plan: Todo 清单 Section

## 方案

1. 扩展 Drift schema 并生成模型。
2. 新增 `TaskSectionRepository`，所有写操作与 outbox 保持同事务。
3. 扩展 TaskRepository、Provider 和 SyncCoordinator。
4. 在清单工作区展示 Section，并提供管理与任务归组入口。
5. 增加 Repository、同步和 Widget 回归测试。
6. 使用 Dart MCP 执行 analyze/test，并用 Claude CLI 做只读交叉评审。

## 非目标

- 不新增服务端独立 Section REST API。
- 不把 Section 应用于智能清单。
- 不在本阶段实现跨 Section 的拖拽归组；任务菜单是明确且可访问的写入口。
