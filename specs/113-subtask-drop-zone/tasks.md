# 任务台账：清单行右下象限「拖动转子任务」（FL #590）

基准：分支 `feat/590-drag-to-subtask`，起点 FL `origin/develop` 的 `f1e710147fd5`（本轮开工时它是 tip）。

## 已完成

- [x] T001 一次性 widget 探针答掉阻塞问题（`ReorderableListView(buildDefaultDragHandles: false)` 的 child 里
      放自定义 `DragTarget<TodoTask>`，长按拖动收不收得到）。实测读数 `drops=[into-c:a] reorderCalls=[1->2] order=[a, b, c]`
      ⇒ 收得到，且行首手柄那条排序照旧 ⇒ 不必自建拖放层、不动 #14 面① 的实现。探针跑完即删，未入库。
- [x] T002 落点组件 `lib/features/task/task_subtask_drop.dart`（象限几何 + 闸门 + 同清单条件 + 失败可见）。
- [x] T003 清单页接线：两个 builder 分支（桌面 `ReorderableListView` 与移动/其它）都套上落点，
      页身份与可写闸门在 `_subtaskDropEnabled` 一处算，写库走 `_reparentAsSubtask` → `TaskRepository.reparent`。
- [x] T004 用例 18 条（`test/features/task/task_subtask_drag_test.dart`），全绿。
- [x] T005 变异探针 14 发，逐发归属到用例，见下表。
- [x] T006 门禁：`flutter analyze --no-pub` 0 失项；全量 `flutter test` 的失项只允许是
      `test/tooling/raw_error_text_gate_test.dart` 里 `desktop_update_io.dart` 那两条存量欠债，
      本轮自己引入的第三条（把异常对象插进文案）已改成 `describeError`；结果记在下面「门禁读数」。
- [x] T007 交叉验证并采纳其结论（拖出源形态差额不另立单、矩阵 #23 维持「部分」、异清单截走是真缺陷）。

## 未完成 / 留给下一轮

- [ ] T008 FL #591：拖「+」到任务下方偏右 ⇒ 在该任务下建子任务（原文 `:24`）。可与本面共用象限判定。
- [ ] T009 FL #585 第四处实例：落点接受判定吃拖出快照（`details.data`），且连续两刀无 in-flight 闸门。
      本轮**没有**顺手加闸门（形状该由那条单自己的红测决定），只在 PR 正文与本台账记账。
- [ ] T010 清单页只渲染顶层任务（`watchTopLevelByList`），子任务不作为行 ⇒ 拖成子任务后这一行从列表消失，
      且"父任务拖到自己后代"这条反向用例在新入口够不到。`specs/032` T013 已把"清单页子任务树"单列成另一件事
      （它同时记着改可见列表布局要先申请重录 9 张黄金基线）。本轮按够得到的形状做，不扩范围。

## 变异探针（十四发）

判据：改坏实现 ⇒ 期望哪几条红。每发跑 `flutter test --no-pub -r expanded test/features/task/task_subtask_drag_test.dart`，
跑完立刻从 `cp` 备份还原并 `git status --short` 复验工作树干净、重跑全绿。

| 号 | 改坏的地方 | 红了哪几条（简称） |
| --- | --- | --- |
| P1 | 象限 `0.5×0.5` 改成整行、`bottomRight` 改 `topLeft` | 「同一次拖、落在左上象限」1 条 |
| P2 | `if (!widget.enabled) return child` 改恒不返回 | 「智能清单里落点不存在」「只读清单没有落点」2 条 |
| P3 | 自引用判定 `id != task.id` 改恒真 | 「自己拖到自己」1 条 |
| P4 | `onAcceptWithDetails` 改成空函数 | 8 条（右下象限写库、入参顺序、窄屏、五层、不抢排序、同清单内层、可写清单、失败可见的前置） |
| P5 | 页面里 `reparent(dragged.id, parent.id)` 参数对调 | 6 条（入参顺序、写库、不抢排序前置、窄屏、五层、可写清单） |
| P6 | `error is StateError` 改 `error is TypeError` | **作废**：红在编译期（`TypeError` 没有 `message`），不是判据红 |
| P6b | `describeError(error)` 改成固定「操作失败」 | 「守卫原话被改写」「五层上限」2 条 |
| P7 | 摘掉候选态语义节点的 key | 「候选态读屏语义」1 条 |
| P8 | 落点 `hitTestBehavior` 改 `opaque` | 11 条（含「不抢点击」，证明确实是它把点击吞了） |
| P9 | 页面把 `enabled: widget.subtaskDropEnabled` 改恒真 | 「智能清单里落点不存在」「只读清单没有落点」2 条 |
| P10 | 同清单条件改成 `true ||`（来者不拒） | 「异清单任务落到右下带」「自己拖到自己」2 条 |
| P11 | 同清单条件取反（同清单也拒） | 10 条（本面正向用例全红，异清单那条也红——它期望的落点顺序被推翻） |
| P12 | 闸门里 `return list.writable` 改恒真 | 「只读清单没有落点」1 条 |
| P13 | 闸门里 `return list.writable` 改恒假 | 「同一张清单改回可写后落点出现」1 条 |
| P14 | 页面 `subtaskDropEnabled` 加 `width > 600` 条件 | 「320px + 1.3 倍字号」1 条 |

