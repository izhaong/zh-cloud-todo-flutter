# Tasks: Todo 多端视觉高保真垂直切片

**Input**: Design documents from `/specs/002-todo-visual-fidelity/`

**Prerequisites**: [plan.md](./plan.md)、[spec.md](./spec.md)、[research.md](./research.md)、[data-model.md](./data-model.md)、[workspace-ui-contract.md](./contracts/workspace-ui-contract.md)、[quickstart.md](./quickstart.md)

**Tests**: 本功能强制测试先行。每个用户故事先提交会失败的 widget/interaction/golden 测试，再实现最小代码使其通过；视觉基线只有经人工批准后才可更新。

**Approval delegation**: 用户已于 2026-07-11 明确批准 T012，并授权后续 T019/T025 由 Agent 在逐图检查、自动化回归通过并记录证据后代为批准，无需等待用户在线回复。

**Organization**: 任务按用户故事分组。US1 是可独立验收的桌面 MVP；US2 增加真实选择与详情闭环；US3 完成同一任务流的多端映射。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可与同阶段其它 `[P]` 任务并行，前提是文件不冲突。
- **[Story]**: 对应 `spec.md` 的用户故事。
- 所有路径均相对 `zh-cloud-todo-flutter` 仓库根目录。
- 除非用户明确要求，不执行 commit、push 或 PR。

## Phase 1: Setup — Deterministic Visual Harness

**Purpose**: 建立无网络、固定时间、可重复的数据与渲染入口，供所有用户故事共享。

- [x] T001 Create deterministic in-memory Drift seed data, fixed IDs, fixed `DateTime(2026, 7, 11, 9)` clock, Provider overrides, and teardown helpers in `test/support/todo_visual_fixture.dart`
- [x] T002 Create shared viewport/theme pump helpers and golden filename helpers for 1440×900, 1280×800, 1024×768, 390×844, and 360×800 in `test/support/todo_visual_test_harness.dart`

**Checkpoint**: Fixture tests can render existing widgets without a real session, real network, real token, or persistent database.

---

## Phase 2: Foundational — Visual Contract Test Skeleton

**Purpose**: 在改生产代码前，把 contract 中的结构、密度和场景变成失败测试。

- [x] T003 Create `test/visual/todo_workspace_golden_test.dart` with a typed registry for all nine scenario names from `contracts/workspace-ui-contract.md`, activate the three US1 wide scenarios, pump the current `HomeShell` through the visual fixture, and assert the new semantic keys/layout so the active tests compile but fail against the current UI

**Checkpoint**: The visual test file compiles against fixture helpers and fails only because the contracted workspace implementation/baselines are not present.

---

## Phase 3: User Story 1 — 桌面用户获得清晰紧凑的任务工作区 (Priority: P1) 🎯 MVP

**Goal**: 在 `1440×900` 交付自有品牌四区工作台、紧凑 Sidebar、单一 QuickAdd、分组扁平任务行和稳定无选择详情区。

**Independent Test**: 用 `wide-populated`、`wide-empty`、`wide-long-content` fixture 运行布局、任务行和 golden 测试；一屏至少 10 条任务，无重复控件、卡片阴影或第三方品牌文案。

### Tests for User Story 1 — write first and verify failure

- [x] T004 [P] [US1] Replace `test/features/home/home_shell_layout_test.dart` with failing `test/features/home/todo_workspace_layout_test.dart` assertions for the product-owned `todo-rail`, `todo-sidebar`, `todo-content`, and `todo-detail` regions, exact wide widths, and stable no-selection detail
- [x] T005 [P] [US1] Move `test/task_row_test.dart` to `test/features/task/task_row_test.dart` and `test/task_row_hover_test.dart` to `test/features/task/task_row_hover_test.dart`, then extend both with failing assertions for 44/58px density, no `AppCard`, 18px checkbox visual, selected/hovered backgrounds, fixed-clock date text, and contextual pin/drag/more actions
- [x] T006 [P] [US1] Rewrite `test/features/shell/sidebar_test.dart` and extend `test/features/shell/quick_add_bar_test.dart` with failing assertions for compact 40px rows, a neutral Todo product header, one desktop QuickAdd, and no duplicate FAB/ListPicker/smart chips

