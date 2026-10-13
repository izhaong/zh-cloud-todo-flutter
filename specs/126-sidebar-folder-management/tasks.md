# 执行记录：矩阵 #18 面①④（FL #627 / FL #355）

## 落地的改动

- `lib/features/list/list_actions.dart`：动作表新增 `sidebar-list-action-folders`（「文件夹管理」，排在「编辑」之后），点它 push `FolderPage`；同时把整张表改成 `isScrollControlled` + `SingleChildScrollView`（新增档位后 320px + 1.3 倍字号装不下，见探针 P3）。
- `lib/features/shell/sidebar_list_folder_merge.dart`（新）：`SidebarListMergeDrag` 载荷、`SidebarListDragHandle`（悬停或窄视口才出现的行尾手柄）、`SidebarListMergeTarget`（落点是另一条清单）、`createFolderByMergingLists`（命名弹窗 → 建夹 → 两条清单搬进去；搬失败回滚建夹并给可见提示）。
- `lib/features/shell/sidebar.dart`：`_ListRow` 由 `ConsumerWidget` 改为 `ConsumerStatefulWidget`，加 `MouseRegion` 悬停态、外层包 `SidebarListMergeTarget`、行尾挂手柄。既有左滑动作表与长按入口一字未改。
- 用例：`test/features/shell/sidebar_folder_management_test.dart`、`test/features/shell/sidebar_list_drag_create_folder_test.dart`。

## 门禁读数（本轮提交前的字节）

- `flutter analyze` ⇒ `No issues found!`，rc=0。
- `flutter test` ⇒ `bash tool/gate_counts.sh <日志>` 打印 `last=1990/26/5 max=1990/26/5 complete=yes`；基线（develop `e2e57521efb3`）为 `last=1978/26/5 max=1978/26/5 complete=yes`，通过数 1978→1990 的差值正好等于新增用例数（复算 `git diff --stat` 里这两个 test 文件的 `testWidgets(` 行数之和 = 12）。
- 失败名单与基线逐项相同（habit 年度热力 2 项＝FL #607、task_organize 时区 2 项＝FL #610、raw_error_text 门禁 1 项＝FL #569），本轮零新增红。
- 黄金基线：`test/visual/todo_workspace_golden_test.dart` 的 9 张全绿，未重录任何 PNG（复算 `git status --porcelain test/goldens` 无输出）。

## 探针

- P1 摘实现（把 `sidebar.dart`、`list_actions.dart` 换成 `origin/develop` 的字节）⇒ 新用例 11 项红，用 `grep -c "\[E\]"` 数。
- P2 还原后 `cmp -s` 逐字节相同 ⇒ 探针没有毁掉本轮实现。
- P3 既有溢出用例 `test/features/list/list_share_entry_test.dart` 在加档后先红（`A RenderFlex overflowed by 17 pixels on the bottom`）⇒ 改弹层为可滚动，而不是放宽那条断言。

## 交叉验证提示词

见本目录 `spec.md` 的「交叉验证」段：`cursor-agent -p --trust` 收 stdin 提示词，只允许它用 `git -C zh-cloud-todo-flutter show origin/develop:<path>` 只读方式看代码（本轮工作树会被并行会话清扫，因此禁止它 cd 进仓库）。

## 与矩阵的承接

矩阵 `#18` 行状态仍「部分」：本轮补齐面①（入口可达）与面④（拖清单建夹），但该行「术语照抄嘀嗒」那条（本端文案「删除文件夹」应为「解散文件夹」）已在 FL #312 收口，落点端 `BE/FL` 不变。若判据源与本轮实测冲突，以本轮字节为准并在此追记。
