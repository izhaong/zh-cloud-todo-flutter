# 规格：清单行右下象限「拖动转子任务」（FL #590，矩阵 #23 mobile 方式二 / desktop 方式三）

## 判据源（嘀嗒原文逐字，zh-cloud-docs 镜像）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md`
（该页是 `:::::tabContainer [mobile|desktop]` 两个 tab，同一件事在两处各有一句）：

- mobile tab `:20`「方式二：通过拖动将现有的任务转化成子任务。」
- desktop tab `:60-:61`「方式三：通过拖动将现有的任务转化成子任务。
  将光标覆盖在一个任务上，按住任务前的图标拖动到另一个任务**右下方**即可快速转化为子任务。」
- 两个 tab 共用的 `:28`「这一功能在「今天」、「最近七天」等智能清单中不可用，
  只可以在「收集箱」以及自己创建的普通清单中可用。」

同一对手势还记在矩阵 #14 面⑥ 与 #87 `:39`「快速形成主子任务关系」——按矩阵口径不重复计账，
本规格是那三处的实现单；矩阵 #23 的另一半（拖「+」建子任务，原文 `:24`）在 FL #591，未做。

## 形态差额（写在这里，不在矩阵格里藏）

嘀嗒 desktop `:61` 说的拖出源是「**任务前的图标**」，本实现沿用清单行已有的整行
`LongPressDraggable<TodoTask>`（并列日历改期那一面用的就是它，`lib/features/task/tasks_by_list_page.dart`
的 `_CalendarDragSource`）。裁定过程与理由：

- 给图标单开第二条拖拽通道 ⇒ 把嘀嗒的"一个手势、落点决定结果"改成"两个手势"，形态更不一致，
  上一轮施工图（#590 留言 13763 第 3 条）已明确否掉那条走法。
- 交叉验证（`cursor-agent --mode=ask`）推荐只做"右下象限＝转子任务"这一半，
  不顺手把"左半＝排序插入"也并进同一手势 —— 那会改掉 `specs/065` 已验收的"整行长按只改期、不动顺序"，
  并把 #14 面① 的三条既有用例的手感换掉。它的结论是**矩阵 #23 因此维持「部分」**，
  差额写进证据格而不另立单。本台账与 PR 正文都按这个口径写。

⇒ 结论：本面交付"落到另一行右下象限 ⇒ 转子任务"，拖出源仍是整行长按；差额两条（拖出源形态、
左半落点不改顺序）都记在本格，不声称与嘀嗒逐字同形。

## 需求与裁定

1. **「右下方」用几何实现，不用坐标手算。** 命中区是行自身的右下 `0.5×0.5` 象限
   （`Positioned.fill` + `FractionallySizedBox(widthFactor: 0.5, heightFactor: 0.5,
   alignment: Alignment.bottomRight)`，见 `lib/features/task/task_subtask_drop.dart`）。
   这不是省事：本机 SDK（Flutter 3.44.8 stable）里 `DragTargetDetails.offset` 取的是 drag target
   实现内部那句 `_lastOffset = globalPosition - dragStartPoint`，源没设 `dragAnchorStrategy` 时
   `dragStartPoint` 是 `centerDragAnchorStrategy` 的返回值而不是全局指针位置 ⇒
   拿它当全局坐标算象限必错。**这是外部证据（SDK 源码，不在本仓 git 索引里，故不写成仓内锚点）**，
   本仓内的证据是第一版实测读数：那条实现跑全文件是 `+3 -7`（十个用例里七个红），
   换成几何落点后同一批用例转绿。
2. **命中区扩不扩得开要能测。** 「同一次拖、落在左上象限：不建立父子关系」这条就是象限判据的活证据；
   变异探针 P1 把象限扩成整行，只有这一条红（见 `tasks.md`）。
3. **只加落点，不加第二个拖出源。** 沿用清单行已有的 `LongPressDraggable<TodoTask>`；
   「两个入口并存」用例钉住拖出源键 `todo-list-task-drag-<id>` 与行首 hover 才出现的「拖动排序」手柄都在。
4. **落点只走 `TaskRepository.reparent`。** 自引用、防成环、五层上限三道守卫都在它里面
   （`_reparentWithinTransaction`），这里不复制判定 —— 复制一份就会漂。「落点走 reparent 那条带守卫的通道」
   用例钉的是入参顺序 `(拖动项, 目标父)`，不许另开一条只改 `parentTaskId` 的裸 update。
5. **闸门是两半，不是一句「是不是清单页」。** `:28` 前半句＝智能清单不可用（页身份用现成的
   `_viewPreferenceSourceKey`，`list:` 前缀才开），后半句「自己创建的普通清单」＝**可写**清单：
   订阅/共享来的清单 `TodoLists.writable` 为 false，仓储那条通道会抛「当前清单为只读，无法修改任务」
   （`lib/state/repositories/task_repository.dart:653`），所以那一类清单上这一行根本不该是落点，
   而不是拖上去再报错。两半各有正反用例（P2/P9/P12/P13 分别咬）。
