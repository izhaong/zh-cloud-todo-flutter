# 任务台账：清单页子任务树（FL #598，矩阵 #23）

基准：分支 `feat/598-list-subtask-tree`，起点 FL `origin/develop` 的 `7586c9d05809`。

## 已完成

- [x] T001 数据源：`lib/state/repositories/task_repository.dart` 加 `watchSubtasksByList` 与
      `watchAllSubtasks`（本清单/跨清单的子级流），顶层那两条一字未改；
      `lib/state/providers.dart` 加对应的 `subtasksByListProvider` 与 `allSubtasksStreamProvider`。
- [x] T002 树形铺行：`_ListBodyState._subtreeOf` 把"父 + 其展开出来的子树"铺进 `entries`，
      分组头之后先铺本组顶层行、每行后面紧跟它的子树 ⇒ 子行不会按自己的 dueAt 跑到别的组。
- [x] T003 展开/收起：箭头由页面那层的 `Set<String> _expandedSubtaskParentIds` 驱动（默认收起），
      位置按原文分两端（`TaskRow` 里 desktop 挂行尾、mobile 挂行首），desktop 那一头不等 hover 才出现。
- [x] T004 层级可见：`indentLevel` 按深度缩进（判据量行内最前那块，行表面本身铺满整宽度量不出缩进）。
- [x] T005 放置排序加"只接同一父级的兄弟"（`_acceptsPlacement` + `placementZone`）；
      行首手柄那条**不加**（扁平下标经归堆后等价于"落到本组最近的缝"，理由见 `spec.md` 需求 6）。
- [x] T006 用例 14 条（`test/features/task/task_list_subtask_tree_test.dart`），全绿；
      既有的 19 + 16 + 9 + 3 条一字未改仍过。
- [x] T007 黄金基线：先现量（6 张红、差异像素数记在下面）再重录，录后 9 张全绿。
- [x] T008 变异探针 9 发（T1–T9）逐发归属，见下表；含一发"第一版判据假绿"的自纠。
- [x] T009 门禁跑在最后一笔提交之后，读数见下。

## 未完成 / 留给下一轮

- [ ] T010 **展开态下的拖拽落点会飘**：T2 那发探针（强制全部展开）顺带量到
      FL #590 的「真仓储的五层上限」那条会红 —— 源行下面凭空多出五行为子行时，
      起手势前量好的落点坐标在拖拽过程中已不再指向那一行。默认收起把这个窗口关掉了，
      但"用户自己展开之后再拖"仍然存在，需要真机复核 + 决定是否在拖拽中重算落点。
- [ ] T011 展开态是本地态：切清单/重进页面会回到收起。要不要持久化（以及跨设备）原文没说，未裁定。
- [ ] T012 筛选与子行的组合只断了结构（父不在序列 ⇒ 子不冒出来），
      没断"父被筛掉但子命中筛选条件"这一格（嘀嗒原文没写，要做先定口径）。

## 变异探针（九发）

判据：改坏实现 ⇒ 期望哪几条用例红。每发跑
`flutter test --no-pub -r compact test/features/task/task_list_subtask_tree_test.dart test/features/task/task_subtask_drag_test.dart test/features/task/task_row_placement_drag_test.dart test/features/task/quick_add_drag_subtask_test.dart test/features/task/task_list_reorder_widget_test.dart`
（基线 61 条），跑完立刻还原、`git status --short` 复验干净（九发还原位全为 `restored=True`）。

