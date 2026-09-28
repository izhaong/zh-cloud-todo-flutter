# 台账（specs/066 日历任务拖入清单详情区域）

Issue：zh-cloud-todo-flutter #398　矩阵：zh-cloud-docs `todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 的 #32 面 ②
判据源：`99_参考资料` 镜像《02-功能指南/02-日历/07-任务与日历同时显示.md》`:53`/`:55`（镜像在 zh-cloud-docs 仓）

## 一、判据与实现

- [x] 落点只换所属清单、保留时间安排、清掉分组 —— `lib/features/task/list_drop_target.dart` 的 `TaskListMoveController.handleDrop`
- [x] 落点只在列表模式 + 选中具体清单时存在 —— `lib/features/task/tasks_by_list_page.dart` 里 `currentListId: _mode == TaskViewMode.list ? listId : null`
- [x] 同清单不构成迁移 —— 同文件 `onWillAcceptWithDetails`

## 二、门禁（写在最终字节上，逐条现跑现读）

| 门 | 命令 | 读数 |
| -- | ---- | ---- |
| 1 `git diff --check` | `git diff --check` | 见 §五 提交前复跑 |
| 2 格式 | `dart format --output=none --set-exit-if-changed <本轮 3 个文件>` | 见 §五 |
| 3 静态 | `flutter analyze` | `No issues found! (ran in 3.6s)` |
| 4 黄金 | `flutter test --tags golden` | 见 §五，基线 9 张、不重录 |
| 5 全量 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 见 §五 |
| 6 构建 | `flutter build web --release …` | 见 §五 |

本面自己的单测先跑：`flutter test test/features/task/calendar_task_into_list_test.dart` ⇒ `00:00 +6: All tests passed!`（6 条用例）。

## 三、四件套

- 窄屏与字号：用例名「320px + 1.3 倍字号下落点仍自带读屏语义，且不溢出」，
  断言 `tester.getSemantics(find.byKey(TaskListDropTarget.zoneKey)).label` 含 `移入当前清单`，并量该节点宽 ≤ 320。
- 读屏语义：label 挂在带 key 的落点节点自身（`container: true`），不是旁侧 `Text`。
- 失败保留已加载数据：用例「仓储不可用：给可见反馈，并且不动本地数据（任务还在原清单）」⇒ 断言库内 `listId` 仍是 `1`。
- 过期响应不覆盖新响应：用例「落库期间清单被切走：旧目标的失败提示不盖新界面」+
  用例「同一任务连着两次落点按先后串行，后一次不插队」。

## 四、后端契约

无需改 `zh-cloud-service`：换清单走既有任务更新，同步登记走既有 outbox upsert（无新列、无新端点）。

## 五、门禁读数（跑在本轮最终字节上；日志目录 `/tmp/r136/g66/`）

| 门 | 命令 | 读数 |
| -- | ---- | ---- |
| 1 | `git diff --cached --check` | rc=0、stdout 0 字节 |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/task/list_drop_target.dart lib/features/task/tasks_by_list_page.dart test/features/task/calendar_task_into_list_test.dart` | rc=0、`Formatted 3 files (0 changed) in 0.03 seconds.` |
| 3 | `flutter analyze` | rc=0、`No issues found! (ran in 1.2s)` |
| 4 | `flutter test --tags golden` | rc=0、`00:04 +9: All tests passed!` |
| 4b | `git status --porcelain -- test/goldens \| wc -l`；`git ls-files test/goldens \| grep -c '\.png$'` | 前者 0 行（改动 0 张）、后者 9（基线共 9 张）⇒ 基线一张都没重录，无需请示 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0、`03:24 +1140 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web` |

`pubspec.lock` 未随本次提交走：`git status --short` 的改动面只有 4 条 ——
`lib/features/task/list_drop_target.dart`、`lib/features/task/tasks_by_list_page.dart`、
`test/features/task/calendar_task_into_list_test.dart`、`specs/066-calendar-task-into-list/`。

台账自扫：`python3 tool/check_spec_selfscan.py specs/066-calendar-task-into-list/tasks.md` ⇒ rc=0、`失项 0 条`。

## 六、只读复核

- 第 1 轮：待派单（被审 head 以 §五 复跑后的 head 为准）。

## 七、回写与下轮入口

- 矩阵 #32 的「仍缺三面」在**本 PR 合并后**改成两面（②闭合），并同步 `:104` 的证据格与 `--summary`；未合并前矩阵不翻。
- 剩余两面：FL Issue #399（③「拖动到清单或标签上」）、FL Issue #400（④「拖动到智能清单上」）。
