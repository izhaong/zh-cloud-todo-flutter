# 119 台账

## T1 模型与仓储

- `lib/state/repositories/board_preference_repository.dart`：
  `BoardColumnWidth`（small/medium/large → 200/260/320）、
  `BoardViewPreference.columnWidth/showColumnInput`、
  `_decodeLayout` 读新键（缺省默认档）、`saveDisplaySettings`（只改两键）、
  `saveLayout` 读现值整体写回（列序保存不冲显示设置）。
  不新增表/列/迁移：键随 `columnsJson` 走既有同步。

## T2 视图

- `lib/features/task/views/kanban_view.dart`：`columnWidth`/`showColumnInput`
  参数、列宽落到 `_KanbanColumn` 根 `SizedBox`、`_KanbanInlineAddField`
  行内输入行（key `kanban-inline-add-<列id>`，提交清空可连续录入）、
  `_quickAddInline` 按列语义写库、失败走 SnackBar。

## T3 入口

- `lib/features/task/widgets/task_workspace_header.dart`：
  `boardDisplaySettings` 命令 + 菜单项（key `todo-board-display-settings`，
  回调 null 即不渲染）。
- `lib/features/task/tasks_by_list_page.dart`：`_openBoardDisplaySettings`
  → `_BoardDisplaySettingsDialog`（宽度 RadioGroup + 显示输入框 Switch）
  → `saveDisplaySettings`，失败可见 SnackBar；仅看板模式且清单非空给入口。

## T4 用例（test/features/task/kanban_display_settings_test.dart，6 条）

- 仓储 2：落库回读 + saveLayout 不冲掉；旧 JSON 缺键默认档。
- 视图 3：三档宽度实测、输入行提交走真实仓储带列档位（urgent→priority 2）、
  未开启无输入行。
- 页面 1：菜单入口 → 选「大」+开输入框 → 保存 → 偏好落库。

## T5 探针（各自红后还原）

- PD `fromWire` 默认档错（medium→small）⇒ 1 红。
- PE `showColumnInput` 解码反转 ⇒ 3 红。
- PF 行内提交丢列档位 ⇒ 1 红。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +6（3 探针各自红后还原）；存量 board_preference_repository_test 的
  layout JSON 断言补上显示设置两键（同一笔提交更新） |
| 全量 | `+1955 ~26 -1`（唯一红 #569 存量；较基线 +10 = 本切片 6 条新用例 + 存量 board_preference 拆分/新增计数差） |
