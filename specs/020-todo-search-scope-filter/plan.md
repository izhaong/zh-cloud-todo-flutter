# Todo 搜索范围与任务组合筛选 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让离线优先的 Todo 搜索页具备滴答清单式范围切换、任务组合筛选和稳定分页。

**Architecture:** `TaskQueryRepository` 新增强类型请求和分页结果，在本地 FTS 结果与既有 `TaskQueryFilter` 间做确定性交集。`TaskSearchPage` 仅消费 Repository，并将范围、任务筛选、已加载页和失败状态留在页面状态；筛选选择器读取 Drift 中的清单、标签，不发起 HTTP 请求。

**Tech Stack:** Flutter、Dart 3.11、Drift/SQLite FTS5、Riverpod、Material 3、flutter_test。

## Global Constraints

- 只在 `codex/242-todo-search-scope-filter` 本地分支工作；不使用 worktree。
- Drift 是搜索结果唯一真相源；不得将网络结果覆盖未同步的本地数据。
- 任务范围的关键词、清单、标签、优先级和日期条件全部为 AND；标签条件彼此也为 AND。
- 页长固定为 50，稳定排序仍为任务、清单、标签、标题、实体 ID；不得以 widget 索引作为稳定键。
- 320px 下不允许横向溢出，所有可操作控件必须有键盘和读屏名称。

---

### Task 1: Repository scope and pagination contract

**Files:**
- Modify: `lib/state/repositories/task_query_repository.dart`
- Modify: `test/task_organize_search_repository_test.dart`
- Modify: `test/task_query_repository_persistence_test.dart`

**Interfaces:**
- Produces `TaskSearchScope { all, task, list, tag }`.
- Produces `TaskSearchPageRequest(keyword, scope, filter, offset, limit)` and `TaskSearchPageResult(results, total)`.
- Produces `TaskQueryRepository.searchPage(TaskSearchPageRequest request)`.

- [ ] **Step 1: Write repository red tests**

Create 55 fixed UUID task matches plus one list and one tag match. Assert page one contains 50 stable task IDs, page two contains the remaining five, `total` is 55 in task scope, and the same request repeats byte-for-byte. Add a task request with list, two tags, priority and inclusive date bounds; assert only the one matching task remains. Assert a list scope ignores task filters.

- [ ] **Step 2: Run the red tests**

Run: `flutter test test/task_organize_search_repository_test.dart --plain-name 'search page scopes and combines task filters before pagination'`

Expected: compilation failure because paged scope types and `searchPage` do not exist.

- [ ] **Step 3: Implement the minimal local query contract**

Reuse the parameter-bound Drift FTS result order. `searchPage` must first derive the stable matching result set, apply `TaskQueryFilter` only to task result IDs, then slice after filtering. Validate `offset >= 0` and `1 <= limit <= 50`; reject an inverted date range through the existing filter validation.

- [ ] **Step 4: Run focused repository tests**

Run: `flutter test test/task_organize_search_repository_test.dart test/task_query_repository_persistence_test.dart`

Expected: PASS.

### Task 2: Scoped search and task filter UI

**Files:**
- Create: `lib/features/task/task_search_filter_sheet.dart`
- Modify: `lib/features/task/task_search_page.dart`
- Modify: `test/features/task/task_organize_search_test.dart`

**Interfaces:**
- Consumes `TaskSearchPageRequest`, `TaskSearchPageResult`, current Drift lists and tags.
- Produces `TaskSearchFilterDraft` with `listId`, `tagIds`, `priority`, `dueAtFrom`, and `dueAtTo`.

- [ ] **Step 1: Write scoped UI red tests**

Enter a keyword that matches task/list/tag fixtures. Assert the all scope shows all three, task scope hides list/tag, and list/tag scopes each show only their own type. In task scope select a list, two tags, priority and date range; assert only the matching task is rendered and the filter count is announced. Clear filters and assert the keyword plus task scope remain.

- [ ] **Step 2: Run the red Widget tests**

Run: `flutter test test/features/task/task_organize_search_test.dart --plain-name 'search scopes task results and applies local combined filters'`

Expected: FAIL because no range controls or scoped result query exist.

- [ ] **Step 3: Implement page state and sheet**

Use a compact `TabBar` or scrollable segmented control with explicit semantics labels for all four scopes. Show a filter button and selected-condition count only for task scope. The sheet must use local list/tag rows, permit multi-tag selection, offer priority clear, and use date pickers with an inclusive date range. Closing without apply leaves state unchanged; apply reloads from offset zero; clear only resets `TaskSearchFilterDraft`.

- [ ] **Step 4: Run the scoped UI tests**

Run: `flutter test test/features/task/task_organize_search_test.dart`

Expected: PASS.

### Task 3: Load more, resilience and accessibility

**Files:**
- Modify: `lib/features/task/task_search_page.dart`
- Modify: `test/features/task/task_organize_search_test.dart`
- Modify: `specs/020-todo-search-scope-filter/tasks.md`

- [ ] **Step 1: Write load-more and 320px red tests**

Use 51 matching tasks. Assert page one exposes “加载更多 1 条”, tapping it appends the final result without removing page one, and a stale load-more response cannot replace a newer keyword/scope result. At 320px assert no exception and semantic labels for scope, filter, clear and load-more.

- [ ] **Step 2: Run the red tests**

Run: `flutter test test/features/task/task_organize_search_test.dart --plain-name 'search appends stable pages and isolates stale requests'`

Expected: FAIL because the page has no page state or stale-request isolation.

- [ ] **Step 3: Implement append-only pagination and feedback**

Keep a monotonically increasing request token. A successful first page replaces only when current; a successful next page appends unique `identity` values only when current. A failed next page preserves prior results and shows a retryable feedback action. Disable duplicate load-more while that request is in flight.

- [ ] **Step 4: Run focused regression tests**

Run: `flutter test test/features/task/task_organize_search_test.dart test/task_organize_search_repository_test.dart`

Expected: PASS.

### Task 4: Full verification and cross-review

**Files:**
- Modify: `specs/020-todo-search-scope-filter/tasks.md`

- [ ] **Step 1: Run formatting and static analysis**

Run: `dart format --output=none --set-exit-if-changed lib/core/db/app_database.dart lib/state/repositories/task_query_repository.dart lib/features/task/task_search_page.dart lib/features/task/task_search_filter_sheet.dart test/task_organize_search_repository_test.dart test/task_query_repository_persistence_test.dart test/features/task/task_organize_search_test.dart`

Run: `flutter analyze`

- [ ] **Step 2: Run complete local gates**

Run: `flutter test --concurrency=1`

Run: `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`

- [ ] **Step 3: Run Claude CLI read-only review**

Review this spec, the changed database/repository/page/sheet files and tests. Record a literal pass verdict or the exact external blocker; do not treat a timeout as approval.
