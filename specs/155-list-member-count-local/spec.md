# 155 · 本地落「清单在用成员数」（FL #559 切片：判据的**数据面**）

## 背景

FL #559 要按嘀嗒《02-用清单管理任务》`:21`「收集**来自不同共享清单**中分配给你的任务」
收紧「指派给我」。**判据只能是"这个清单是不是共享的"**，而客户端本地**没有成员表**。

服务端那一半已落：`list` 载荷带 `memberCount`（在用成员数 = `invited` + `active`），
见 `zh-cloud-service` 的 `specs/054-sync-list-member-pull/`（切片二 !400）。
**本切片只做本地那一半的数据面**：把它落到本地、并在 pull 时正确映射。

## 为什么不能复用 `accessRole`

`accessRole` 说的是**我在这个清单里的角色**。**我自己建的、拉了协作者的清单**，
`accessRole` 仍是 `owner` ⇒ 判不出「这是共享清单」—— 而那正是嘀嗒 `:21` 点名的场景。
所以判据必须是 `memberCount > 1`。

## 改动

1. `TodoLists` 加 `memberCount`（`IntColumn`，默认 1）；`schemaVersion` 30 → **31**，
   迁移里用 `_columnExists` 守卫（`from < 31`）；
2. pull 映射：`memberCount`（兼容 `member_count` 驼峰/下划线两种写法）。

## 一处**有意的**取舍：缺键时保留旧值，**不退回 1**

```dart
memberCount: Value(
  (payload['memberCount'] as num?)?.toInt() ??
      (payload['member_count'] as num?)?.toInt() ??
      existing?.memberCount ??     // ← 保留旧值
      1,
),
```

服务端不带这个键时（旧版本），若退回 1，就会把「共享清单」**误判成个人清单** ⇒
**静默丢掉**用户本该看到的任务。
（对照：多显示几条是"看得见的错"，少显示是"看不见的错"。**宁可多，不可少**。）

## 判据

| 判据 | 说明 |
| --- | --- |
| pull 带 `memberCount: 3` ⇒ 落库为 3，且 `accessRole` 仍是 `owner` | 正是"我建的共享清单"那一档 |
| 再 pull 一次**不带**该键 ⇒ 仍是 3 | 缺键保留旧值；退回 1 = 静默丢任务 |

**反向探针**：摘掉 `memberCount` 映射 ⇒ 第一条即红（实测 `Expected: <3> Actual: <1>`）。

## 边界（下一刀）

**判据本身还没改**：「指派给我」目前仍按 `assignee_user_id == 我` 取数。
把 `memberCount > 1` 接进那条查询要动 `task_query_repository` 的过滤（它现在只做任务行内过滤，
拿不到清单行）—— 那是下一刀，本切片只保证**数据面**先到位。


---

## 切片四（收口）：判据接进「指派给我」

`applyTaskFilter` 加 `sharedListIds`（共享清单的 id 集合），在 `lockedAssigneeUserId` 那道闸门之后
**再叠一层**：`lockedAssigneeUserId != null && sharedListIds != null && !sharedListIds.contains(task.listId)`
⇒ 排除。

**徽章同步改**（`TaskStats.fromTasks` 也收 `sharedListIds`）：**两处判据必须同一份** ——
否则会出现「侧栏说 3 条、点进去只有 1 条」，那比两种都错更糟。

**`null` = 索引没就位 ⇒ 不加这道闸门**：宁可多显示，不可少显示
（少显示是"看不见的错"：用户不会知道自己的任务被吞了）。

### 一处必须写下来的语义：**收集箱里的任务永远不进这一档**

判据是清单行上的 `memberCount`，而 **`inbox` 是合成清单、库里没有它的行**
⇒ 收集箱里的任务恒不满足。这与原意一致（收集箱是个人空间，不是"来自不同共享清单"）——
但两个既有用例原来正是拿收集箱里的任务测的，**它们红了是对的**：那两条测的场景
按新判据**本来就不该出现**。改法是**把夹具改对**（移进真实共享清单），不是放宽判据。

### 判据

| 判据 | 说明 |
| --- | --- |
| 个人清单里的自指派不出现 | 判据不能只看 `assigneeUserId` |
| 共享清单里的指派出现 | 正例 |
| `sharedListIds == null` 时放行 | 索引没就位 ⇒ 宁可多 |
| 既有两条端到端用例（面板 / 徽章）改夹具后仍绿 | 徽章与列表**同一判据** |

**反向探针**：摘掉共享闸门 ⇒ 「个人清单里的自指派不出现」转红。
