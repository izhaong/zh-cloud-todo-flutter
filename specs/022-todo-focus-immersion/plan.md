# Todo 番茄沉浸模式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让已有番茄专注会话可以进入可访问、可恢复且不改变服务端会话事实的三样式沉浸展示。

**Architecture:** 新增一个只负责设备本地展示偏好的存储接口，`PomodoroPage` 在会话状态转换时决定是否进入沉浸，并把当前会话与现有动作回调传给独立的沉浸展示组件。沉浸组件不拥有计时器、不调用 API；它只渲染秒数和发出用户动作，因此 15 秒服务端会话收敛仍由现有页面状态机单一负责。

**Tech Stack:** Flutter、Dart 3.11、Riverpod、`shared_preferences`、Material 3、flutter_test。

## Global Constraints

- 只在本地分支 `codex/253-todo-focus-immersion` 工作；不使用 worktree。
- 仅存储设备本地展示偏好；不得新增 Pomodoro REST、Drift、outbox、同步实体或请求。
- 只在有效 RUNNING/PAUSED 会话中进入；远端清除会话时同步退出沉浸。
- “退出沉浸”绝不等价于暂停、完成或取消；动作必须继续走现有 `PomodoroApi` 成功确认后的状态机。
- 不在此切片加入音频资产、播放器、原生权限、浏览器全屏、悬浮窗、传感器、严格模式或 Live Activity。

### Task 1: Local immersion preference contract

**Files:**
- Create: `lib/features/pomodoro/focus_immersion_settings.dart`
- Modify: `lib/state/efficiency_providers.dart`
- Test: `test/features/pomodoro/focus_immersion_settings_test.dart`

**Interfaces:**
- Produces `enum FocusTimerStyle { digital, flip, pixel }`.
- Produces immutable `FocusImmersionSettings({required bool autoEnter, required FocusTimerStyle style})`.
- Produces `abstract interface class FocusImmersionSettingsStore` with `Future<FocusImmersionSettings> read()` and `Future<bool> write(FocusImmersionSettings value)`.
- Produces `focusImmersionSettingsStoreProvider`, whose production value uses the scoped key `todo_focus_immersion_settings_v1`.

- [x] **Step 1: Write the failing storage tests**

```dart
expect(await store.read(), const FocusImmersionSettings());
await store.write(const FocusImmersionSettings(autoEnter: true, style: FocusTimerStyle.pixel));
expect(await store.read(), const FocusImmersionSettings(autoEnter: true, style: FocusTimerStyle.pixel));
```

Add malformed JSON and unknown style cases; both must return the default instead of throwing. Add a failing write fake and assert it returns `false` without changing the caller's in-memory settings.

- [x] **Step 2: Run the red storage test**

Run: `flutter test test/features/pomodoro/focus_immersion_settings_test.dart`

Expected: FAIL because the settings types, store and provider do not exist.

- [x] **Step 3: Implement the minimal storage contract**

Use a private JSON codec with exactly `{ "autoEnter": bool, "style": "digital|flip|pixel" }`. The `SharedPreferences` implementation catches read/write/parse failures and returns defaults or `false`; it must never use member credentials or server IDs in the key/value.

- [x] **Step 4: Run the storage test**

Run: `flutter test test/features/pomodoro/focus_immersion_settings_test.dart`

Expected: PASS.

### Task 2: Isolated immersive presentation

**Files:**
- Create: `lib/features/pomodoro/focus_immersive_pane.dart`
- Test: `test/features/pomodoro/focus_immersive_pane_test.dart`

**Interfaces:**
- Consumes `FocusTimerStyle`, `seconds`, `paused`, `onToggleControls`, `onPauseOrResume`, `onComplete`, `onCancel`, `onExit`, and `controlsVisible`.
- Produces `FocusImmersivePane`, which contains no `Timer`, `Ref`, REST client or storage access.

- [x] **Step 1: Write failing visual and semantic tests**

```dart
expect(find.byKey(const Key('focus-immersive-pane')), findsOneWidget);
expect(find.bySemanticsLabel('沉浸计时：12 分 34 秒，翻页钟样式'), findsOneWidget);
await tester.tap(find.byKey(const Key('focus-immersive-timer')));
expect(find.text('退出沉浸'), findsOneWidget);
```

