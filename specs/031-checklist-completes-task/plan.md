# 031 计划

## 落点（单点改动，不新增文件层次）

- `lib/state/repositories/task_repository.dart`
  - `toggleChecklistItem`：在写完检查事项与其 outbox 之后，若本次是"勾成完成"，调用私有守卫
    `_completeTaskWhenChecklistDone(parent)`。
  - `_completeTaskWhenChecklistDone(TodoTask task)`：`completed || cancelled` 直接返回；
    重查该任务全部检查事项，空集或仍有未完成则返回；否则 `copyWith(completed:true, completedAt:now, updatedAt:now)`
    写回 `todoTasks`，并用既有 `_taskPayload` 再入队一条 `task/upsert`。
  - 复用既有 `Value` / `_queue.enqueue` / `_taskPayload`，不新增 provider、不新增表、不加开关配置。
- `test/features/task/checklist_completes_task_test.dart`：7 条 repository 用例（纯 Dart `test()`，
  `AppDatabase.forTesting(NativeDatabase.memory())` + `TaskRepository(db, SyncChangeQueue(db))`）
  + 1 条 `TaskDetailPane` widget 用例（`TodoVisualFixture` + `UncontrolledProviderScope`，760×900）。

## 为什么放这里

规则要在**唯一写入口**里生效：详情面板、列表行、将来批量导入与同步回灌都经 `TaskRepository`，
放 UI 会漂；放 `app_database.dart` 的 helper 则拿不到 `_queue`（outbox 在 repository 侧），
所以取"事务内的 repository 私有方法"。

## 被否方案

1. **UI 层判断后调 `toggleComplete`** — 见 `spec.md`；且会产生两条 outbox（勾选 + 完成）。
2. **`todo_task` 加 `auto_completed` 标记列以支持反向回退** — 需要 SQL 增量 + Service 契约同步（属需授权动作），
  且嘀嗒帮助页并未要求反向回退。
3. **让服务端算完成态再回灌** — 违背离线优先；`/app-api/todo/**` 无该语义，不为一条本地规则去造端点。

## 影响面核对

- `toggleComplete` / `abandon` / 完成态相关的其它调用方未改（`task_detail_pane.dart:892`、
  `widgets/task_row_host.dart:147,177`）。
- `deleteChecklistItem`（`task_repository.dart:714`）本轮**不挂**该规则，作为仍缺记在 `tasks.md`。
- 入口不在任何侧栏/dock/路由上，不改可见布局 ⇒ 9 张黄金图基线预期不变（已用 `flutter test --tags golden` 证实）。
