# 实施计划（specs/066）

## 落点与判定分开，判定可测

`lib/features/task/list_drop_target.dart` 放两样东西：

1. `TaskListDropTarget`：纯手势容器。
   - `currentListId == null` 时原样返回 `child`（不存在的落点不该有语义节点，也不该截住拖放）。
   - `onWillAcceptWithDetails` 判「拖来的任务不在这个清单」⇒ 同清单不接受（结论 4）。
   - 命中候选时给 `child` 描一条主色边框（只有边框，不引入新文案、不动布局）。
   - `Semantics(key: 'todo-list-drop-target', container: true, label: '移入当前清单')`
     —— label 挂在**落点自己的节点**上，测试读这个节点的 `label`，不靠全树 `bySemanticsLabel`
     被旁边某个 `Text` 蒙过去。label 用词取源页 `:55` 的效果描述，不自造功能名。
2. `TaskListMoveController`：页侧的落点处理，四条可测主张都在这。
   - 写库调 `repository.update(id, listId: 目标, clearSectionId: true)`，时间安排不传 ⇒ 保持原值（结论 2）。
   - 仓储不可用 / 落库失败 ⇒ 走 `onFailure` 给**可见反馈**，本地数据不动（失败保留已加载数据）。
   - 反馈前比对「此刻查看的清单」还是不是当初那个目标；切走了就不弹（过期响应不覆盖新界面）。
   - 同一任务的多次落点按先后**串行**（后一次不插队写库）。

## 页面接线

`lib/features/task/tasks_by_list_page.dart`：

- `Expanded(child: Padding(child: modeBody))` 改成
  `Expanded(child: TaskListDropTarget(currentListId: 列表模式下的 listId, onAccept: _dropTaskIntoList, child: Padding(...)))`。
- State 里 `_listMove` 懒建控制器，`onFailure` 用 `ScaffoldMessenger` 弹 `SnackBar`，
  与同文件既有的 `_saveBoardLayout` 失败反馈同一路子。

## 测试面

`test/features/task/calendar_task_into_list_test.dart`（6 条，内存 Drift + 真 `TaskRepository`）：

| # | 主张 | 反向怎么做 |
| - | ---- | ---------- |
| 1 | 拖入后换清单、`dueAt` 原值、`sectionId` 变 null、outbox 有记录 | 去掉 `clearSectionId` 或把 `dueAt` 一起写 ⇒ 该条红 |
| 2 | 同清单不接受、不写库 | 把 `onWillAcceptWithDetails` 改成恒真 ⇒ 该条红 |
| 3 | 320px + 1.3 倍字号下语义与不溢出 | 把 label 挂到旁侧 `Text` 而非带 key 节点 ⇒ 该条红 |
| 4 | 仓储不可用给可见反馈且不动数据 | 静默 `return` ⇒ 该条红 |
| 5 | 落库期间切走清单 ⇒ 旧失败提示被抑制 | 去掉目标比对 ⇒ 该条红 |
| 6 | 同一任务两次落点串行 | 去掉 chain ⇒ 第二刀会先落库，该条红 |
