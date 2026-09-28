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

## 五-bis、并入 develop 之后在合并字节上重跑（2026-09-28，merge 提交 `5f580d4`，日志 `/tmp/r136/g66d/`）

develop 在 `b0649a4` 之后进了 specs/047（# 建标签，`af62a8bfa2da`）与 specs/064（日程跨日时间轴，`6f889ea0f8`），
本分支因此必须先并主干。冲突面复算：`git diff --name-only --diff-filter=U HEAD MERGE_HEAD` 只输出 `lib/features/task/tasks_by_list_page.dart`（1 个文件）⇒ 争的是 import 段两边各自新增的一条 import，两边都留、按 `../` 组与同目录组排序。

| 门 | 命令 | 读数 |
| -- | ---- | ---- |
| 1 | `git diff --check HEAD^2 HEAD`（`HEAD^2` = `origin/develop`，量的是本分支落到主干上的字节） | rc=0；`grep -c . /tmp/r136/g66d/g1.log` = 2（标题行 + `rc=0`），除标题外无任何输出 ⇒ 没有空白错误 |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/task/list_drop_target.dart lib/features/task/tasks_by_list_page.dart test/features/task/calendar_task_into_list_test.dart` | rc=0、`Formatted 3 files (0 changed) in 0.04 seconds.` |
| 3 | `flutter analyze` | rc=0、`No issues found! (ran in 3.9s)` |
| 4 | `flutter test --tags golden` | rc=0；`goldens_dirty=0 png=9` ⇒ 9 张基线一张都没重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0、`03:28 +1177 ~26: All tests passed!`（+1177 而非旧的 +1140：主干带进 specs/047 与 specs/064 的用例） |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web`、收尾 `status=0`（工作树干净，`pubspec.lock` 未动） |

真实合并试算：`git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0、干净树 `cda543a9b444`（不再依赖 mergeable 字段）。
台账自扫：`python3 tool/check_spec_selfscan.py specs/066-calendar-task-into-list/tasks.md` ⇒ rc=0。

## 六、只读复核
### 第 1 轮只读复核：`VERDICT: FAIL`（1 条阻塞 + 1 条台账账外问题），已按逐条回源处置

被审字节：分支 head `3768985`（门禁目录 `/tmp/r136/g66/`）。

- **判据 1–5 全过**：可达性（`tasks_by_list_page.dart:236-250` 只在列表模式挂落点，与看板/时间线/日历日格各自的 `DragTarget` 同帧互斥）、语义（只写 `listId` + `clearSectionId`，时间字段一律不传 ⇒ Drift `Value.absent()` 保字节）、四件套、两条反向探针（删 `clearSectionId` 红 2 条、删过期守卫红 1 条）复核员都独立复算过。
- **阻塞项 ⑧「PR 把已合并的 specs/064 反向删除」** ⇒ **回源复验后驳回**，书面理由：复核员看的是两点差 `git diff origin/develop feat/398-...`（分支落后主干时必然把主干新增的行显示成删除）。三点差与真合并都不删东西：`git diff --name-only origin/develop...3768985` 只有 6 个文件、不含 `lib/features/task/views/calendar_view.dart`；`git diff --stat 6f889ea ed28c3d83efe`（develop → 当时的合并树）为 `6 files changed, 663 insertions(+), 8 deletions(-)`，且 `git diff 6f889ea ed28c3d83efe -- '*calendar_view.dart'` 输出为空。⇒ 该主张不成立；但它指出的**分支落后**是真的，已用 §五-bis 的并主干 + 重跑解决。
- **账外问题 ⑥「§五 4b 的读数与复算命令不同行」** ⇒ 已改：4b 现在写「前者 0 行（改动 0 张）、后者 9（基线共 9 张）」，两条命令与两个读数在同一格同一行。



- 第 1 轮：待派单（被审 head 以 §五 复跑后的 head 为准）。

## 七、回写与下轮入口

- 矩阵 #32 的「仍缺三面」在**本 PR 合并后**改成两面（②闭合），并同步 `:104` 的证据格与 `--summary`；未合并前矩阵不翻。
- 剩余两面：FL Issue #399（③「拖动到清单或标签上」）、FL Issue #400（④「拖动到智能清单上」）。
