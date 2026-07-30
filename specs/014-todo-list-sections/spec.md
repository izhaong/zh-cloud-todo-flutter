# Feature Specification: Todo 清单 Section

## 目标

在 Flutter Todo 的真实清单内提供 Section 管理与任务归组，保持离线优先、跨端同步和删除不丢任务。层级与滴答清单公开帮助中的 `Folder → List → Section → Task → Subtask` 对齐。

参考：[TickTick - Organize your tasks](https://help.ticktick.com/articles/7055782309420597248)。

## 用户场景

1. 用户在清单工作区创建、改名和调整 Section 顺序。
2. 用户从任务行将任务移动到任一同清单 Section，或移回“未分组”。
3. 用户删除 Section 后，原任务仍存在并显示在未分组。
4. 用户离线完成上述操作，联网后按依赖顺序同步到其他设备。

## 功能需求

### FR-001 本地模型

- Drift schema 22 增加 `todo_task_sections` 和 `todo_tasks.section_id`。
- Section 名称去除首尾空白后必须为 1–255 个字符。
- Repository 拒绝把任务放入其他清单的 Section。

### FR-002 工作区

- 真实清单的列表模式展示 Section 管理条和分组标题。
- 管理条提供创建、重命名、前移、后移、删除。
- 任务菜单提供“移动到分组”，包含未分组和当前清单全部 Section。
- 存在 Section 时禁用旧的跨日期全局拖拽排序，避免排序与归属语义冲突。

### FR-003 离线同步

- outbox 实体使用 `task_section`，push 顺序固定为 list → task_section → task。
- 同批离线创建时，Section 的 `listId` 和任务的 `sectionId` 必须替换为临时服务端 ID。
- pull 按 list → task_section → task 应用；跨页先到的 Section 暂存到父清单落库。
- 整轮分页成功后才推进游标；中断后允许幂等重放。

### FR-004 删除

- 删除事务先清空关联任务 `section_id` 并逐项写 task outbox，再写 Section tombstone。
- 收到远端 Section tombstone 时执行同样的保任务、回未分组语义。

## 验收

- Repository、sync 和 Widget 测试覆盖创建、归组、重排、删除、同批临时 ID、乱序/跨页 pull 与 tombstone。
- `flutter analyze` 无错误；非 golden、非 performance 测试门禁通过。
- 真机双设备和真实服务端验证作为外部验收门禁。
