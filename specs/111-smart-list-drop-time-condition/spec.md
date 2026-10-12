# 规格：拖动到智能清单上（FL #400，矩阵 #32 拖动排期 ④）

## 判据源（嘀嗒原文，zh-cloud-docs 镜像）

`todo/99_参考资料/dida365-help-center/02-功能指南/02-日历/07-任务与日历同时显示.md`：

- `:47`「在任务与日历并列显示的视图中，你可以：」——四面（`:49`/`:53`/`:57`/`:61`）都挂在这个前提下；
  并列视图本身已由 PR !380 合并进 develop（矩阵 #32 行「已合并 ①」那段），所以 #400 单正文里
  「本单不排进 !380 合并之前的自主轮次」这条前置在 2026-10-12 已解除（现读 `pulls/380` ⇒ `merged: true`）。
- `:61`「拖动到智能清单上：」
- `:63`「会为任务自动添加该智能清单关联的时间条件，例如“今天”、“本周”等。」

同段前三面已落地：`:49`＝FL !405、`:53`＝FL !406、`:57`＝FL !407（`lib/features/shell/sidebar_task_drop.dart`）。
本规格只补第四面，且落点仍沿用同一套 `SidebarDropZone` + `SidebarTaskDropController`。

## 需求与裁定

1. **落点日不新造规则，取该档智能清单自己在用的日期窗口首日**。
   本端「今天 / 明天 / 最近七天」三档的过滤谓词就是 `lib/features/task/tasks_by_list_page.dart`
   的 `_dateConditionMatches`（`dueRange` = `today` / `tomorrow` / `next7days`）。
   `lib/features/shell/smart_list_time_condition.dart` 把同一套窗口写成显式区间，
   并要求**落完必须让任务真的出现在刚拖上去的那个清单里** —— 这是唯一被约束死的选法：
   区间型清单只有窗口内的日子才命中，而窗口首日是不需要用户再输入任何东西的唯一确定值。
   两侧一致性由 `test/features/shell/smart_list_time_condition_test.dart` 的「-10..+12 天逐日对账」钉住
   （谓词侧走公开入口 `applyTaskFilter`，不是抄一份预期）。
2. **只有带日期窗口的三档是落点**，其余五档（收集箱 / 指派给我 / 全部 / 已完成 / 垃圾桶）
   `smartListTimeConditionOf` 返回 null ⇒ 那几行根本不挂 `DragTarget`。
   理由逐档写在代码注释里：收集箱是**清单归属**（`:57` 那一面早已覆盖），
   指派给我按负责人、全部不限条件、已完成按完成态、垃圾桶按回收站，
   都没有 `:63` 那句「关联的时间条件」可落成的语义。
   「本端『最近七天』= 明天起 7 天（不含今天）」是谓词的既有口径（`_dateConditionMatches` 的
   `next7days` 下界就是 `todayEnd`），所以它的落点日与「明天」相同 ——
   这不是缺陷：两档不互斥，已在窗口后段的任务拖到「最近七天」按 3 跳过、拖到「明天」才会改日。
3. **已在窗口内 ⇒ 不是有效落点**（`SidebarTaskDropController.acceptsSmartList`），
   与 `acceptsList`「落回原清单不发写请求」、仓储「同一天不写不入队」同一口径，三层各自有用例。
4. **只改截止日那一格**：时刻（有则按展示墙钟保留）、清单归属、分组、标签一律不动；
   无日期任务落成全天（不替用户编一个时刻）。写入通道复用 `TaskViewActionRepository.scheduleTaskToDay`
   —— 它由 `addToToday`（推荐任务「+ 加入今天」）泛化而来，`addToToday` 只剩一层转调，
   原三条用例仍是绿的，这就是这次泛化没改行为的对照。
5. **成功不弹提示、失败在侧栏所在脚手架上弹「安排到「今天」失败」**，与清单行/标签行一致。

## 已知偏差（本轮不修，另开单）

`scheduleTaskToDay` 只挪 `dueAt`，**不动 `startAt`/`endAt`**。于是「有起止时段的任务」被拖到
「今天」后，截止日在今天、时段仍在原日。这不是本面新造的口径：同一份仓库里
`moveCalendarTask`（`:49` 那一面）与 `addToToday` 都是这个行为，且
`test/task_view_action_repository_test.dart`「日历拖拽改期只更新截止时间」把这条约定钉着；
本轮只是让第三条入口也走这条路。修法要一次覆盖三处（含跨 DST 的时段整体平移），
属产品口径 ⇒ 已开单跟踪，PR 正文与本格互链。

## 测试与判据（本轮实测，不写推测）

| 层 | 文件 | 用例数 |
| --- | --- | --- |
| 窗口/落点日与谓词对账 | `test/features/shell/smart_list_time_condition_test.dart` | 5 |
| 编排（skip/落点日/无日期/失败） | `test/features/shell/sidebar_smart_list_drop_test.dart`（第一组） | 5 |
| 真侧栏 + 真库 + 真手势 | `test/features/shell/sidebar_smart_list_drop_test.dart`（第二组） | 8 |
| 仓储 `scheduleTaskToDay` | `test/task_view_action_repository_test.dart`（新增一组） | 4 |

变异探针七发（P1–P6 + P3b）逐条红在期望用例上、还原后工作树 clean，结果与「哪一层被谁咬住」
记在 `tasks.md` T005。
