# 实现计划：时间线视图的 Ctrl/⌘ + 滚轮缩放

对应规格：[spec.md](./spec.md) Issue：[#298](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/298)

## 改动面

只碰一个生产文件 + 一个新测试文件：

| 文件 | 改动 |
| ---- | ---- |
| `lib/features/task/views/timeline_view.dart` | 新增纯函数 `timelineWheelZoomTarget`；`_TimelineWindowState.build` 把 `_TimelineContinuousCanvas` 包进一层 `Listener(onPointerSignal:)`；补 `import 'package:flutter/services.dart';` |
| `test/features/task/timeline_wheel_zoom_test.dart` | 新增 7 条用例 |

## 缩放计算：纯函数，不复制常量

```dart
double? timelineWheelZoomTarget(PointerSignalEvent event, {required double zoom})
```

返回 `null` 表示这次滚轮不该被接管（非 `PointerScrollEvent`、`scrollDelta.dy == 0`、没有 Ctrl/⌘、或已在边界算出同一个值）。步长取 `_TimelineZoomToolbar._step`（`timeline_view.dart:502`）、上下限 `0.75 ~ 1.5` 与 `:614`/`:632` 两颗按钮的禁用条件一致——**不新写一套常量**，否则按钮和滚轮会各自漂移。

方向：**向上放大、向下缩小**。嘀嗒 `:107` 那句没写方向；取这个方向的理由是它同时满足两处既有语义——同页相邻的《调整界面字号》（`:109` 小节、`:111` 正文）用 `Ctrl` + `+` / `-` 放大/缩小，`+` 在上；浏览器与日历里 `Ctrl` + 滚轮向上也是放大。第一版实现把方向写反过（`zoom + dy.sign * step`），是补测例时按 `:614`/`:632` 按钮的 +/- 语义对照才发现的，现已改为 `zoom - dy.sign * step` 并在代码里注明依据。

## 事件入口：为什么是 `Listener`

`Scrollable` 消费滚轮走的是 `Listener(onPointerSignal: _receivedPointerSignal)`（Flutter `scrollable.dart:1027`，handler `:953`），不是手势竞技场；`PointerSignalResolver.register` 是**先注册者赢**。所以在画布外层再挂一个 `Listener` 就能在同一个事件上拿到滚轮，不必替换 `Scrollable`、也不必接管 `_TimelineContinuousCanvas` 的内部结构。

**这条实现的边界要说清**：`Listener.onPointerSignal` 只观察、不 resolve，因此我们**没有**吞掉这次信号。当前用例里 Ctrl+滚轮不会推动画布，是因为该画布只有一个**横向** `Scrollable`，而 `_pointerSignalEventDelta`（`scrollable.dart:933-950`）对鼠标取的是 `scrollDelta.dx`，只有 `pointerAxisModifiers`（默认 Shift）才翻转轴。⇒ 若将来在时间线里嵌纵向可滚动区，Ctrl+滚轮会同时缩放与滚动，那时要改成 `PointerSignalResolver` 显式 resolve。此点写进测试注释，不留「已互斥」的假结论。

## 测试设计（`test/features/task/timeline_wheel_zoom_test.dart`）

harness 形状抄 `test/m11_b3_eisenhower_test.dart:91-93`：`ProviderScope(child: MaterialApp(home: Scaffold(body: TimelineView(...))))`。裸 `Directionality` 不够——画布上的 `IconButton(tooltip:)` 需要 `Overlay`，否则抛 `No Overlay widget found`（第一版就踩了这个）。

滚轮注入：`tester.sendEventToBinding(PointerScrollEvent(position:, kind: PointerDeviceKind.mouse, scrollDelta: Offset(0, y)))`，前置一个 `PointerHoverEvent` 定住落指位；修饰键用 `sendKeyDownEvent` / `sendKeyUpEvent` 包夹。`WidgetTester` 没有 `sendEvent`，`PointerScrollEvent` 的滚动量参数是 `Offset scrollDelta`（不是标量）。

| # | 用例 | 钉住什么 |
| - | ---- | -------- |
| 1 | Ctrl + 向上放大 | `calls == [1.25]`，步长与按钮同源 |
| 2 | ⌘ + 向下缩小 | `calls == [0.75]`，macOS 侧同一个入口 |
| 3 | 裸滚轮不缩放 | `calls.isEmpty`（FR-003） |
| 4 | Shift 只滚、Ctrl 只缩放 | 先断言 `maxScrollExtent > 0`（前提没牙齿则整条对照作废），Shift 后 `pixels` 必须动，Ctrl 后 `pixels` 必须不动且 `calls == [1.25]` |
| 5 | `zoom = 1.5` + ⌘ 向上不回调 | 边界与按钮禁用态一致（FR-002） |
| 6 | `zoom = 0.75` + Ctrl 向下不回调 | 另一侧边界（第 5 条只证了一半） |
| 7 | `onZoomChanged == null` | `takeException() isNull`（FR-004） |

第 4 条是本轮的**正向对照**：本仓此前没有任何滚轮用例（动手前 `git grep PointerScrollEvent origin/develop -- test` 0 命中），只写「缩放时滚动位置不动」会是恒真断言，必须先证明这个面真的会被滚轮推动。

反向探针（判据）：摘掉 `Listener` 包装（保留纯函数以便编译）后跑该文件，应为 `+3 -3`——三条修饰键用例红、报错形如 `Expected: [1.25] / Actual: []`，三条负向用例仍绿；恢复后 `cmp -s` 与备份逐字节一致。这证明用例咬的是**接线**，不是纯函数自身。

## 不做

不改布局、不加控件、不动 Service、不加持久化；`TimelineView` 的对外签名不变（`zoom` / `onZoomChanged` 已存在），因此宿主页面零改动。
