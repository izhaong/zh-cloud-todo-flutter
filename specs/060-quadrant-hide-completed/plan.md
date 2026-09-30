# 060 实施计划 — 四象限「隐藏已完成」

- 分支：`feat/384-quadrant-hide-completed`，基线 `origin/develop@9032005`
- 判据与决定见同目录 `spec.md`（本文件只写"怎么落地、动了哪些文件、踩过什么坑"）

## 一、改动面（4 个 lib 文件 + 1 个测试文件）

| 文件 | 动什么 | 为什么必须动它 |
| --- | --- | --- |
| `lib/state/repositories/task_view_action_repository.dart` | 新增 `getQuadrantDisplay()` / `saveQuadrantDisplay({showCompletedTasks})`，走既有 `_getTaskWorkspacePreference` / `_saveViewPreference`，sourceType `quadrant_view`、sourceKey `task_quadrant` | 偏好读写必须走这条离线优先链（本地行 + outbox 同一事务），不能由 Widget 拼 payload |
| `lib/features/task/views/eisenhower_view.dart` | 新增顶层纯函数 `quadrantShowsCompleted(...)`；`EisenhowerView` 加 `showCompletedTasks`（缺省 `false`＝现状）；本机分档与远程分档两处 `if (... completed) continue;` 改为 `&& !showCompletedTasks` | spec §二 1 的 3 处硬丢里有 2 处在这个文件里；只改视图不改这两处就是假改 |
| `lib/features/task/widgets/task_workspace_header.dart` | 枚举加 `hideCompleted`；构造参数加 `hideCompleted` / `hideCompletedHint` / `onToggleHideCompleted`；`todo-sort-menu` 里加「隐藏已完成」项（`Key('todo-quadrant-hide-completed')`），hint 非 null 时 `enabled: false` 并把原因写在项里 | 嘀嗒 `:132` 把入口放在**四象限页面右上角「...」**里，那个菜单就是这里 |
| `lib/features/task/tasks_by_list_page.dart` | 状态位 `_hideCompletedInQuadrant`（默认隐藏）+ `_quadrantPreferenceRevision`；`initState` 读偏好；`_toggleQuadrantHideCompleted` 写偏好（失败回退 + SnackBar）；把状态同时接给 header 与 `EisenhowerView`；`_reportInvalidSelection` 的 eisenhower 分支跟着同一把尺 | 第 3 处硬丢在宿主里（`tasks_by_list_page.dart:1323`）；选中态失效判定也读同一批可见任务，两处不同尺就会自相矛盾 |

`classifyEisenhower` 一行没动（spec §四：已完成归 Q4 是既有约定，本轮只在"进不进格子"这一层决定）。

## 二、两道闸的落点（spec §三 2 方案 A）

- 唯一判据函数是 `quadrantShowsCompleted(hideCompleted:, listFilterCompleted:)`：
  清单筛选钉过完成态 ⇒ 以筛选为准（返回 true）；否则由本面开关决定。
- 同一把尺用在三处：视图取数、菜单项是否置灰、选中态失效判定。
  这样"筛已完成 + 象限又全隐藏 ⇒ 空板"这条路径在结构上不存在，不是靠测试兜住的。

## 三、写这批用例时踩到的坑（下一条同类测试别再踩）

1. **页面级用例必须按仓内收尾约定排水**：`task_section_workspace_test.dart:87-90` 那四行
   （`pumpWidget(SizedBox.shrink())` → `pump()` → `container.dispose()` → `pump(Duration.zero)` → `db.close()`）
   不是礼貌动作。Drift 在 `StreamQueryStore.markAsClosed` 里挂一个**零延时定时器**，
   树在测试体结束后才销毁 ⇒ 少了这一步就是 `A Timer is still pending even after the widget tree was disposed`，
   而且报错点看着像"页面有动画"，其实栈里第 6 帧才是 drift。本轮 9 条页面用例全栽过一次。
2. `Duration.zero` 是静态字段不是 const 构造器 ⇒ 写 `const Duration.zero` 直接解析失败。
3. `excludeSemantics` 挂在 `Semantics` 上（"把后代语义一起吞掉"），**不是** `Text` 的参数；
   放错位置是编译错，不是静默无效。
4. 测试辅助函数的 `WidgetTester tester` 要全程一致：要么位置参数要么命名参数。
   本轮先写成位置参数、调用处写 `tester:`，报的是"Too few positional arguments"，看着像实现的问题。
5. Drift 生成的伴随类是**表名复数**：`TodoTasksCompanion`（不是 `TodoTaskCompanion`），数据类才是单数 `TodoTask`。

## 四、验证顺序

红测（`/tmp/r112/red-1.log`，实现前编译红，逐条点名缺的符号）→ 最小实现 →
六道门禁在最终字节上各跑一次 → 反向探针 → `cursor-agent` 交叉验证 → 只读复核 `VERDICT` →
台账自扫 → 回写 `tasks.md`、矩阵 #36 ⑩、PR。
