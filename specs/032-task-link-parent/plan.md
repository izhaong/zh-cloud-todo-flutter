# Todo 关联主任务实施计划

基线：`develop@a1d7733`（specs/023）。分支：`feat/todo-link-parent-task`。

## 不变条件

- 层级、成环、五级上限与只读清单的**唯一裁决点是 `TaskRepository.reparent`**（`task_repository.dart:978`）；
  UI 只做入口与提示，不复制规则。
- 关联成功必须同时落 `todoTasks.parent_task_id` 与 `todoSyncChanges` outbox（由 `_reparentWithinTransaction` 负责）。
- `TaskDetailPane` 的当前任务事实源仍是 `widget.taskId` + `watchById` 实时快照；新增显示项只能订阅，不得自存副本。
- 不改变 9 张黄金基线的可见布局：主任务行只在 `parentTaskId != null` 时渲染，黄金用例选的都是无父任务。

## Task 1：候选排除后代（仓储层）

`task_repository.dart:851` 暴露 `descendantIds(taskId)`（包既有私有 `_collectDescendants`），
供「关联主任务」去掉自己与后代。反向探针：把它换成 `{task.id}` ⇒ 防成环用例红。

## Task 2：详情入口与弹层

`task_detail_pane.dart`：`_TaskDetailAction.linkParent` 菜单项（嵌入态 `_compactMoreActions:830`
与窄屏页 `:2714` 各一处）→ `_linkParentTask:855` 组装候选与当前主任务 → `_ParentTaskSheet:2820`
（`task-parent-sheet` / `task-parent-candidate-<id>` / `task-parent-unlink`）→ `_applyReparent:888`
写库、失败转提示、`sheetContext.mounted` 才 pop。

## Task 3：主任务行与跳转

`_buildParentTaskRow:915` 插在详情 body 标题之前（`:2348`），用 `watchById(parentId)` 保持标题实时；
点击复用 `showTaskDetailSheet`。读屏：`Semantics(container + label + onTap)` 包 `ExcludeSemantics`。

## Task 4：验证与交付

14 条用例（`test/features/task/link_parent_task_test.dart`）+ 十一组反向探针（其中 P5 未能区分机制，边界已记进 tasks.md）+ 六项门禁
+ 只读子代理复核（`claude` CLI 本机不可用，见 `tasks.md` 说明）+ 矩阵回写 + PR。