| 号 | 改坏的地方 | 红了哪几条 |
| --- | --- | --- |
| T1 | 箭头恒不给（`_subtaskExpanderFor` 直接 return null） | 本面 12 条 —— 未红的只有「没有子级的行不给箭头」与「子行只挂在渲染出来的父行下面」，那两条断的都是「不该出现」，摘掉箭头不会让它们变 |
| T2 | 展开集合不判（当作永远已展开） | 「默认收起」「点箭头展开…再点收起」，**外加 FL #590 的「真仓储的五层上限」那条** —— 见 T010 |
| T3 | desktop 那一头不挂箭头（只留 mobile 的 leading） | 与 T1 同一批 12 条：桌面用例点不到箭头，展开类全断 |
| T4 | 不缩进（`indentLevel` 那档恒 0） | 「三层树：展开父再展开子，孙级出现且缩进更深」1 条 |
| T5 | 放置去掉"同一父级"那道条件（两处 `placementZone`） | 「展开后放置仍只在同一父级的兄弟之间」1 条 |
| T6 | 子行不紧贴父（`entries` 只铺顶层行） | 本面 10 条 —— 凡是要先展开才谈得上的用例都断 |
| T7 | 归堆不看 `parentTaskId`（子级流整条当成本父的孩子） | 55 条：本面全崩，且 #590/#591/#595 与行首手柄四条线一起崩 ⇒ 这一条判据是共用的地基 |
| T8 | 智能清单没有子级流（`listId == null` 那支给空表） | 「智能清单也有这棵树」1 条 |
| T9 | 只读清单把箭头挂到写操作闸门上（`!widget.subtaskDropEnabled` 就 return null） | 「只读清单里箭头照旧可用」+「智能清单也有这棵树」2 条 |

## 本轮自纠记录（错过一次，读数留着）

**T9 第一版是假绿的**：那条用例原本把"只读"种在**收集箱**上，而
`_subtaskDropEnabled` 对收集箱是"页身份先判真"（`kInboxListId` 早于 `writable` 返回 true），
于是"把箭头挂到 writable 上"这发变异在收集箱里根本不会红 —— 探针 0 红，
看着像"这条判据没咬住"，实际是**用例选错了清单**。
换到 `workList`（自建普通清单，`writable=false` 真的会关掉落点）并自己种一对父子之后，
T9 才把这条判红。复算：`grep -c "RED:" /tmp/probe296_b.log` 记的是当轮两发的红行数（14），
其中 T9 那两行含「只读清单里箭头照旧可用」。

顺带一条被 T2 揭出来的事实写在 T010 里，不当成本轮的缺陷修：
强制全展开会让 FL #590 那条五层上限用例红，因为源行下凭空多出五行子行、
起手势前量好的坐标在拖拽中已不指向目标行 —— 默认收起关掉了这个窗口，
但"用户展开后再拖"仍然存在。

## 门禁读数（跑在最后一笔代码提交 `f2f8ed18` 之后；台账这一笔只动 markdown）

| 门禁 | 实际输出 |
| --- | --- |
| `flutter analyze --no-fatal-infos` | `No issues found!`，退出码 0 |
| `flutter test --no-pub` | `01:30 +1874 ~26 -1: Some tests failed.` ⇒ 1874 通过、26 跳过、1 失 |
| 那 1 失的明细 | `test/tooling/raw_error_text_gate_test.dart: lib 下没有任何文案在插异常原文`，日志里 `Finding:` 行 = 2，都在 `lib/core/update/desktop_update_io.dart`（FL #569 存量红，本轮没有新增第 3 条） |
| 与上一轮对账 | 第 295 轮全量 1860 通过 → 本轮 1874，差 14 恰等于 `grep -c "testWidgets(" test/features/task/task_list_subtask_tree_test.dart` 的 14 |
| 黄金基线（重录前） | `flutter test --no-pub test/visual/todo_workspace_golden_test.dart` ⇒ 6 张红：wide-populated / wide-selected / wide-long-content 各 321px（0.02%）、tablet-list / mobile-list / mobile-min-long 各 3143px（0.40% / 0.95% / 1.09%）；compact-selected、wide-empty、mobile-detail 未变 |
| 黄金基线（重录后） | 同一命令 ⇒ `+9: All tests passed!`；`git diff --stat` 对 `test/goldens` ⇒ 6 个文件、每个 +120~+180 字节 |
| 重录的人工复核 | 读了重录后的 `mobile-list.png` 与 `wide-populated.png`：只有「准备项目周会材料」那一行多出一枚箭头（mobile 在勾选框左侧、desktop 在日期右侧），行高、其余行、侧栏与底部导航均未变 |
| 台账判据 | `python3 tool/check_spec_selfscan.py specs/116-list-subtask-tree/spec.md` 与 `...tasks.md` ⇒ 失项 0 条 |
