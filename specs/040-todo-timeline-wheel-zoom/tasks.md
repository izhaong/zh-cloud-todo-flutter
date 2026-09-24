# 任务清单：时间线视图的 Ctrl/⌘ + 滚轮缩放

规格：[spec.md](./spec.md) · 计划：[plan.md](./plan.md) · Issue：[#298](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/298)
分支：`feat/todo-timeline-wheel-zoom`（base `origin/develop@a1d7733`）

## 已证实

- [x] **T1 红测先行**：新建 `test/features/task/timeline_wheel_zoom_test.dart` 时生产代码不含任何滚轮入口，首轮即红（`Expected: [1.25] / Actual: []`）。动手前的缺口判据：`git grep -nE 'PointerSignal|MouseScrollEvent|PointerScrollEvent' origin/develop -- lib` 0 命中。
- [x] **T2 最小实现**（FR-001、FR-002）：纯函数 `timelineWheelZoomTarget`（`lib/features/task/views/timeline_view.dart:741`）+ `_TimelineWindowState.build` 外层 `Listener(onPointerSignal:)`（`:468-476`）。步长取 `_TimelineZoomToolbar._step`、上下限 `0.75 ~ 1.5`，与 `:614`/`:632` 两颗按钮同源，未新写常量。
- [x] **T3 方向纠正**：第一版 `zoom + dy.sign * step`（向下放大）与 `:614`/`:632` 按钮的 +/- 语义和同页《调整界面字号》（`:109` 小节）相反，已改为 `zoom - dy.sign * step`（向上放大）。依据写进代码注释与 plan.md。
- [x] **T4 负向不回归**（FR-003）：裸滚轮、Shift + 滚轮仍只滚动画布；`calls.isEmpty` 由用例 3、4 钉住。
- [x] **T5 只读宿主不抛异常**（FR-004）：`onZoomChanged == null` 时 `takeException()` 为 null（用例 7）。
- [x] **T6 正向对照有牙齿**：用例 4 先断言 `maxScrollExtent > 0`，再用 Shift（`pointerAxisModifiers` 会翻转轴）证明画布真被滚轮推动，才允许「Ctrl + 滚轮后 `pixels` 不动」这句断言存在。
- [x] **T7 反向探针**：摘掉 `Listener` 包装（保留纯函数以维持编译）后该文件 `+3 -3`——三条修饰键用例红、三条负向用例仍绿；`cp` 还原后 `cmp -s` 证明与备份逐字节一致。⇒ 用例咬的是接线，不是纯函数自己。
- [x] **T8 六项门禁**（最终状态一次跑完，日志 `/tmp/r35_gates.log`）：
  | 门禁 | 原文结果 |
  | ---- | -------- |
  | `git diff --check`（`a1d7733`..工作树） | `exit=0` |
  | `dart format --output=none --set-exit-if-changed` 本轮两文件 | `Formatted 2 files (0 changed)`，`exit=0` |
  | `flutter analyze` | `No issues found! (ran in 2.1s)` |
  | `flutter test --tags golden` | `00:04 +9: All tests passed!`（基线 9 张未变，无需重录） |
  | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:14 +716 ~26: All tests passed!`（本分支 base 709 + 本轮 7 = 716） |
  | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` |
- [x] **T9 不随 PR 提交 `pubspec.lock`**：本机新 SDK 把它整树重解析改脏，本轮只提交 `timeline_view.dart`、新测试文件与 `specs/040-*`。

## 复核记录

`claude` CLI 本机不可用（`unrecognized_model`），按既定口径改用**本会话只读子代理**审本轮 FR（逐条 `git show <ref>:<path> | sed -n '<N>p'` 复验，必须回 `VERDICT`）。复核结论与不采纳项的理由在本节下方回填。

- [ ] **R1** 复核 VERDICT 回填。

## 仍缺 / 边界（不得当已完成）

- **矩阵 #87 不因本 PR 进「已证」**：嘀嗒《:107》那一面是**日历日/周视图的小时轴**，本端 `calendar_view.dart:168` 的 `CalendarMode` 无 day 档、全文件无小时刻度 ⇒ 那是独立缺口。本 PR 只结掉「缩放能力已有、滚轮快捷入口未做」这半条。合并前矩阵行不动（诚实规则：状态翻转只引已合并 SHA）。
- **滚轮事件未被 resolve**：`Listener.onPointerSignal` 只观察不消费。当前 Ctrl+滚轮不滚动，是因为画布只有横向 `Scrollable` 且 `_pointerSignalEventDelta` 对鼠标取 `scrollDelta.dx`；若将来嵌入纵向滚动区，需改用 `PointerSignalResolver` 显式 resolve，否则缩放与滚动会叠加。
- 未验证真机/桌面原生编译：门禁只有 Web release 与 Dart 侧测试，本机无 Android SDK、iOS 卡 SPM（`flutter build ios` 不可用），滚轮行为在桌面原生端的实测仍待人工。

## 下一轮入口

- 嘀嗒《:101》「快速切换日/周视图中的日期」（Shift + 滚轮）——但它同样依赖「日/周视图有可切换的时间区块」，与 #87 的日历小时轴缺口同源；开工前先确认那个前置面是否值得单独一轮（会改可见布局 ⇒ 需先申请重录黄金图基线）。
