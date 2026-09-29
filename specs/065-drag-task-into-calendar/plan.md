# 065 · 实施计划 — 清单任务拖入日历（面 ①）

工作树 `/private/tmp/wt-fl-397`，分支 `feat/397-drag-task-into-calendar`，
基 `origin/develop@2d0aa12`（本轮开工时的 develop 尖）。

## 一、先取证，再动字节

1. 读源页 `07-任务与日历同时显示.md` 的 `:45-63`（`spec.md` §一 已按行抄录，四面各对应一个 Issue）。
2. 读 develop 上的接收端：`lib/features/task/views/calendar_view.dart` 的
   `_DayCell` —— 它已经有 `DragTarget<TodoTask>` 与 `onWillAcceptWithDetails`
   （判 `onTaskDateChanged != null`、非外部日历任务、且落点日期 ≠ 当天）。
3. **取证发现的真实缺陷（比 Issue 正文更准）**：并列副栏那个日历是
   `lib/features/home/home_shell.dart` 的 `_CalendarHost` 造的，它当时只传了
   `tasks:` ⇒ 接收端在并列视图里是**死的**（`onTaskDateChanged` 为 null，
   `onWillAcceptWithDetails` 恒假），而且没传 `now:` 时月视图跟随真实时钟，
   清单里的任务压根不在画出来的那个月上。
4. 同仓先例：`lib/features/task/tasks_by_list_page.dart` 里的日历视图
   （`CalendarView(tasks:…, now:…, onTaskDateChanged:…)`）已经把"怎么接"写好了，
   本轮照它的形状接线，不另造 use-case。

## 二、最小实现（三处，均为接线）

| 落点 | 改动 |
| ---- | ---- |
| `lib/features/home/home_shell.dart` | `_CalendarHost` 补 `now: ref.watch(currentDateTimeProvider)()` 与 `onTaskDateChanged`（走 `taskViewActionRepositoryProvider.moveCalendarTask`） |
| `lib/features/task/tasks_by_list_page.dart` | 新增文件末尾的 `_CalendarDragSource`（`LongPressDraggable<TodoTask>`，`delay: 300ms`，载荷 `TodoTask` 与 `_DayCell` 的 drop 对齐），把两条列表分支的行各包一层 |
| `test/features/home/drag_list_task_into_calendar_test.dart` | 新增：按 `spec.md` §二 的口径写用例 |

不改 `calendar_view.dart`（接收端已具备能力）、不动 SQL、不动后端契约。

## 三、四件套怎么落

- **读屏语义**：包一层 `LongPressDraggable` 不引入 `Semantics(container:true)`/
  `ExcludeSemantics`，用一条用例钉住"标题仍在该行内且语义树里可被读屏点到"。
- **失败保留已加载数据**：复用 `_DayCell._moveTask` 的 try/catch ⇒ 写失败播
  `日历改期失败，请重试`，本地日期不动；用一条用例把这条反馈当**正向对照**跑起来
  （否则"没有失败文案"那句 `findsNothing` 是恒真的假判据）。
- **320px + 1.3 倍字号**：本轮不新增界面/不改布局常量，拖拽反馈用的就是行本身；
  反馈条宽度受 `SizedBox(width: 320)` 约束（与 320px 档同宽），不产生新的溢出面。
- **过期响应不覆盖新响应**：拖拽落点是本地事务（Drift `update` + outbox 入队），
  没有"后发先至"的异步回包可覆盖；`moveCalendarTask` 内部走同一 transaction。

## 四、探针设计（判覆盖面，不看绿光）

用 `/tmp/r136/probe397b.py` 逐处摘掉实现后跑本文件，每条打印 `+N -M` 摘要行，
摘完立刻还原并断言字节一致。四个探针分别对应：
桌面分支拖出源、普通 ListView 分支拖出源、接收端 `onTaskDateChanged`、`now:` 注入。
**B 项结果要如实登记**（它决定第二处包层是否有牙，见 `tasks.md` 的"覆盖面缺口"节）。
