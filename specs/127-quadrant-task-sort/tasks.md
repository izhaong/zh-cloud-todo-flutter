# 127 台账

## T1 仓储

- `TaskWorkspacePreference.quadrantTaskSort`（Map q1..q4 → TaskSort.name，
  valueJson 编解码对称）；`saveQuadrantTaskSort(sourceKey, quadrant, sort,
  current)`：档名/象限名白名单校验（ArgumentError）+ current 合并（patch
  整键覆盖，由调用方传现值）。

## T2 视图与页面

- `eisenhower_view.dart`：`quadrantTaskSort`/`onQuadrantSortChanged` 参数；
  分桶后按档排序（`compareTodoTasks` 复用）；每象限头「…」菜单
  （key `quadrant-sort-<象限>`，当前档勾选）。
- `tasks_by_list_page.dart`：`_quadrantTaskSort` 状态 + restore 回读 +
  `_changeQuadrantTaskSort`（失败回退所选 + 可见 SnackBar，ArgumentError
  单独提示「排序档无效」）。

## T3 用例（test/features/task/quadrant_task_sort_test.dart，8 条）

- widget 4：默认无入口 + 输入顺序 / 菜单回调 / createdAt 档重排 + 当前档
  勾选 / 未选档象限不受影响。
- 页面 1：选档 → 偏好落库 → 界面生效。
- 仓储 3：非法档名 / 非法象限名 / current 合并。

## T4 探针（各自红后还原）

- PA 比较器摘掉（桶直接透传）⇒ 1 红。
- PB 档名白名单删除 ⇒ 2 红。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +8（2 探针各自红后还原） |
| 全量 | `+2007 ~26 -1`（基线 `+1987 ~26 -1` + 本切片 8 + 存量计数差 12 条来自 dart format 触碰的测试文件里既有用例计数变化——复核 `git diff` 未删任何用例，差额为 joiner 计数口径；唯一红 #569 存量） |
