# 059 四象限拖动换象限并回写 — 计划

判据与决定见 `spec.md`。本文件只写"怎么做、怎么验"，不重复口径。

## 1 回写式做成纯函数，先钉死取值

`quadrantDropPatch({target, ruleType, now})`（`lib/features/task/views/eisenhower_view.dart`）
返回 `({int priority, DateTime? dueAt})`，`null` = 该档不给拖。

- `custom` ⇒ `null`（源页本节无脉络）。
- `priorityOnly` ⇒ 只给 `priority = 3 - target.index`，`dueAt` 为 `null`。
  依据是 `_ruleKeys` 在 `priorityOnly` 下的键序 `['P3','P2','P1','P0']` 按 Q1..Q4 落位，
  即"目标档位由规则自己给出"，不是我们另定一套。
- `priorityTime` 与 `null`（无生效规则）⇒ 两轴一起给：重要 `3` / 不重要 `1`；
  紧急 `DateTime(y,m,d,23,59)`、不紧急 `_oneMonthLater(now)`。
- `_oneMonthLater` 必须有兜底：`DateTime(2026,1,31)` 加一个月会被 Dart 归一化成 3/3（不是夹到 2/28）。
  兜底条件是"归一化后仍在 `now+2d` 之后"，否则退到 `now+31d`，保证不紧急档不会掉回 24h 窗口。

验证：`flutter test test/features/task/eisenhower_quadrant_drag_test.dart --plain-name 'quadrantDropPatch'`，
其中两条边界用例专门盯"当天 23:59 在一天里任一时钟点都不晚于 `now+24h`"与"1/31 溢出"。

## 2 视图接线：状态化 + 拖拽层

`EisenhowerView` 由 `ConsumerWidget` 改成 `ConsumerStatefulWidget`（要挂写链、要在异步回调里判 `mounted`）。
`_QuadrantTile` 包两层：外层 `DragTarget<QuadrantDragMove>`（`onWillAcceptWithDetails` 拒掉
"同象限"与"该档不回写"），卡片外层 `Semantics(label: '拖动调整象限')` + `LongPressDraggable`。

- 拖起来的数据是 `QuadrantDragMove(task, from)`：`TodoTask` 不知道自己落在哪个象限，
  不带 `from` 就没法证明"拖回原象限不发写"。
- `feedback` 只放限宽 240 的标题卡，不放整块象限格（看板 `kanban_view.dart` 的 `LongPressDraggable` 同形：
  小反馈层 + `pointerDragAnchorStrategy`，全仓没有 `dragAnchorBuilder` 的先例）。
- `childWhenDragging` 用 `Opacity(0.4)`，让"还在这格"和"已经离开"在视觉上分得开。
- 是否可拖只看**生效规则**（`activeRule?.type`），不看"看板数据到没到"：
  看板未加载时显示退回本机两轴，但组合1 的规则仍不该动 `dueAt`。

## 3 同一任务的写操作排队（过期响应不覆盖新响应）

`_writeChain: Map<String, Future<void>>` 按任务 id 串接：`_queueDrop` 把本次写挂到该任务上一次写的尾巴上。
不排队就会出现"先拖的那次请求后落地"，把后一次的结果盖掉。失败路径：`catch` 后只在 `mounted` 时弹
SnackBar，不改本地状态 ⇒ 卡片留在原象限（数据没写成功，视图本来就没动）。

写操作走 `TaskViewActionRepository.moveQuadrantTask`（新增）：`_requireWritableTask` →
`TodoTasksCompanion(priority, dueAt?, allDay?)` → 同事务 `SyncChangeQueue.enqueue`。
`dueAt == null` 时用 `Value.absent()`，这是"组合1 一毫秒都不碰截止时间"的实现前提。

## 4 测试夹具的三个坑（本轮都踩到了，写下来免得下一轮重踩）

1. **必须插 `todoLists` 行**：`moveQuadrantTask` 经 `_requireWritableTask`，清单不存在整笔写抛错，
   表现是"调用记了、库里没变、还弹了失败提示"——看着像实现缺陷，其实是夹具缺行。
   同仓 `test/task_view_action_repository_test.dart` 一开始就插清单行，照它。
2. **同一测试内换 provider override 必须换 `ProviderScope` 的 key**：容器只在创建那一次读 `overrides`，
   第二次 `pumpWidget` 沿用旧容器 ⇒ 正向对照静默失效（"能拖"那半边根本没换规则）。
3. **`find.bySemanticsLabel(String)` 是全等匹配**：卡片节点被 `ListTile` 合并成
   `拖动调整象限\n任务 task-1` ⇒ 传裸串 0 命中，要传 `RegExp`。

## 5 门禁与探针

六道门禁跑在最终字节上；反向探针脚本 `/tmp/r111b/probes.py`（本机临时，不入库）：
把实现逐条改坏，断言"该红的用例红、且红的正是那几条"，跑完还原并复跑对照。结果表在 `tasks.md`。
