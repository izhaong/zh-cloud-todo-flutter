# 四象限规则入口（嘀嗒《03-四象限/02-如何编辑四象限规则》）

## 嘀嗒原样（唯一口径，不自创交互）

帮助中心 `zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/03-四象限/02-如何编辑四象限规则.md`：

- 规则编辑发生在**四象限视图内**（页面截图就是四象限里点开的规则面板），不是一条独立的顶级导航。
- 术语：象限、规则、自定义象限规则；维度为 清单/标签、时间、优先级。
- 默认给两套规则组合（优先级 / 时间+优先级），可自定义。

## 现有落点（本规格的地基）

- 视图：`features/task/`lib/views/eisenhower_view.dart`6` `EisenhowerView`，由
  `lib/features/task/tasks_by_list_page.dart`（基准 `origin/develop`；本分支 HEAD 上是 `:452`）
  在 `TaskViewMode.eisenhower` 分支渲染；
  枚举与标签 `lib/features/task/view_mode.dart`（枚举与标签三处，行号随编辑漂，按符号名搜）。⇒ 四象限视图本身**可达**（矩阵 #34/#35 有依据）。
- 规则页：`lib/features/quadrant/quadrant_rules_page.dart` `QuadrantRulesPage` 已实现完整的
  读/新建/编辑/删除（`:105` `quadrantApiProvider`、`:111/:120` create/update、`:167` 删除确认、
  `:291` 「新建/编辑四象限规则」表单、`:371` 「还没有四象限规则」空态），读写落 `/app-api/todo/quadrant/**`。
- **缺口（本轮要修的）**：全库（`lib/` + `test/`）只有该文件自身的定义与它自己的用例引用它 ——
  `git grep -n "QuadrantRulesPage" origin/develop` 命中 4 行，全部落在
  `quadrant_rules_page.dart:10,11` 与 `test/quadrant_rules_page_test.dart:25,45` ⇒ **没有任何导航入口，
  用户走不到这个页面**。矩阵 #36 原先拿废弃 Web 当证据，属验收口径里的无效证据。

## 功能需求

- FR-1 「编辑象限规则」出现在**四象限视图的右上角「...」菜单里**（即既有 `todo-sort-menu`，与
  「批量编辑」「新建分组」同一个菜单位置），措辞照帮助中心，不发明同义词（不叫「设置」「配置」。
- FR-2 点入口进入 `QuadrantRulesPage`，不新起路由栈语义：用 `Navigator.push`，返回后仍停在四象限视图。
- FR-3 入口只在四象限视图出现，其它四种视图（列表/看板/时间线/日历）不得多出这个动作
  —— 四种视图逐个负向断言，且每个都带「批量编辑」正对照证明菜单确实展开了（否则 `findsNothing` 是空转）。
- FR-4 四件套：320px + 1.3 倍字体不溢出（档位要在 push 出来的规则页**自己的 context** 上自检，
  不能只包 `home:`；规则页数据态与编辑器弹窗也在 320px 下排版）、入口与页面标题各自是独立可读屏节点、
  规则读取失败要明说且不伪装成空态。
  **撤掉的子句**：「同一入口连点只叠一层页面」不可证 —— `PopupMenuMenuItem` 选中即关菜单，
  不重开菜单点不到第二次，也就没有可叠的第二次导航；留着它等于写一条永远绿的判据。
  **另记未做**：「过期响应不覆盖新响应」属规则页数据层竞态。原因**不是**脚手架缺能力 ——
  `TodoVisualFixture.create` 在 develop 上就有 `overridesBuilder`（`test/support/todo_visual_fixture.dart:60`、`:90`），
  只是本仓包装 `pumpTodoVisualScenario` 没往下透传（`test/support/todo_visual_test_harness.dart:35`）；
  细节与两条可选做法见 tasks.md T007。
- FR-5 不改动服务端契约：`/app-api/todo/quadrant/**` 已被规则页消费完，本轮无后端缺口。

## 取舍与被否方案

- **入口放四象限视图头部，不放设置页聚合入口**：嘀嗒那里就是视图内的动作；
  被否：照 #76–78 成就入口那样塞进 `settings_route.dart` —— 那会把「规则」从它作用的视图里搬走，
  用户要先离开四象限才能改规则，属自创交互。
- **不改 9 张黄金基线**：`git grep -iE "eisenhower|四象限|viewMode" origin/develop -- test/visual test/support`
  ⇒ **0 命中**（命令原先漏写 `-E`，`|` 被当字面量 —— 复核员指出后按 `-E` 复跑仍 0 命中，结论不变；
  同时反向自检 `-iE` 跑在 `lib` 上得 63 命中，证明是这三张目录里真没有，不是正则写坏了）；
  黄金用例从不切到四象限模式，往该视图头部加一行不可能改变基线；
  被否：为"更保险"去申请重录基线。
- **加在既有「...」菜单里、按视图条件出现，不新造头部行**：`TaskWorkspaceHeader` 的 `todo-sort-menu`
  已经承载两个按视图条件出现的动作（批量编辑、仅列表视图的「新建分组」`tasks_by_list_page.dart:202`）
  ⇒ 沿用同一模式，四象限之外拿到的回调是 `null`，其它视图的像素与菜单项一字不变。
  被否：给四象限视图另起一条专属头部行 —— 那是嘀嗒没有的新表面。
- **不往 `AppBar.actions` 加**：生产里 `TasksByListPage` 只有 `home_shell.dart:669` 一个使用者且 `hideAppBar: true`
  ⇒ `tasks_by_list_page.dart:281` 那个 actions 分支在生产拿不到，加在那里等于加一条走不到的入口。

## 验证边界（诚实）

- 证据只来自 `flutter test` 用例 + 反向探针 + 六项门禁日志；不含真机、不含远端 CI
  （runner `cgroup is not mounted`、Jenkins Job 不可达）。
- 规则的**内容**（拖拽改象限即改优先级、两套默认规则组合）不在本规格范围：
  那属 #34/#35 与「拖动调整象限」这一面，本轮只补「走得到规则页」这一条断裂。