6. **同清单才接，别把外层落点截走。** 清单页的列表体外层还套着 `TaskListDropTarget`
   （嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》`:55`「任务会从原所属清单迁移到当前查看的清单中」），
   它吃的也是 `TodoTask`。内层来者不拒 ⇒ 从日历拖来的异清单任务被右下带截走，那一面当场失效。
   这条是交叉验证提出、本机**先跑出红再补的条件**（补之前「异清单任务落到右下带」用例为红）。
7. **失败必须看得见，且走 `describeError`。** 直接把异常对象插进文案会被本仓门禁
   `test/tooling/raw_error_text_gate_test.dart` 判成失项（第一版就被判过，见 `tasks.md` 的自纠记录）。
8. **新视觉只在拖拽候选态出现。** 静止态一行都不变色 ⇒ 九张黄金基线一张都不用重录
   （`specs/112-subtask-context-and-consecutive` 与 `specs/032` T013 都记着"改可见列表布局需先申请重录"
   这条前置）。**这句是量出来的**：`flutter test --no-pub test/visual/todo_workspace_golden_test.dart`
   ⇒ `+9: All tests passed!`，没带 `--update-goldens`，基线字节一个字没动。
   ⚠️ 顺带记一条测量口径的坑：这 9 条挂着 `tags: ['golden']`，**不在不加参数的全量 `flutter test` 里跑**
   （本轮全量日志里 `follows the workspace visual contract` 出现 0 次；`ci.yml:39` 也是
   `--exclude-tags 'golden || performance'`）⇒ 只看"全量绿"等于没看过黄金基线，
   落点这类视觉改动必须单独点名跑一遍。

## 交付检查四件套（逐格落，不许写"本面不适用"）

| 项 | 结论 | 依据 |
| --- | --- | --- |
| ① 320px + 1.3 倍字号 | **满足** | 用例「320px + 1.3 倍字号：象限按行自身的比例算，拖动照样成立」真跑一次拖放并回读库；命中区是行自身比例，没有固定像素。变异探针 P14（窄屏不给落点）只让这一条红 |
| ② 独立读屏语义 | **满足（候选态）** | 静止态不挂标签（否则每行都是「成为子任务」＝噪声）；悬停时语义挂在带 key 的节点自己身上，用例读 `getSemantics(zoneKey).label`，不用全树 `bySemanticsLabel` |
| ③ 失败保留数据 | **满足** | 用例「真仓储的五层上限从新入口被触发时：提示看得见且一个字节都不写」用真仓储真守卫触发，断言提示上屏 + `parentTaskId` 未变 + 该任务的同步队列条数前后相等 |
| ④ 过期响应不覆盖新响应 | **未满足** | 落点的接受判定吃的是**拖出那一刻的任务快照**（`details.data` 的 `listId`/`id`），与 FL #585 记的侧栏两处是同一形状，本轮是**第四处实例**；另外连续两次拖同一任务没有 in-flight 闸门。按上一轮定的口径：本 PR 不顺手加闸门（加哪种形状该由 #585 自己的红测决定），差额写在 PR 正文与本台账，指向 FL #585 |

## 测试与判据（本轮实测）

| 层 | 文件 | 用例数 |
| --- | --- | --- |
| 真页面 + 真仓储的拖放落点（含窄屏、闸门、嵌套落点、失败可见） | `test/features/task/task_subtask_drag_test.dart` | 18 |
| 既有排序（本轮在每个行外面套了一层 Stack，必须一字不改地过） | `test/features/task/task_list_reorder_widget_test.dart` | 3 |

复算命令（与上表同一行口径，别抄数）：
`grep -c "testWidgets(" test/features/task/task_subtask_drag_test.dart` ⇒ 18；
`grep -c "testWidgets(" test/features/task/task_list_reorder_widget_test.dart` ⇒ 3。

结构性断言的尺也换过一次：全树 `find.byType(DragTarget<TodoTask>)` 会把页级
`TaskListDropTarget` 一起数进来（清单页恒在），量不出"这一行是不是落点" ⇒ 台账与用例统一用
按 `TaskSubtaskDropTarget` 切作用域的 `_rowDropZones()`。

变异探针十四发（P1、P2、P3、P4、P5、P6b、P7、P8、P9、P10、P11、P12、P13、P14）逐发红在期望用例上，
结果与归属记在 `tasks.md`；其中 P6 第一发（`error is StateError` 改成 `error is TypeError`）
红在编译期而不是判据上，已作废重跑成 P6b。
