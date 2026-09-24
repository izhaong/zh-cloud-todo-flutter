# 实现计划：时间线视图的 Ctrl/⌘ + 滚轮缩放

对应规格：[spec.md](./spec.md) Issue：[#298](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/298) PR：[!299](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/299)

## 改动面

| 文件 | 改动 |
| ---- | ---- |
| `lib/features/task/views/timeline_view.dart` | 新增纯函数 `timelineWheelZoomTarget`（`:741`）；`_TimelineWindowState.build` 把 `_TimelineContinuousCanvas` 包进一层 `Listener(onPointerSignal:)`（`:468-476`）；补 `import 'package:flutter/services.dart';` |
| `test/features/task/timeline_wheel_zoom_test.dart` | 新增 7 条用例 + 受控宿主 `_WheelZoomHost` |
| `specs/040-todo-timeline-wheel-zoom/*` | 本规格三件套 |

## 缩放计算：纯函数，步长引用同一常量

```dart
double? timelineWheelZoomTarget(PointerSignalEvent event, {required double zoom})
```

返回 `null` 表示这次滚轮不该被接管（非 `PointerScrollEvent`、`scrollDelta.dy == 0`、没有 Ctrl/⌘、或已在边界算出同一个值）。步长取 `_TimelineZoomToolbar._step`（`timeline_view.dart:502`）；上下限 `0.75 ~ 1.5` 与 `:614`/`:632` 两颗按钮的禁用条件同值——**该 widget 里没有 min/max 常量**，所以 `:753` 只是又添一处 —— 连同 `:616`/`:634` 的 clamp，文件里共五处，本轮按「不顺手重构」不收拢（已记在 tasks.md 的「仍缺」）。

方向：**向上放大、向下缩小**。嘀嗒 `:107` 那句确实没写方向；取这个方向的理由是它同时满足两处既有语义——同页相邻的《调整界面字号》（`:109` 小节、`:111` 正文）用 `Ctrl` + `+` / `-` 放大/缩小，`+` 在上；浏览器与日历里 `Ctrl` + 滚轮向上也是放大。第一版实现把方向写反过（`zoom + dy.sign * step`），补边界用例时对照 `:614`/`:632` 按钮语义才发现，现改为 `zoom - dy.sign * step`，依据写在代码注释里。

## 事件入口：为什么是 `Listener`

`Scrollable` 消费滚轮走的是 `Listener(onPointerSignal: _receivedPointerSignal)`（Flutter `scrollable.dart:1027`，handler `:953`），不是手势竞技场，所以在画布外层再挂一个 `Listener` 就能在同一条滚轮事件上收到它，不必替换 `Scrollable`、也不动 `_TimelineContinuousCanvas` 的内部结构。（`PointerSignalResolver.register` 是先注册者赢，但**本例没有任何注册者**——外层 `Listener` 只是观察，不参与仲裁。）

**边界要说清**：`Listener.onPointerSignal` 只观察、不 resolve，因此我们**没有**吞掉这次信号。当前 Ctrl+滚轮不推动画布，是因为该画布只有一个**横向** `SingleChildScrollView`（`timeline_view.dart:816`），而 `_pointerSignalEventDelta`（`scrollable.dart:932-951`）对鼠标取 `scrollDelta.dx`，只有 `pointerAxisModifiers`（默认 Shift，见 `scroll_configuration.dart:154`）才翻转轴 ⇒ 若将来在时间线里嵌纵向可滚动区，Ctrl+滚轮会同时缩放与滚动，那时要改用 `PointerSignalResolver` 显式 resolve。不留「两者已互斥」的假结论。

## 测试设计（`test/features/task/timeline_wheel_zoom_test.dart`）

harness 形状抄 `test/m11_b3_eisenhower_test.dart:91-93`：`ProviderScope(child: MaterialApp(home: Scaffold(body: ...)))`。裸 `Directionality` 不够——画布上的 `IconButton(tooltip:)` 需要 `Overlay`，否则抛 `No Overlay widget found`（第一版就踩了）。

**宿主必须受控**：`TimelineView.zoom` 是外部受控属性，若测试把 zoom 写成常量，缩放回调虽然触发但画布宽度永远不变 ⇒ 「Ctrl+滚轮只缩放、不推动画布」那句 `pixels` 断言结构性无法失败。第一轮复核指出这点，现由 `_WheelZoomHost` 把 `onZoomChanged` 的新值 `setState` 回 `zoom`。

滚轮注入：`tester.sendEventToBinding(PointerScrollEvent(position:, kind: PointerDeviceKind.mouse, scrollDelta: Offset(0, y)))`，前置一个 `PointerHoverEvent` 定住落指位；修饰键用 `sendKeyDownEvent` / `sendKeyUpEvent` 包夹。`WidgetTester` 没有 `sendEvent`，`PointerScrollEvent` 的滚动量参数是 `Offset scrollDelta`（不是标量）。

| # | 用例 | 钉住什么 |
| - | ---- | -------- |
| 1 | Ctrl + 向上放大 | `calls == [1.25]` |
| 2 | ⌘ + 向下缩小 | `calls == [0.75]` |
| 3 | 裸滚轮不缩放 | `calls.isEmpty`（FR-003） |
| 4 | Shift 只滚、Ctrl 只缩放 | 先断言 `maxScrollExtent > 0`，用 Shift 证明画布真被推动，再要求 Ctrl 缩放发生时 `pixels` 不变 |
| 5 | `zoom = 1.5` + ⌘ 向上不回调 | 上限与按钮禁用态一致（FR-002） |
| 6 | `zoom = 0.75` + Ctrl 向下不回调 | 下限同一件事 |
| 7 | `onZoomChanged == null` | `takeException()` 为 null（FR-004） |

第 4 条是本仓**第一条**滚轮用例（动手前 `git grep PointerScrollEvent origin/develop -- test` 0 命中），所以自带正向对照，否则「缩放时位置不动」是恒真断言。

## 判据：反向探针（最终状态，输出已入 `/tmp/r35_gates.log`）

摘掉 `Listener` 包装（保留纯函数以便编译）后：`00:01 +4 -3: Some tests failed.` —— 红的正是 1、2、4 三条修饰键用例（`Expected: [1.25] / Actual: []`），4 条负向（3、5、6、7）仍绿。恢复后 `cmp -s` 打印 `RESTORE: byte-identical`。⇒ 用例咬的是**接线**，不是纯函数自己。

（更正记录：这一条先前写的是 `+3 -3`，那是补第 7 条用例**之前**的探针结果；把旧数字当新证据是本仓反复踩过的坑，已按最终状态重测。）

## 不做

不改布局、不加控件、不动 Service、不加持久化；`TimelineView` 对外签名不变（`zoom` / `onZoomChanged` 已存在），宿主页面零改动。
