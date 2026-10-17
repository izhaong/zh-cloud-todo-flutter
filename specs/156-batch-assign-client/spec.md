# 156 · 批量指派的客户端（FL #357 切片二）

## 背景

嘀嗒《02-团队如何协作》`:17`「你也可以在任务列表页，批量指派任务。点击右上角「···」-「批量编辑」
并多选任务，点击右下角「···」- 选择「分配给」进行指派。」

服务端契约那一半已落（`zh-cloud-service` 的 `specs/057-batch-assign-contract`，
`AppTodoTaskBatchUpdateReqVO` 加 `assigneeUserId`）。本切片做客户端。

## 改动

1. `TodoTaskBatchUpdateRequest` 加 `assigneeUserId` + 纳入 `hasChanges()` + `toJson`；
2. `TaskBatchEditCommand` 加 `assigneeUserId`，本地写库跟着落；
3. `TaskBatchAction.assign`（label 逐字用嘀嗒的「分配给」）+ 「更多」菜单一项；
4. `_assignBatchSelection`：
   - **未同步任务整批拒绝并说明**（与单条 `openTaskAssignAction` 同一句
     「任务尚未同步，无法指派」）——**不许静默跳过**；
   - 选人用 `listMembersProvider`，**只列 `active` 成员**（被邀请未接受 / 已退出的不能当执行人，
     列出来点了也只会被服务端拒 —— 那属于"给了个选不了的人"）；
   - 成员**还没取回来**时给一句"请稍后重试"而**不是**当成"没有成员"（空列表 ≠ 没取到）；
   - 走既有的 `_applyBatchEdit` ⇒ **逐项结果**照旧汇总、失败项可重试。

## 一处**有意的**语义：`null` = 这一档不改

```dart
assigneeUserId: command.assigneeUserId == null
    ? const Value.absent()          // ← 不是 Value(null)
    : Value(command.assigneeUserId!),
```

`Value(null)` 会把它写成"**清空执行人**"。**"这一档不改"与"清空"是两件事**，
混成一件会让"批量改优先级"顺手把执行人清光。

## 判据

| 判据 | 说明 |
| --- | --- |
| 两条任务都写上执行人 | 只写第一条 = 用户以为都指派了、实际少了几条（**静默少做**） |
| `assigneeUserId == null` 时**不动**这一档 | 与"清空"分开 |

**反向探针**（两条各自独立验过）：
- 把 `Value.absent()` 退成 `Value(null)` ⇒ 第二条转红；
- 整档不写 ⇒ 第一条转红。

## 边界（下一刀）

- 原单第三条判据「目标清单不是成员的人被拒」由**服务端**负责（逐条按自己的清单校验，
  见 `specs/057`）；客户端只如实汇总**逐项结果**。跨清单批量时会有条目以
  `TODO_TASK_ASSIGNEE_INVALID` 失败 —— 这是服务端的语义，不是客户端静默。
- 「未同步任务整批拒绝」这一条是**界面行为**，本轮用仓库级判据覆盖了数据面
  （不静默写、不静默跳过的前提），界面文案那一条待补 widget 级判据。