Cover all three styles, hidden/revealed controls, PAUSED wording, every action callback, 320px and 1.3 text scale with no `RenderFlex overflowed` exception.

- [x] **Step 2: Run the red pane test**

Run: `flutter test test/features/pomodoro/focus_immersive_pane_test.dart`

Expected: FAIL because `FocusImmersivePane` does not exist.

- [x] **Step 3: Implement the pure presentation component**

Render `digital` with the normal display typography, `flip` as grouped digit cards and `pixel` with a fixed-width visual treatment. Keep the same `mm:ss` data in every style. Wrap the timer in a labelled button that toggles the control layer; controls use text-plus-icon buttons and stay inside a scrolling/`Wrap` action region at narrow widths.

- [x] **Step 4: Run the pane test**

Run: `flutter test test/features/pomodoro/focus_immersive_pane_test.dart`

Expected: PASS.

### Task 3: Connect page state without changing session truth

**Files:**
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Consumes `FocusImmersionSettingsStore` and `FocusImmersivePane`.
- Adds page-local `_immersive`, `_immersiveControlsVisible`, `_autoEnteredSessionId`, and loaded `FocusImmersionSettings` state.
- Reuses existing `_pause`, `_resume`, `_finish`, `_clearSession`, `_activateSession`, `_secondsLeft` and `_session`; no new API method is introduced.

- [x] **Step 1: Write failing integration tests**

```dart
await tester.tap(find.byTooltip('更多专注操作'));
await tester.tap(find.text('进入沉浸模式'));
expect(find.byKey(const Key('focus-immersive-pane')), findsOneWidget);
await tester.tap(find.text('退出沉浸'));
expect(api.pauseCalls, isEmpty);
expect(api.completeCalls, isEmpty);
```

Add cases for auto-enter after local start and remote active-session restore, manual exit followed by a 15-second sync does not re-enter, remote session disappearance exits immersion, style selection persists, and pause/finish actions call the existing fake API exactly once.

- [x] **Step 2: Run the red page tests**

Run: `flutter test test/pomodoro_page_contract_test.dart --plain-name 'immersive'`

Expected: FAIL because there is no page menu, preference load, immersive state or pane.

- [x] **Step 3: Implement minimal integration**

Load settings in `initState` without blocking presets/session sync. Show a `PopupMenuButton` with stable tooltip `更多专注操作`; expose manual entry only while `_session != null`, and expose a checkable auto-enter setting plus a style picker. In `_activateSession`, after updating existing state, call a guarded helper that enters once only when the loaded preference is enabled, the session has not been manually dismissed and its id differs from `_autoEnteredSessionId`. In `_clearSession`, reset immersive local state before returning to normal page.

- [x] **Step 4: Run focused page tests**

Run: `flutter test test/pomodoro_page_contract_test.dart --plain-name 'immersive'`

Expected: PASS.

### Task 4: Verification and independent review

**Files:**
- Modify: `spec.md`
- Modify: `specs/022-todo-focus-immersion/tasks.md`

- [ ] **Step 1: Run local quality gates**

Run:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/pomodoro/focus_immersion_settings.dart \
  lib/features/pomodoro/focus_immersive_pane.dart \
  lib/features/pomodoro/pomodoro_page.dart \
  test/features/pomodoro/focus_immersion_settings_test.dart \
  test/features/pomodoro/focus_immersive_pane_test.dart \
  test/pomodoro_page_contract_test.dart
flutter analyze
flutter test test/features/pomodoro/focus_immersion_settings_test.dart test/features/pomodoro/focus_immersive_pane_test.dart test/pomodoro_page_contract_test.dart
flutter test --concurrency=1
flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1
```

Expected: every command exits 0; any Web Wasm dry-run warning from existing `flutter_secure_storage_web` is recorded separately from the JavaScript Web build result.

- [ ] **Step 2: Run Claude CLI in verified mode**

Pass the storage/state excerpt, the immersive pane excerpt and the relevant tests separately through stdin to `claude -p --model sonnet --no-session-persistence`. Require each response to begin with literal `VERDICT: PASS` or `VERDICT: FAIL`; a nonresponding request is recorded as an execution constraint, never approval.

- [ ] **Step 3: Create and merge the Gitea PR**

Create one conventional commit `feat(todo): 增加番茄沉浸模式` linked to `Fixes #253`; preserve actual Actions/Jenkins evidence and merge only through the repository PR flow.
