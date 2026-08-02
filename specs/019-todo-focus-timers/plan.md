# Todo 常用专注计时器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在专注页提供跨设备常用 Timer 的完整管理、一键开始以及真正的 Stopwatch 体验。

**Architecture:** `PomodoroApi` 负责强类型 Timer HTTP 合同；`PomodoroPage` 维护请求序号、上次成功列表和当前会话。Timer 列表/编辑 UI 拆到独立文件，任务来自 Drift，习惯来自现有 `myHabitsProvider`；普通会话动作仍复用当前状态机。

**Tech Stack:** Flutter、Dart 3.11、Riverpod、Dio、Material 3、flutter_test。

## Global Constraints

- 不使用 worktree；只在 `codex/todo-focus-timers` 本地分支工作。
- 不新增状态管理或网络依赖。
- 320px 无横向溢出；键盘和读屏可完成新增、编辑、启动、归档、恢复、删除。
- `FREE` 正计时不得伪造目标分钟；Timer 服务端失败不得清空旧列表或当前会话。

---

### Task 1: Timer API contracts

**Files:**
- Modify: `lib/core/api/efficiency_api.dart`
- Modify: `test/efficiency_api_contract_test.dart`

**Interfaces:**
- Produces: `PomodoroTimerDto` with `id,name,mode,focusMinutes,taskId,habitId,sortOrder,archived`.
- Produces: `PomodoroApi.timers`, `createTimer`, `updateTimer`, `setTimerArchived`, `deleteTimer`, `startTimer`.

- [ ] **Step 1: Write the failing API test**

```dart
final timers = await api.timers(archived: false);
final session = await api.startTimer(10);
expect(timers.single.focusMinutes, isNull);
expect(requests, contains(predicate<RequestOptions>((r) =>
  r.path.endsWith('/pomodoro/timers/10/start'))));
expect(session.timerId, 10);
```

Assert create/update bodies omit FREE `focusMinutes`, archive uses `value`, list sends `archived`, and delete uses the id route.

- [ ] **Step 2: Run the red test**

Run: `flutter test test/efficiency_api_contract_test.dart --plain-name 'pomodoro timer CRUD and start follow service contracts'`

Expected: compilation FAIL on missing Timer symbols.

- [ ] **Step 3: Implement DTO and API methods**

`PomodoroSessionDto` also parses nullable `timerId/habitId`; `startTimer` requires and parses the complete session map returned by Service. A scalar id or malformed body is a contract error and must not be converted into a fabricated RUNNING session.

- [ ] **Step 4: Run the API tests**

Run: `flutter test test/efficiency_api_contract_test.dart`

Expected: PASS.

### Task 2: Timer list and one-click start

**Files:**
- Create: `lib/features/pomodoro/pomodoro_timer_section.dart`
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Consumes: Task 1 Timer DTO/API methods and existing tasks/habits providers.
- Produces: `PomodoroTimerSection` callbacks `onStart/onCreate/onEdit/onArchive/onDelete/onShowArchived`.

- [ ] **Step 1: Write list/start/failure red tests**

```dart
expect(find.text('常用专注'), findsOneWidget);
expect(find.text('晨间阅读'), findsOneWidget);
await tester.tap(find.bySemanticsLabel('开始晨间阅读，正计时'));
expect(api.startedTimerIds, [10]);
expect(find.text('暂停'), findsOneWidget);
```

Also hold the initial Timer response pending and advance 15 seconds to prove active-session polling continues; make start fail and assert the card and current session remain.

- [ ] **Step 2: Run the red widget tests**

Run: `flutter test test/pomodoro_page_contract_test.dart --plain-name 'timer cards start a server timer without blocking session sync'`

Expected: FAIL because Timer UI/state does not exist.

- [ ] **Step 3: Implement request-isolated list and start**

Keep `_timers`, `_timersDataArchived`, `_timersRequest`, loading/error state. Initial loads are unawaited and independent. Only a current response replaces content; start calls the id-only endpoint and activates the returned session after success.

- [ ] **Step 4: Run the widget tests**

Run: `flutter test test/pomodoro_page_contract_test.dart`

Expected: PASS.

### Task 3: Editor, association and lifecycle actions

