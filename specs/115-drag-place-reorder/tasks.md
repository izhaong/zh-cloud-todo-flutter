# 任务台账：长按放置即排序（FL #595，矩阵 #23 #14）

基准：分支 `feat/595-drag-place-reorder`，起点 FL `origin/develop` 的 `27e9c9a4efa1`。

## 已完成

- [x] T001 落点几何：`lib/features/task/task_subtask_drop.dart` 在原有右下象限之外加两块
      —— 上半条（`1 × 0.5`，`topCenter`）与下半左（`0.5 × 0.5`，`bottomLeft`），
      三块共用 `_acceptsTask`（同清单、非自己）与外层 `enabled` 闸门。
- [x] T002 语义裁定（FL #595 第 1 条要的那件事）：上半＝排到该行之前、下半左＝排到该行之后，
      右下＝转子任务不动；写进 `spec.md` 的裁定表与交叉验证处置。
- [x] T003 页面接线：`_ListBodyState._placeTask` 按**当前可见顺序**算插入位，
      与行首手柄那条 `onReorder` 一起收进同一处 `_commitOrder`（乐观改序 → 提交 → 回滚 + 一条提示）。
- [x] T004 闸门三处：智能清单与有分组走既有的 `onTasksReordered == null`，批量选择态走
      `widget.batchSelectionActive`（与手柄的 `reorderIndex: null` 同形状）——**回调不接就不建落点**。
- [x] T005 候选态画得不一样：放置那两块只在插入边画线、转子任务那块保持描边
      （交叉验证第 2 条，逐条处置见 `spec.md`）。
- [x] T006 用例 16 条（`test/features/task/task_row_placement_drag_test.dart`），全绿；
      既有的 19 + 9 + 3 条（`task_subtask_drag_test.dart`、`quick_add_drag_subtask_test.dart`、
      `task_list_reorder_widget_test.dart`）一字未改仍过 —— 只有 #590 的
      「同一次拖、落在上半格：不建立父子关系（各格管各的）」按新语义改了后半句断言。
- [x] T007 变异探针 12 发（P1–P12）逐发归属，见下表；其中一发是不等价变异，如实记下原因。
- [x] T008 门禁跑在最后一笔代码提交之后，读数见下。

## 未完成 / 留给下一轮

- [ ] T009 清单页子任务树（`specs/032` T013）：不做则"拖成子任务后这一行从列表消失"，
      矩阵 #23 仍「部分」就剩这一个理由。
- [ ] T010 交叉验证提的两条歧义面（松手点恰好落在邻行上半的日历改期、窄列表长按放置的手感）
      只有 widget 测的形状证据，没有真机读数。
- [ ] T011 分组视图下的放置语义（现在整块禁用）要先定"插到哪个容器"。

## 变异探针（十二发）

判据：改坏实现 ⇒ 期望哪几条用例红。每发跑
`flutter test --no-pub -r compact test/features/task/task_row_placement_drag_test.dart test/features/task/task_subtask_drag_test.dart test/features/task/quick_add_drag_subtask_test.dart test/features/task/task_list_reorder_widget_test.dart`
（基线 47 条），跑完立刻还原并 `git status --short` 复验工作树干净 —— 十二发还原位均为 `restored=True`。

| 号 | 改坏的地方 | 红了哪几条 |
| --- | --- | --- |
| P1 | 上半格那块整块不建（`if (widget.onPlace != null)` 改恒假） | 上半＝之前、上半与左下各挂各的语义、三块画得不一样、收集箱两块都在、窄屏、回滚，加上 #590 的「同一次拖、落在上半格」——7 条 |
| P2 | 左下格的 `after` 传成 `false`（两块语义合成一块） | 「上半与左下是两块」+「拖到某行左下格＝排到该行之后」2 条 |
| P3 | 上半格 `heightFactor` 0.5→0.25（几何缩了） | 上半＝之前、语义、三块画得不一样、窄屏、回滚，加 #590 那条——6 条 |
| P9 | 左下格 `heightFactor` 0.5→0.25 | **0 条 —— 不等价变异**：`Rect.contains` 顶边算命中，落点中心 y=0.75h 正好压在缩高后的顶边上，所以照旧命中（对照 P10） |
| P10 | 左下格 `widthFactor` 0.5→0.25 | 缩宽后 x=0.25w 压在**右边**（右边不算命中）⇒「左下＝之后」「上半与左下是两块」「语义」「三块画得不一样」4 条 |
| P11 | 上半格高亮退回整圈描边 | 「三块的候选态画得不一样」1 条 |
| P12 | 左下格高亮退回整圈描边 | 「三块的候选态画得不一样」1 条 |
| P4 | `_acceptsTask` 去掉"同一张清单" | 本面「异清单任务不被放置落点截走」+ #590 同名那条——2 条（两个文件都红 ⇒ 三块确实共用一条接受条件） |
| P5 | `_acceptsTask` 去掉"不是自己" | 本面「拖到自己那一行」+ #590「自己拖到自己」2 条 |
| P6 | 页面两处都不接放置回调 | 上半＝之前、左下＝之后、两块各挂各的、三块画得不一样、收集箱两块都在、窄屏、回滚、#590 上半格 —— 8 条 |
| P7 | `_commitOrder` 失败不回滚（摘掉那段 `setState`） | 「排序保存失败要回滚视觉顺序并只给一条可见提示」1 条 |
| P8 | 批量态闸门摘掉（两处 `|| widget.batchSelectionActive`） | 「批量选择态下这两块落点不存在」1 条 |

