# 执行记录：任务行「滑动操作」（FL #601，矩阵 #14 面⑦）

## 落地的文件

| 文件 | 干什么 |
| --- | --- |
| `lib/core/task/task_swipe_preferences.dart` | 档位枚举、两侧默认档、一侧上限、宽容解码、按内容相等 |
| `lib/state/repositories/task_swipe_preference_repository.dart` | 读写档位 + `view_preference` 出箱 |
| `lib/state/providers.dart` | 仓储与档位流两个 provider、`resolveTaskSwipePreferences` 三态读法 |
| `lib/features/task/widgets/task_swipe_reveal.dart` | 双向"短滑露出 + 点击执行"的行组件 |
| `lib/features/task/widgets/task_row_host.dart` | 换掉 `Dismissible`，五档接既有通道，移动目标的选单 |
| `lib/state/repositories/task_repository.dart` | 新增 `moveToList`（子树 + 清分组 + 目标可写） |
| `lib/features/settings/task_swipe_settings_page.dart` | 「设置 → 任务 → 滑动操作」自定义页 |
| `lib/features/settings/settings_route.dart` | 「任务」分组里那颗入口 |

## 测试与结果

`flutter test --no-pub` 分文件跑，四条全绿：

- `test/task_swipe_preference_repository_test.dart` ⇒ 10 条
- `test/task_repository_move_to_list_test.dart` ⇒ 6 条
- `test/features/task/task_row_swipe_test.dart` ⇒ 21 条
- `test/features/settings/task_swipe_settings_test.dart` ⇒ 8 条

既有用例改了两条，各因本次改动而起：

- `test/features/task/task_focus_entry_test.dart` 移动端那一腿（详见 `spec.md` 的"有意差异"）
- `test/native_entry_page_test.dart` 设置页那一腿：多了一行设置项之后
  `ensureVisible` 实测滚不进视口（tap 目标停在 y=662.7 而视口高 600），改成 `dragUntilVisible`
  并补一条"真进了视口"的正对照

黄金基线：`test/visual/todo_workspace_golden_test.dart` ⇒ 18 条全绿，0 张重录。

## 变异探针（每处只改一个判据，要求对应测试必须红）

驱动脚本 `/tmp/probe_round297.py`（逐条：备份 → 断言 needle 命中 1 次 → 改 → 跑 → 还原 → `cmp` 校还原）。

| 探针 | 改哪 | 结果 |
| --- | --- | --- |
| P1 | 关闭态也画动作带（去掉 `value > 0` 那道条件） | 红：`mobile-list` 等黄金基线挂 |
| P2 | 行宿主两侧档位对调 | 红：方向与半区两条用例挂 |
| P3 | `moveToList` 不带子树 | 红：仓储与行级各一条挂 |
| P4 | `moveToList` 去掉目标可写校验 | 红：只读清单那条挂 |
| P5 | 露出态不挂 barrier | 红：「点行体只收起」挂 |
| P6 | 完成档文案恒为「完成」 | 红：「取消完成」那条挂 |
| P7 | 设置页不挡第四个 | 红：「第四个按不动」挂 |
| P8 | 仓储不认 sync pull 的再包装形态 | 红：第二设备那条挂 |

## 实现期自纠（都是量出来的，不是想到的）

1. **关闭态把按钮透出来。** 第一版把动作带常驻在 `Stack` 里，靠行体盖住 ——
   但行体底色是透明的，于是静止态每一行都露着五颗钮。黄金基线一次红了 47.33%（155781px）。
   改成关闭态根本不建那两条带，顺带把 barrier 也搬进同一个 `AnimatedBuilder`
   （写在 `build` 返回值上的 barrier 永远进不了树：拖动只有控制器在变，`build` 不重跑，
   于是"点行体收起"那条用例先是绿的假象 —— 它绿在按钮根本没被盖住）。
2. **`data class` 直接喂 `write()` 会丢 null 字段。** `moveToList` 第一版写
   `row.copyWith(sectionId: const Value(null))` 再 `.write(next)`，分组没被清掉
   （drift 按 `nullToAbsent` 把 null 当成"没改"）。改成显式 `TodoTasksCompanion` 只写那三列。
   这条是红测先发现的，不是读文档读出来的。
3. **露出态下行体的几何中心已经压在按钮带上。** 两条用例（换侧、点行体收起）先都写成
   `tester.drag/tap(find.byKey(task-row-surface-*))`，起手势打在按钮上 ⇒ 位移不生效。
   改成从行的未被遮住那一段起手（`_swipe` 里按方向选起点）。
4. **文案断言要收到"那颗钮自己身上"。** `find.text('取消完成')` 命中 2 处（行体别处也有），
   改成 `find.descendant(of: byKey(那颗钮), matching: byText(...))`。
5. **读屏名被念两遍。** `Semantics(label:)` 里那颗 `Text` 自己又报一份，
   合成 `"移动任务\n移动任务"` ⇒ 内层套 `ExcludeSemantics`。
6. **设置页「恢复默认」被确认条盖住。** 390x844 下列表滚到底时钮占 y=772..820、
   确认条占 y=796..844 ⇒ 重叠。先量出重叠再改（把 `ListView` 底部内边距 24 提到 88），
   并留一条按坐标断的用例；反向验证：把内边距改回 24，那条用例当场红。
7. **一次勾选一串确认条。** 改为 `hideCurrentSnackBar()` 后再 `showSnackBar`，
   用例断"连点两次只剩一条"。

## FL #600（同一行的另一面）本轮只量不修

第 296 轮立的那条说的是"拖动途中插入行会让预量坐标失效"。本轮的滑动组件
**不新增也不删除任何行**（只平移行体），所以那条症状与本轮无交集：
`test/features/task/task_list_subtask_tree_test.dart` 与
`test/features/task/task_row_placement_drag_test.dart` 在全量里照旧绿，FL #600 仍留单。

## 后续（另立，不在本 PR 顺手做）

- 「移动到清单」那张表里四颗死按钮（删除/移动到清单/设置提醒/编辑标签 只 pop）
  —— 属于那张表自己的面，FL #601 评论里记着。
- **三条既有"换清单"通道应并到 `moveToList`**：详情面板的清单切换
  （`task_detail_pane.dart:1149` 那条 `update(listId:)`，且不带 `clearSectionId`）、
  侧栏拖放（`sidebar_task_drop.dart:183`）、`list_drop_target.dart:107`
  —— 前两条清了分组/没清不一致，三条都不校验目标可写、都不带子树。
  并完之后"选目标清单"那张表也该合成一张（`task_detail_pane.dart` 的 `_TaskListPicker`
  与本轮行宿主里那张是同一件事的两个副本）。
- 移动端「移动到分组」入口随形状撤掉后没有替代（镜像里没有这一档）。
