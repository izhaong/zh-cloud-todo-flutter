# 045 任务表 — 看板卡片「分配给」与团队看板三面判定（Issue #317）

分支 `feat/317-kanban-card-assign`，实现提交 `05d62fe`，**未合并** ⇒ 矩阵 #15 不翻状态。

## 已证实（只勾真满足的）

- [x] `:175`「在看板视图右键任务，选择「分配给」」有入口了，且**真的走到指派页**：
      `kanban_card_assign_menu_test.dart` 第 1/3 条跑绿（右键出菜单；真清单任务 + 清单都有 serverId ⇒ `find.byType(TaskAssignPage)` 命中）。
- [x] 前置条件不满足时**可见且不写库**：第 2 条（任务未同步 ⇒ 「任务尚未同步，无法指派」，
      且 `updatedAt`/`assigneeUserId`/`assigneeUserName` 逐字段与操作前相同）、
      第 4 条（收集箱 ⇒ 「清单尚未同步，无法选择执行人」且不 push）。
- [x] `:188` 判定=可达，**有用例**（不是我读码）：第 5 条 —— 看板卡片左键 ⇒ 详情里 `tooltip: '协作（指派/评论/成员）'` 命中
      ⇒ 协作 Sheet 里「查看/添加评论」与「指派执行人」都在。
- [x] `:198` 判定=可达（形态不同，spec 已写明差异）：第 6 条 —— 同一详情里滚到「任务动态」这一节，
      未同步时读到「任务同步后可查看动态」。
- [x] 详情页「指派执行人」与看板右键共用同一个函数（`task_assign_action.dart`），行为与原实现一致：
      提示文案逐字沿用，只是从 `task_detail_pane.dart` 的 `if (choice == 'assign')` 分支里抽出来。
- [x] 顺带撞出来的既有缺陷已立 **Issue #318**（收集箱任务得到「清单尚未同步」这句误导性文案），
      有可达链 + 用例证据；本轮不改（不顺手重构清单侧既有路径）。

## 四件套（新增界面=卡片右键菜单）

| 件 | 实测方式 | 读数 |
| -- | -------- | ---- |
| 320px + 1.3 倍字号 | `MaterialApp.builder` 上包 `MediaQuery`（菜单是 root Overlay 的路由，挂 `home` 到不了），物理宽 320 | 第 7 条：`takeException()` 为 null 且「分配给」在屏上；绿 |
| 独立读屏语义 | `tester.ensureSemantics()` 后读该菜单项 | 第 7 条：`getSemantics(find.text('分配给')).label` 含「分配给」；绿 |
| 失败保留已加载数据 | 三个前置分支只 `showSnackBar`，不碰仓储 | 第 2 条逐字段比对 + 第 4 条 `find.byType(TaskAssignPage)` findsNothing；绿 |
| 过期响应不覆盖新响应 | 菜单只交出被右键条目自身（`data.tasks[i]`），视图不持有列表状态 | 结构判据（无异步读回旧对象的路径）；未做成用例 ⇒ 记在下面「仍缺」 |

## 六道门禁（全部跑在已提交终态 `05d62fe` 的字节上）

日志 `/tmp/g58/gates.log`（首行含 `head=` 与跑前 `git status --porcelain`，末行含 `pr_files` 与跑后状态）。

| 门禁 | 命令 | 读数 | rc |
| ---- | ---- | ---- | -- |
| 1 | `git diff --check HEAD~1 HEAD` | 无空白错误 | 0 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 4 个 dart 文件>` | `Formatted 4 files (0 changed)`（`count=4` 与本轮显式文件数一致，不是 zsh 假绿那种 `Formatted no files`） | 0 |
| 3 | `flutter analyze` | `No issues found!` | 0 |
| 4 | `flutter test --tags golden` | `00:04 +9` 基线 9 张，**一张未重录** | 0 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:28 +905 ~26` | 0 |
| 6 | `flutter build web --release --dart-define=…todo-test… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0 |

跑完 `status_after_gates=[]`；`pr_files` 共 5 个（4 个代码/用例 + 1 个 spec.md），**`pubspec.lock` 不在里面**。

**用例数可加减对上**：单独把新用例文件移出后重跑全量 = `02:25 +898 ~26`（日志 `/tmp/g58/baseline.txt`），
`898 + 7 = 905` ⇒ 本 PR 净增 7 条，没有用例被顺带删掉或跳过。

## 反向探针（每条断言都要能红，否则不算证据）

| # | 探针改法 | 期望 | 实际读数 |
| - | -------- | ---- | -------- |
| P1 | 摘掉 `KanbanView.build` 里 `onAssignCard:` 的接线（`/tmp/g57/p1.txt`） | 依赖菜单的 5 条红，两条判定用例不受影响 | `5` 条 `[E]`，且第 5/6 条（:188/:198 判定）仍绿 ⇒ 菜单确实由这条接线驱动；`cmp -s` 确认还原 |
| P3b | 把「任务尚未同步，无法指派」的 `Text` 换成空串（`/tmp/g57/p3b.txt`） | 第 2 条红 | 恰好第 2 条 `[E]`；`cmp -s` 确认还原 |
| P4 | 菜单文案改成自创的「指派给」（`/tmp/g57/p4.txt`） | 依赖文案的 5 条红 | `5` 条 `[E]`；`cmp -s` 确认还原 |
| P3（作废） | 想摘掉 `if (taskServerId == null) { … return; }` 整块 | — | **没做成反向探针**：删掉后编译就红（`loading … [E]`，`/tmp/g57/p3.txt` 的 rc=1 是编译失败，不是行为红）—— 那个 `if` 同时承担 `int? → int` 的收窄。改判据交给 P3b。 |

## 仍缺（不谎称完成）

- 「过期响应不覆盖新响应」这一件只有结构判据，没有用例（该菜单是同步交出对象、无异步回读，写不出真实的旧响应路径）。
- 卡片右键菜单只有「分配给」一项；帮助中心没写看板右键的完整菜单，所以不补别的项，也不声称"右键菜单已复刻"。
- `:217`-`:219`（「排序」里把「分组」改为「自定义」才可管理分组）仍未实现 —— 属 specs/044 / PR !314 那条线。
- 收集箱指派文案（#318）。
- 矩阵 #15 的行内证据要等本 PR 合并后才能写 SHA；回写内容挂 izhaong/zh-cloud-docs Issue #104。

## 下一轮入口

1. 判 `:217`-`:219` 的「排序 → 分组改为自定义」这条前提：它属看板列绑分组的前置，先定"做/不做/不可达"再谈 #15 升「有」。
2. #318（收集箱指派的准确文案）——先查嘀嗒收集箱能否指派，再动代码。
3. specs/044 撤证里那条「端到端『确认删除后列真的消失』用例红因未定位」仍待补。
