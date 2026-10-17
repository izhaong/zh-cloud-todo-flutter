# 150 台账

## T1 复现与量事实

- [x] 探针（`tasks_by_list_page.dart:2319` 改恒假）⇒ #600 那条真红
      （`Found 0 widgets with text containing 任务层级不能超过五级`）。
- [x] 实测拖动期间 `task-row-surface-*` = **2** 个：真行 `(16,134)-(1424,174)`、
      feedback 副本 `(16,134)-(304,174)`。
- [x] 实测 `beforeDropKey=1 / afterDropKey=1 / zoneKey=0`（zoneKey 悬停才建）。
- [x] 实测 `find.descendant(of: Scrollable, matching: rowKey)` = **1**。

## T2 改动

- [x] 新增 `_rowInList(taskId)`；`_startBandHover` 的源行/目标行都走它。
- [x] `_startBandHover`：`_bandCenter` 移到 `startGesture` + pump 之后。

## T3 验证

- [x] 探针 + 修复前：`+58 -3`；探针 + 修复后：`+59 -2`，**#600 那条转绿**。
- [x] 剩下 2 条红是 `task_list_subtask_tree_test` 里断言「默认收起」的用例 ——
      **探针定义上就会让它们红**（探针改掉的正是那道判定），不是回归。
- [x] 正常态 5 个文件：`+61 All tests passed!`

## 过程教训

1. **先量"哪个 key 在静止态真的存在"**：第一版按落点 key 量，用了 `zoneKey` ——
   它是**悬停才建**的高亮节点（production 源码自己写着这条警告），静止态找不到 ⇒ **红了 8 条**。
   而且右下那块（转子任务）**根本没有 `dropKey`**，只能由行矩形推。
   **"用 key 量"听起来比"算比例"稳，但前提是那个 key 真的在。**
2. **自拖那一条会把"量两个"暴露出来**：目标 == 源时，`getSize` 会同时看到真行与 feedback 副本。
   我第一版把落点移到起手势之后、却仍用裸 `find.byKey` ⇒ 自拖那条因为两个匹配而抛错。
   **要把"什么时候量"和"量哪一个"当成两件事分别钉住。**
3. **探针态剩下的红要分清是"没修好"还是"探针本来就该让它红"**：
   本单剩下那 2 条断言的就是探针改掉的那道判定 —— 把它们"修绿"反而是错的。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 探针 + 修复后（5 文件） | `+59 -2`（2 条 = 断言「默认收起」的用例，探针定义上就红） |
| 正常态（5 文件） | `+61 All tests passed!` |
| `flutter analyze` | 见提交信息 |
| 全量（exclude golden/performance） | 见提交信息 |
