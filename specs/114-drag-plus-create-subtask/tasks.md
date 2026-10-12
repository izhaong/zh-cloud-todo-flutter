# 任务台账：拖「+」到任务下方偏右 ⇒ 在该任务下建子任务（FL #591）

基准：分支 `feat/591-drag-plus-to-subtask`，起点 FL `origin/develop` 的 `038496acbfd2`。

## 已完成

- [x] T001 「+」成为拖出源：`lib/features/shell/quick_add_bar.dart` 里 `MobileQuickAddButton` 的
      `FloatingActionButton` 套上 `Draggable<QuickAddSubtaskIntent>`（键 `todo-mobile-add-drag-source`，
      `Semantics(button: true)` 仍在最外层）。点击通道未动（既有两条 mobile 快速添加文件一字未改仍过）。
- [x] T002 落点：`TaskSubtaskDropTarget` 在同一块右下象限里嵌一层 `DragTarget<QuickAddSubtaskIntent>`，
      闸门（页身份 + 清单可写）与 `specs/113` 共用一份；新文案「在「X」下新建子任务」挂在带 key 的节点自己身上。
- [x] T003 页面接线：`_ListBody.onCreateSubtask` → 页面 `_createSubtaskByDrag` → `addSubtaskFlow(context, ref, parent)`
      （同一张 `TaskQuickAddSheet`，深度守卫仍只有一处）。
- [x] T004 用例 9 条（`test/features/task/quick_add_drag_subtask_test.dart`），全绿；
      上一面 19 条一字未改仍过。
- [x] T005 变异探针 7 发（Q1–Q7）逐发归属，见下表。
- [x] T006 门禁跑在最后一笔代码提交之后，读数见下。
- [x] T007 更正上一轮记错的差额，并把没做的那半独立立单：新读《01-列表视图.md》后，
      "拖出源形态"这条经实测不成立（就地改 `specs/113`），"长按放置即排序"这条成立 ⇒ FL #595。

## 未完成 / 留给下一轮

- [ ] T008 FL #595：长按任务拖到行的非右下区域 ⇒ 放置排序（《01-列表视图.md》:21/:23/:47）。
- [ ] T009 清单页子任务树（`specs/032` T013 单列的那件事）：不做则"拖成子任务后这一行从列表消失"，
      #23 那句「每一个层级的子任务在功能上都与普通任务相同」在清单页看不见 ⇒ 矩阵 #23 仍「部分」的两个理由之一。
- [ ] T010 连拖两次「+」开两张表这件事未量（`spec.md` 四件套 ④ 里写明）。

## 变异探针（七发）

判据：改坏实现 ⇒ 期望哪几条用例红。每发跑
`flutter test --no-pub -r expanded test/features/task/quick_add_drag_subtask_test.dart test/features/task/task_subtask_drag_test.dart`，
跑完立刻从 `cp` 备份还原、`git status --short` 复验工作树干净、重跑两个文件全绿。

| 号 | 改坏的地方 | 红了哪几条 |
| --- | --- | --- |
| Q1 | `if (widget.onCreateParent != null)` 改恒假（落点整块不建） | E2E 开表、候选态语义、入口抛错可见 —— 3 条 |
| Q2 | 象限扩成整行、`bottomRight` 改 `topLeft` | 「落在左上象限：不开表」+ 上一面「同一次拖、落在左上象限」2 条（证明两个落点真的共用同一块几何） |
| Q3 | `if (!widget.enabled) return child` 改恒不返回 | 智能清单、只读清单各 2 条（两个文件都红 ⇒ 闸门确实只有一份） |
| Q4 | 内层 `onWillAcceptWithDetails` 改恒假 | E2E 开表、候选态语义、入口抛错可见 —— 3 条 |
| Q5 | 内层 `Positioned.fill` 换成 `left/top/width/height = 0`（0×0 落点） | E2E 开表、候选态语义、入口抛错可见 —— 3 条（这条就是本轮踩到的那个 bug 的形状） |
| Q6 | 页面不传回调（`onCreateParent: null`） | E2E 开表、候选态语义 2 条（组件级"入口抛错"那条自带回调，故不红 —— 归属如实记下） |
| Q7 | 「+」加 `maxSimultaneousDrags: 0`（拖不起来） | E2E 开表 1 条（点击那两条仍绿 ⇒ 点与拖确实是两条通道） |

## 本轮自纠记录（错过一次，读数留着）

**0×0 的落点既不画高亮也进不了命中路径。** 第一版把内层 `DragTarget<QuickAddSubtaskIntent>`
与任务高亮都作为 `Stack` 的非 positioned 子节点写进去：`Stack` 给非 positioned 孩子的是 loose 约束，
两者按内容收缩成 0×0 ⇒ E2E 开表、候选态语义、入口抛错三条同时红
（`Expected: exactly one matching candidate / Actual: ... 0 widgets`）。
改成两条 `Positioned.fill` 后同批用例转绿；结论写进 `spec.md` 需求 5，Q5 就是它的反向证据。

顺带两条 SDK/工具口径（都是现量出来的，不是猜的）：
`find.byIdentifier` 在这个 SDK 的用例里不存在（编译红），仓内既有用法叫 `find.bySemanticsIdentifier`
（`test/features/shell/quick_add_bar_test.dart:53`）；读按钮标志位要 `getSemantics(f).getSemanticsData()`
而不是裸 `getSemantics(f).flagsCollection`（后者不合并子节点，注已在
`test/features/settings/timezone_preference_test.dart` 里）。

## 门禁读数（跑在最后一笔代码提交之后）

| 门禁 | 实际输出 |
| --- | --- |
| `flutter analyze --no-pub` | `No issues found!`，退出码 0 |
| `flutter test --no-pub` | `01:30 +1844 ~26 -1: Some tests failed.` ⇒ 1844 通过、26 跳过、1 失 |
| 那 1 失的明细 | `lib 下没有任何文案在插异常原文`，日志里 `Finding:` 行 = 2，都在 `lib/core/update/desktop_update_io.dart`（FL #569 存量红，本轮没有新增第 3 条） |
| 黄金基线（单独点名跑） | `flutter test --no-pub test/visual/todo_workspace_golden_test.dart` ⇒ `+9: All tests passed!`，退出码 0，未带 `--update-goldens` |
| 本轮新增用例 | `grep -c "testWidgets(" test/features/task/quick_add_drag_subtask_test.dart` ⇒ 9 |
| 探针跑完的工作树 | `git status --short` ⇒ 空 |

⚠️ 上表的 1844 是在最终树上重跑的读数；补测试之前也跑过一次全量，那次少几条用例、数对不上是必然，
所以别拿别处的汇总数当本轮读数。两次都只有那 1 条存量失项、`Finding:` 都是 2 行
（复算 `grep -c "Finding:" /tmp/fl594b-fulltest.log` 这类临时日志计数只在当轮有效，
要复跑就重跑 `flutter test --no-pub test/tooling/raw_error_text_gate_test.dart` 看它打出的条数）
—— 记下来是为了不让人把"只剩 1 失"读成"门禁干净"。
