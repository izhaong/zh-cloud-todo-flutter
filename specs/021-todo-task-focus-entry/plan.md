# Todo 从任务入口开始番茄专注 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让已同步的有效任务可以从滴答清单式任务列表和任务详情直接进入现有番茄专注页。

**Architecture:** 不改变专注领域 API。任务行和详情页仅在 `serverId != null && !completed && !cancelled` 时暴露入口，导航时传递整数 `serverId` 至 `PomodoroPage(taskId: ...)`；番茄页保留模式选择与开始会话职责。

**Tech Stack:** Flutter、Dart 3.11、Riverpod、Drift、Material 3、flutter_test。

## Global Constraints

- 只在 `codex/247-todo-task-focus-entry` 本地分支工作；不使用 worktree。
- 不新增或修改后端契约、Drift 表、outbox、同步实体与提醒派发动作。
- 不使用本地 UUID 作为 `PomodoroPage.taskId`，只可传已同步任务的整数 `serverId`。
- 移动端仍保留既有完成/更多手势；本切片在更多菜单中加入专注，而不偷换为未配置的固定滑动动作。

### Task 1: List entry contract

**Files:**
- Modify: `lib/features/task/widgets/task_row_host.dart`
- Create: `test/features/task/task_focus_entry_test.dart`

- [x] **Step 1: Write list-entry red tests**

构造已同步、未完成任务。断言桌面右键和移动端既有“更多”菜单均出现“开始专注”，选择后展示 `PomodoroPage` 且 `taskId` 等于整数 serverId。构造未同步、完成及放弃任务，断言菜单不显示入口。

- [x] **Step 2: Run the red test**

Run: `flutter test test/features/task/task_focus_entry_test.dart --plain-name 'task list menus open pomodoro only for synced active tasks'`

Expected: FAIL because task-row menus do not yet expose `开始专注` or a desktop secondary-click menu.

- [x] **Step 3: Implement minimal list navigation**

复用既有 `_showMoreMenu`，在关闭菜单后用当前 navigator push `PomodoroPage(taskId: serverId)`。桌面使用二级鼠标点击展示紧凑上下文菜单，行内“更多”继续作为无障碍替代入口。

- [x] **Step 4: Run the focused list tests**

Run: `flutter test test/features/task/task_focus_entry_test.dart --plain-name 'task list menus open pomodoro only for synced active tasks'`

Expected: PASS.

### Task 2: Detail entry contract

**Files:**
- Modify: `lib/features/task/task_detail_pane.dart`
- Modify: `test/features/task/task_focus_entry_test.dart`

- [x] **Step 1: Write detail-entry red tests**

在窄屏详情的“更多任务操作”和宽屏/嵌入详情的“更多任务操作”中断言有效任务有“开始专注”，触发后 `PomodoroPage.taskId` 正确。断言无 serverId 或已结束任务不会有该项。

- [x] **Step 2: Run the red test**

Run: `flutter test test/features/task/task_focus_entry_test.dart --plain-name 'task detail menu forwards synced active task to pomodoro'`

Expected: FAIL because详情菜单没有专注 action。

- [x] **Step 3: Implement minimal detail menu action**

扩展现有 `_TaskDetailAction`，复用单一 action handler；窄屏完整更多菜单及宽屏/嵌入详情的紧凑更多菜单都只在有效任务时显示该项。

- [x] **Step 4: Run focused detail tests**

Run: `flutter test test/features/task/task_focus_entry_test.dart --plain-name 'task detail menu forwards synced active task to pomodoro'`

Expected: PASS.

### Task 3: Verification and cross-review

**Files:**
- Modify: `spec.md`
- Modify: `specs/021-todo-task-focus-entry/tasks.md`

- [x] **Step 1: Format and analyze**

Run: `dart format --output=none --set-exit-if-changed lib/features/task/widgets/task_row_host.dart lib/features/task/task_detail_pane.dart test/features/task/task_focus_entry_test.dart`

Run: `flutter analyze`

- [x] **Step 2: Run local acceptance gates**

Run: `flutter test --concurrency=1`

Run: `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`

- [ ] **Step 3: Run Claude CLI read-only review**

Review this spec, `task_row_host.dart`, `task_detail_pane.dart`, `task_focus_entry_test.dart`, and `spec.md`. Record a literal pass verdict or the exact external blocker; do not treat a timeout as approval.