### Implementation for User Story 1

- [x] T007 [US1] Add all geometry, density, semantic surface colors, and motion constants from the UI contract to `lib/core/theme/todo_layout_tokens.dart`; update light semantic colors in `lib/core/theme/app_theme.dart`; add optional size/stroke parameters with backward-compatible defaults to `AppCheckbox` in `lib/core/widgets/app_widgets.dart`
- [x] T008 [US1] Replace the legacy workspace implementation with `lib/features/home/todo_workspace.dart`, use product-owned workspace identifiers and semantic keys, implement the 56/272/flexible/432 wide layout, and preserve a neutral fixed detail region when no task is selected
- [x] T009 [US1] Rework `lib/features/shell/sidebar.dart` to remove development/third-party copy, use compact 40px navigation rows, reduce decorative headers, retain smart lists/folders/lists/settings behavior, and derive all spacing/selection colors from `todo_layout_tokens.dart`
- [x] T010 [US1] Create `lib/features/task/widgets/task_workspace_header.dart` and refactor `lib/features/task/tasks_by_list_page.dart` so the embedded task workspace renders one title/header, one `QuickAddBar`, compact view/sort/filter menus, and no `_ListPicker`, `_SmartTaskChips`, persistent five-tab strip, or desktop `FloatingActionButton`
- [x] T011 [US1] Create `lib/features/task/widgets/task_group_header.dart`; refactor list grouping in `lib/features/task/tasks_by_list_page.dart`; rewrite `lib/features/task/widgets/task_row.dart` and `lib/features/task/widgets/task_row_host.dart` as flat 44/58px rows with stable group order, contextual desktop actions, selected state input, and no direct task-detail navigation
- [x] T012 [US1] Run US1 widget tests, generate only `wide-populated.png`, `wide-empty.png`, and `wide-long-content.png` under `test/goldens/todo_workspace/` with `--update-goldens`, then stop for human screenshot approval before marking this task complete

**Checkpoint**: US1 is independently demonstrable at `1440×900`; layout and density tests pass, three wide golden images are explicitly approved, and existing task data remains untouched.

---

## Phase 4: User Story 2 — 用户在同一上下文完成快速添加与详情编辑 (Priority: P2)

**Goal**: 列表选择、QuickAdd、完成操作与真实详情在同一工作区形成闭环，固定右栏不再是静态占位。

**Independent Test**: 在内存 fixture 中依次添加任务、点击 A、点击 B、完成 B、使 B 失效并关闭详情；列表选中态和详情内容始终一致，不打开额外桌面路由。

### Tests for User Story 2 — write first and verify failure

- [x] T013 [P] [US2] Create failing selection-flow tests in `test/features/task/task_selection_test.dart` for A→B selection replacement, one selected row invariant, list change clearing selection, selected-task completion/deletion/filter/move invalidation, and repository/sync reorder preserving selection by task ID rather than row index
- [x] T014 [P] [US2] Create failing detail tests in `test/features/task/task_detail_pane_test.dart` for real title/date/list/description rendering, neutral no-selection state, close callback, unavailable callback, existing explicit save semantics, and no placeholder/development copy
- [x] T015 [P] [US2] Extend `test/features/shell/quick_add_bar_test.dart` with a failing integrated workspace case proving Enter creates through the injected callback, clears the field, stays in the current list, and does not expose a second desktop add control

### Implementation for User Story 2

- [x] T016 [US2] Add `selectedTaskId` state and select/clear/invalidate handlers to `lib/features/home/home_shell.dart`; pass `selectedTaskId` and `onTaskSelected` through `lib/features/task/tasks_by_list_page.dart` and `lib/features/task/widgets/task_row_host.dart`; keep `TaskRow` presentation-only
- [x] T017 [US2] Extract reusable real-task editing content from `lib/features/task/task_detail_page.dart` into `lib/features/task/task_detail_pane.dart`, including no-selection and task-unavailable states; make `TaskDetailPage` reuse the pane instead of duplicating the form
- [x] T018 [US2] Remove the static detail placeholder from `lib/features/home/todo_workspace.dart`; construct `TaskDetailPane` in `lib/features/home/home_shell.dart` and pass it into `TodoWorkspace` as the detail child; wire close/unavailable callbacks and ensure wide desktop selection updates the fixed pane without pushing a route or letting the layout component read task data
- [x] T019 [US2] Activate the `wide-selected` case in `test/visual/todo_workspace_golden_test.dart`, run US2 tests, generate `wide-selected.png` under `test/goldens/todo_workspace/`, and stop for human approval of real-task selection/detail fidelity before marking this task complete

