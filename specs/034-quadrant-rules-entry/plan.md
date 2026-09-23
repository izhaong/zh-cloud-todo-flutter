# 四象限规则入口 实施计划

## 现状与缺口（开工前复验，不抄上一轮结论）

- `QuadrantRulesPage`（`lib/features/quadrant/quadrant_rules_page.dart:10`）在 develop 上已实现完整 CRUD：
  读 `quadrantRulesProvider`（`:15`）、失败态 `_LoadError`（`:29`，文案 `规则加载失败：$error` + 「重试」`:393`，
  该 `:393` 是 `origin/develop` 基准，本分支 HEAD 上是 `:394`）、
  空态（`:371` 「还没有四象限规则」）、规则行 `ListTile` + `编辑/删除` 菜单（`:53-68`）。
- 可达性复验：`Grep "QuadrantRulesPage|四象限" lib/ test/` ⇒ 生产侧只有该文件自身；
  `test/quadrant_rules_page_test.dart:25,45` 是直接 `MaterialApp(home: QuadrantRulesPage())` 泵出来的，
  **没有任何 in-app 导航指向它** ⇒ 矩阵 #36 判「实现齐但走不到」成立。
- `origin/feat/136-quadrant-rules` 相对 develop **0 提交**（`git log origin/develop..origin/feat/136-quadrant-rules` 空、
  `git branch -a --contains` 含 develop）⇒ 规则页那次交付已合并，本轮不是重做它。

## 落点选择

生产里 `TasksByListPage` 只有一个使用者：`home_shell.dart:669` 且 `hideAppBar: true`
⇒ 页面自己的 `AppBar.actions`（`tasks_by_list_page.dart:281`）在生产是死分支，
真正常驻的顶部条是 `TaskWorkspaceHeader`（`lib/features/task/widgets/task_workspace_header.dart`）。
它的「排序与批量编辑」菜单（key `todo-sort-menu`）已经承载两个**按视图条件出现**的动作：
批量编辑（`onBatchPressed != null`）与「新建分组」（仅 `_mode == TaskViewMode.list`，`tasks_by_list_page.dart:202`）。
⇒ 入口就加在这个菜单里，同样按 `_mode == TaskViewMode.eisenhower` 条件出现。
这与嘀嗒「四象限页面右上角『...』→『编辑』」同构，且不新建表面、不动侧栏/dock/共享工具栏。

## 步骤 → 验证

1. 红测（`test/features/task/quadrant_rules_entry_test.dart`，**最终 5 例**：初版 4 例，
   第 1 轮复核补第 5 例覆盖编辑器弹窗）⇒ 逐条失败信息必须指向缺失项，
   不能是「切不到四象限视图」这类前置失败。
2. 最小实现：`TaskWorkspaceHeader` 加可选 `onEditQuadrantRules` + 菜单项；`tasks_by_list_page` 按视图传值并 `Navigator.push`。
3. 反向探针 PA/PB/PC/PD（见 tasks.md；PD 又拆成 PD/PD2 两种字体配置），恢复后 `cmp -s` 逐字节一致。
4. 六项门禁 → 最终版 `/tmp/gate-034d.log`（修订前的两版留在 `/tmp/gate-034.log`、`/tmp/gate-034c.log`）；
   只读子代理复核 FR-1..FR-5 拿 `VERDICT`（两轮各一次）。
5. 回写 `tasks.md` 与矩阵 #36 行（未合并前只写「已实现待合并」）。

## 明确不做

- 不实现「拖动任务改象限即改优先级/时间」、不改四象限规则的判定算法 —— 属 #34/#35 面。
- 不为「更保险」申请重录 9 张黄金基线：`grep -rn "eisenhower|TaskViewMode" test/visual test/support` 零命中
  ⇒ 黄金用例从不切到四象限，往该视图的菜单里加一项不可能改变基线像素。
- 不动 `/app-api/todo/quadrant/**` 契约：规则页已把它消费完。