P6 的红集里含「收集箱这两块落点都在」——这条是**正向对照**：智能清单与分组那两条只断 `findsNothing`，
没有它就可能变成恒过的判据。

## 本轮自纠记录（错过两次，读数留着）

**其一：拿悬停节点判闸门会恒过。** 第一版的闸门用例读 `beforeZoneKey(firstId)`，
而那个 key 挂在**候选态才建**的 `Semantics` 上——静止态本来就找不到，于是"智能清单没有落点"
是一条永远不会红的判据。改法：`DragTarget` 自己身上另挂恒在的 `beforeDropKey`/`afterDropKey`，
闸门用例改读这一对，并补「收集箱这两块落点都在」当正向对照（P6 证明这套对照真的会红）。

**其二：`ensureVisible` 会把另一头回收。** 第一版 `_dragBand` 只滚源行，然后量目标行 ——
ListView 懒建 ⇒ 目标行被滚出视口后根本不在树上，`ensureVisible(target)` 直接抛
`Bad state: No element`（窄屏与智能清单两条就是这么红的，读数与落点无关）。
改成"两行都必须在视口内且整条可见"再量（`_expectRowVisible`），用例改挑同一屏里的行。

顺带一条 SDK 口径（现量，不是猜的）：`Rect.contains` 对**顶边与左边算命中、对右边与底边不算** ——
这就是 P3/P10 会红而 P9 不会红的原因，也是落点中心取 `0.25h`/`0.75h` 这类"正好压线"的坐标时
必须知道的边界。

## 测试与判据

| 层 | 文件 | 用例数 |
| --- | --- | --- |
| 放置排序（三块语义、闸门四处、失败回滚、穿透、点击、描边、窄屏） | `test/features/task/task_row_placement_drag_test.dart` | 16 |
| FL #590 右下带（本面在每个行外又叠了一层落点，必须仍过） | `test/features/task/task_subtask_drag_test.dart` | 19 |
| FL #591 拖「+」建子任务 | `test/features/task/quick_add_drag_subtask_test.dart` | 9 |
| 行首手柄排序 | `test/features/task/task_list_reorder_widget_test.dart` | 3 |

复算命令：`grep -c "testWidgets(" test/features/task/task_row_placement_drag_test.dart` ⇒ 16；
`grep -c "testWidgets(" test/features/task/task_subtask_drag_test.dart` ⇒ 19；
`grep -c "testWidgets(" test/features/task/quick_add_drag_subtask_test.dart` ⇒ 9；
`grep -c "testWidgets(" test/features/task/task_list_reorder_widget_test.dart` ⇒ 3。

## 交叉验证

`cursor-agent --trust -p`（模型自报 HEAD `35627b5114c31c1f324d95fe3d3dfc6740d0d51f`，即本分支第一笔代码提交），
输出 4641 字节、结尾 `CROSSCHECK: DONE`。它提的每一点怎么写处置都记在 `spec.md`
「交叉验证与逐条处置」一节：描边区分与"点击/穿透各块都测"这两点成立、已改；
改成行缝那点不采纳，理由是与已合并的 FL #590/#591 那块右下象限冲突且会让两块候选态同时亮。

## 门禁读数（跑在最后一笔代码提交 `6d3a7191` 之后）

| 门禁 | 实际输出 |
| --- | --- |
| `flutter analyze --no-fatal-infos` | `No issues found!`，退出码 0 |
| `flutter test --no-pub` | `01:29 +1860 ~26 -1: Some tests failed.` ⇒ 1860 通过、26 跳过、1 失 |
| 那 1 失的明细 | `test/tooling/raw_error_text_gate_test.dart: lib 下没有任何文案在插异常原文`，日志里 `Finding:` 行 = 2，都在 `lib/core/update/desktop_update_io.dart`（FL #569 存量红，本轮没有新增第 3 条） |
| 黄金基线（单独点名跑） | `flutter test --no-pub test/visual/todo_workspace_golden_test.dart` ⇒ `+9: All tests passed!`，退出码 0，未带 `--update-goldens` |
| 与上一轮对账 | 第 294 轮全量是 1844 通过，本轮 1860 ⇒ 差 16，恰等于 `grep -c "testWidgets(" test/features/task/task_row_placement_drag_test.dart` 的 16 —— 没有别的用例被顺带改动或弄没 |
| 探针跑完的工作树 | `git status --short` ⇒ 空（十二发还原位全为 `restored=True`） |

⚠️ 「只剩 1 失」不等于门禁干净：那 1 失是 `raw_error_text_gate_test` 自己判红的存量两条，
读数要从 `Finding:` 行的条数取，别从"失项数"取。