## 本轮自纠记录（错过三次，都留下读数）

1. **坐标带手算**：第一版在落点里用 `details.offset` 算"右下"，实测读数 `+3 -7`（十个用例七个红）——
   因为 SDK 那个字段是 `globalPosition - dragStartPoint`，不是全局指针（外部证据：本机 Flutter 3.44.8
   stable 的 drag target 实现里那句 `_lastOffset` 赋值；它不在本仓 git 索引里，所以不当仓内锚点用）。
   改成几何落点后同一批用例转绿；结论写进 `spec.md` 需求 1。
2. **`findRenderObject` 拿错尺寸**：State 的 context 向上找的是祖先 RenderObject（整张列表的滚动容器），
   拿它当行尺寸会把象限算成"整屏右下"。第一版的象限判因此恒不命中。
3. **两条用例的第一版各自测错**：窄屏那条没等 1.3 倍字号重排就量行矩形 ⇒ 落点掉到别行，读数
   `Expected: 'visual-task-today-primary' Actual: 'visual-task-today-secondary'`；五层那条只挂了四层
   （`depthOf` 是 0 基，四层正好五级、合法不拒）⇒ 量出来是"拖成功了"而不是被拒。
      都已改正，注释分别写在对应用例自己的上方（「320px + 1.3 倍字号」与「真仓储的五层上限」）。
4. **自己引入的门禁失项**：第一版把 `error.message` 插进文案，`raw_error_text_gate_test` 从 2 条失项变 3 条；
   改走 `describeError` 后回到那 2 条存量。

## 门禁读数（跑在最后一笔代码提交之后）

| 门禁 | 实际输出 |
| --- | --- |
| `flutter analyze --no-pub` | `No issues found!`，退出码 0 |
| `flutter test --no-pub`（不加 tag 过滤） | `+1834 ~26 -1: Some tests failed.` ⇒ 1834 通过、26 跳过、1 失 |
| 那 1 失是哪条 | `test/tooling/raw_error_text_gate_test.dart: lib 下没有任何文案在插异常原文` |
| 它的失项条数 | `Finding:` 行只有 2 条，都在 `lib/core/update/desktop_update_io.dart`（`:24`、`:34`），存量红由 FL **#569** 跟踪（本轮没并进去修）；本轮自己插进去的第 3 条已改走 `describeError` |
| 黄金基线 | `flutter test --no-pub test/visual/todo_workspace_golden_test.dart` ⇒ `+9: All tests passed!`（未带 `--update-goldens`） |
| 本轮新增用例 | `grep -c "testWidgets(" test/features/task/task_subtask_drag_test.dart` ⇒ 18 |
| 探针跑完的工作树 | `git status --short` ⇒ 空（十四发每发都从 `cp` 备份还原并复验） |

⚠️ 上面第 2 行与第 5 行是**两次不同的运行**：不加参数的全量 `flutter test` 里没有那 9 张黄金基线
（`tags: ['golden']` 被排除，全量日志里 `follows the workspace visual contract` 出现 0 次，复算：
`grep -c "follows the workspace visual contract" <全量日志>` ⇒ 0）⇒ "全量绿"这句话不含视觉契约，
视觉类改动要按第 5 行单独点名跑。这条口径本身记在 `spec.md` 需求 8。