**Files:**
- Create: `lib/features/pomodoro/pomodoro_timer_editor.dart`
- Modify: `lib/features/pomodoro/pomodoro_timer_section.dart`
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Produces: `PomodoroTimerDraft(name,mode,focusMinutes,taskId,habitId,sortOrder)`.
- Consumes: current synced incomplete tasks and current unarchived `HabitDto` values.

- [ ] **Step 1: Write editor and lifecycle red tests**

Cover trimmed name, 64-char edge, blank/65-char rejection, Pomo 1/1440 accepted and 0/1441 rejected, FREE minutes hidden/null, task/habit exclusivity, edit refresh, archive/delete confirmation, archived restore, and failure preserving the original card.

- [ ] **Step 2: Run the red tests**

Run: `flutter test test/pomodoro_page_contract_test.dart --plain-name 'timer editor validates modes associations and lifecycle actions'`

Expected: FAIL because the editor and callbacks are missing.

- [ ] **Step 3: Implement editor and actions**

Use a keyboard-reachable dialog with explicit radio/segmented mode, one association selector whose values encode `task:<id>` or `habit:<id>`, and confirmation text “历史专注记录会保留”. Keep the card when the server action fails; after server confirmation, update the current list from the confirmed result and refresh in the background without turning a refresh failure into a false action failure.

- [ ] **Step 4: Run the widget suite**

Run: `flutter test test/pomodoro_page_contract_test.dart`

Expected: PASS.

### Task 4: True Stopwatch session rendering

**Files:**
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Consumes: nullable FREE `plannedMinutes`, `startedAt`, `pausedAt`, `pausedSeconds`.
- Produces: elapsed-seconds display for FREE and remaining-seconds display for Pomo.

- [ ] **Step 1: Write count-up red tests**

```dart
api.activeResponses.add(PomodoroSessionDto(
  id: 41, mode: 'FREE', status: 'RUNNING', plannedMinutes: null,
  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
));
expect(find.text('03:00'), findsOneWidget);
await tester.pump(const Duration(seconds: 1));
expect(find.text('03:01'), findsOneWidget);
```

Add PAUSED restoration and verify elapsed time freezes; Pomo countdown regression must remain green.

- [ ] **Step 2: Run the red test**

Run: `flutter test test/pomodoro_page_contract_test.dart --plain-name 'stopwatch restores and counts elapsed focus time'`

Expected: FAIL because FREE still uses remaining countdown.

- [ ] **Step 3: Implement dual timer semantics**

Track elapsed seconds separately or derive a mode-aware display value. On each tick increment FREE when running and decrement Pomo when running; pause freezes both. `_canStart` permits FREE with null minutes and the API omits that field.

- [ ] **Step 4: Run focused regression tests**

Run: `flutter test test/pomodoro_page_contract_test.dart test/efficiency_api_contract_test.dart`

Expected: PASS.

### Task 5: Accessibility, docs and Flutter gates

**Files:**
- Modify: `spec.md`
- Modify: `specs/019-todo-focus-timers/tasks.md`
- Modify: `test/pomodoro_page_contract_test.dart`

- [ ] **Step 1: Add 320px and semantics assertions**

Exercise active and archived Timer sections at 320x640; assert no exception and exact labels for name/mode/minutes/association/start/menu. Confirm stale list responses cannot replace the selected archive state.

- [ ] **Step 2: Update repository contract and evidence**

Record the Service dependency commit, red failures, focused counts, full suite, Web build, Claude verdict or raw blocker, and Gitea/Jenkins external state.

- [ ] **Step 3: Run fresh local gates**

Run: `dart format --output=none --set-exit-if-changed lib/core/api/efficiency_api.dart lib/features/pomodoro/pomodoro_page.dart lib/features/pomodoro/pomodoro_timer_section.dart lib/features/pomodoro/pomodoro_timer_editor.dart test/efficiency_api_contract_test.dart test/pomodoro_page_contract_test.dart`

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`

Expected: format/analyze/test/build all exit 0; protected live tests may only skip under their existing explicit flags.

- [ ] **Step 4: Run Claude CLI read-only review**

Review spec, API, Timer widgets, page state and tests. Accept only an explicit `VERDICT: PASS`; otherwise record exact output/duration and continue to the next official missing capability.