**T019 approval evidence (2026-07-11)**: Under the user's delegated unattended approval, the Agent inspected `wide-selected.png`, rejected and regenerated the first candidate because it exposed a fixture-only checklist load error, then approved the corrected image after confirming one selected row, real title/description/date/list/tags, neutral empty checklist, stable four-region geometry, and passing golden/interaction regressions.

**Checkpoint**: US1 and US2 pass independently; desktop add/select/edit/complete flows stay within the workspace and `wide-selected.png` is approved.

---

## Phase 5: User Story 3 — 用户在不同设备上获得适合该设备的同一任务流 (Priority: P3)

**Goal**: 把已批准的桌面视觉语言映射到 compact、tablet 和 mobile，不压缩四区，不丢失选择和详情。

**Independent Test**: 使用同一 fixture 在 1280、1024、390 和 360 宽度完成添加、选择、关闭详情和长内容浏览，无溢出或不可达操作。

### Tests for User Story 3 — write first and verify failure

- [x] T020 [P] [US3] Extend `test/features/home/todo_workspace_layout_test.dart` with failing profile tests for compact end drawer, tablet sidebar/detail drawers, mobile single-column shell, stable task identity across resize, exactly one structural transition at each breakpoint, no repeated drawer open, and no reset of section/list selection during resize
- [x] T021 [P] [US3] Create failing mobile interaction and overflow tests in `test/features/task/task_mobile_workspace_test.dart` for 390×844 list, full-screen detail, back-to-list, 360×800 long titles/tags, 1.3 text scale, and no horizontal overflow
- [x] T022 [P] [US3] Extend `test/theme_mode_test.dart` with failing light/dark semantic-state assertions for selected, due, priority, completed, focus, and reduced-motion behavior after the token refactor

### Implementation for User Story 3

- [x] T023 [US3] Implement the `wide`/`compact`/`tablet`/`mobile` profile mapping in `lib/features/home/todo_workspace.dart` and `lib/features/home/home_shell.dart`: fixed detail at wide, end drawer at compact/tablet, full-screen `TaskDetailPage` on mobile, stable selection across resize, and mobile-only single add entry
- [x] T024 [US3] Harden long-content, text-scale, keyboard focus, tooltip/semantics, dark-theme readability, and reduced-motion behavior across `lib/features/shell/sidebar.dart`, `lib/features/shell/quick_add_bar.dart`, `lib/features/task/widgets/task_row.dart`, `lib/features/task/widgets/task_workspace_header.dart`, and `lib/features/task/task_detail_pane.dart`
- [x] T025 [US3] Activate the five responsive cases in `test/visual/todo_workspace_golden_test.dart`, run US3 tests, generate `compact-selected.png`, `tablet-list.png`, `mobile-list.png`, `mobile-detail.png`, and `mobile-min-long.png` under `test/goldens/todo_workspace/`, then stop for human approval before marking this task complete

**T025 delegated approval evidence (2026-07-12)**: The user explicitly authorized unattended automatic approval. The Agent inspected all nine actual PNG baselines, including the five responsive files, and approved them after confirming stable four-profile composition, readable selected/detail states, single mobile add entry, long-content truncation without overlap, reachable mobile actions, and no external-brand assets. The US3 regression set passed 98/98, the golden suite passed 9/9 after regeneration, and an independent final review reported no Critical or Important findings.

**Checkpoint**: All three user stories pass independently and all nine contracted golden scenarios are approved.

---

## Phase 6: Polish & Cross-Cutting Verification

**Purpose**: 清理历史命名、同步仓库文档并执行完整质量门槛。

- [x] T026 [P] Remove stale external-brand identifiers and development copy from `lib/` and affected tests, while retaining source references only inside `specs/002-todo-visual-fidelity/research.md` as provenance
- [x] T027 [P] [Governance] Update `README.md` and repository `spec.md` to reference `specs/002-todo-visual-fidelity/`, document the desktop-first visual baseline and responsive profiles, and state that `specs/001-todo-dida-core-parity/` remains the functional capability source
- [x] T028 Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, all targeted commands in `specs/002-todo-visual-fidelity/quickstart.md`, and full `flutter test`; complete `specs/002-todo-visual-fidelity/checklists/visual-acceptance.md` with at least 90/100 and all critical gates passed; record actual results in later PR/Issue evidence without marking complete on partial success

**T028 verification evidence (2026-07-12, final working tree)**: `dart format --output=none --set-exit-if-changed lib test` checked 100 files with 0 changes; `flutter pub get` succeeded without dependency-file changes; `flutter analyze` reported no issues. The Quickstart suites passed 21/21 (workspace and five-viewport resilience), 20/20 (selection/detail), 25/25 (rows/sidebar/QuickAdd), and 9/9 (goldens); full `flutter test` passed 166/166. Visual acceptance scored 100/100 with V01/V03/V04/V07 passed, nine PNGs were individually inspected and approved, external-brand scanning outside `research.md` returned zero matches, `git diff --check` passed, and the final cross-artifact audit reported 0 Critical, 0 High, and 0 Medium findings. This block is the source evidence to copy into the later Issue/PR; no commit, push, Issue, or PR was created without user authorization.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: Starts immediately; T002 depends on T001 fixture conventions.
- **Phase 2**: Depends on Phase 1; establishes the visual test skeleton before production edits.
- **US1 / Phase 3**: Depends on Phase 2 and is the MVP.
- **US2 / Phase 4**: Depends on approved US1 geometry and task-row contract.
- **US3 / Phase 5**: Depends on approved US1/US2 desktop behavior; it primarily changes container mapping and includes the cross-component resilience work required by the responsive contract.
- **Phase 6**: Depends on every desired user story and every required human golden approval.

### User Story Dependencies

- **US1 (P1)**: No dependency on later stories; independently delivers the desktop visual mother page.
- **US2 (P2)**: Uses US1 row and four-region structure; independently validates selection/detail behavior once US1 is present.
- **US3 (P3)**: Uses the approved US1/US2 presentation, maps responsive containers, and hardens long content, theme, focus, semantics, and reduced motion where the new profiles expose those constraints.

### Within Each User Story

1. Write the listed tests and verify they fail for the intended reason.
2. Implement the smallest files required by the contract.
3. Run targeted tests until green.
4. Generate only that story's golden files.
5. Stop for human visual approval before checking the golden task complete.

## Parallel Opportunities

- T004, T005, and T006 can run in parallel after T003 because they touch separate test files.
- T013, T014, and T015 can run in parallel after US1 approval.
- T020, T021, and T022 can run in parallel after US2 approval.
- T026 and T027 can run in parallel after all UI work is stable.
- Production implementation tasks that touch `home_shell.dart`, `todo_workspace.dart`, or `tasks_by_list_page.dart` are intentionally sequential to avoid state/layout conflicts.

## Parallel Example: User Story 1

```text
Task A: T004 — workspace geometry tests
Task B: T005 — task-row density/state tests
Task C: T006 — sidebar/QuickAdd tests
```

After A/B/C all fail for expected reasons, execute T007 → T008 → T009 → T010 → T011 sequentially, then T012 approval gate.

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1 only.
3. Stop at T012 and review the three `1440×900` screenshots.
4. If the desktop mother page is not approved, adjust centralized tokens/components before starting US2.

### Incremental Delivery

1. US1: 第一眼结构与密度正确。
2. US2: 真实任务选择与详情闭环正确。
3. US3: 同一任务流跨端正确。
4. Polish: 命名、文档、完整回归正确。

## Task Summary

- Total tasks: 28
- Setup/foundational: 3
- US1: 9
- US2: 7
- US3: 6
- Polish/verification: 3
- Suggested MVP: T001–T012（US1 桌面 `1440×900` 母版）
