# 045 任务表 — 看板卡片「分配给」与团队看板三面判定（Issue #317）

分支 `feat/317-kanban-card-assign`，实现 `05d62fe` + 复核修复 `37a06b0`，PR **!319**，**未合并** ⇒ 矩阵 #15 不翻状态。

## 已证实（只勾真满足的）

- [x] `:175`「在看板视图右键任务，选择「分配给」」有入口且**真的走到指派页**：用例第 1/3 条（右键出菜单；
      「工作」清单任务 + 清单都有 `serverId` ⇒ `find.byType(TaskAssignPage)` 命中，且两条"未同步"提示都不出现）。
- [x] 前置条件不满足时**可见且不写库**：第 2 条（任务未同步 ⇒ 提示 + **整行** `toJson()` 与操作前相等 + 发件箱行数不涨）、
      第 4 条（清单未同步 ⇒ 「清单尚未同步，无法选择执行人」且不 push）。第 4 条已由"拿收集箱当道具"改成用工作清单演真实情形（原因见 #318 撤单）。
- [x] `:188` 评论 = 可达（限"点开详情"这条路）：第 5 条钉住**内嵌态**那枚 `tooltip: '协作（指派/评论/成员）'` → 「查看/添加评论」。
      另有两条分支（`_buildPage` 窄屏 `Text('协作')`、宽屏 `tooltip: '协作'`）也调用同一个 hub，**但无用例** ⇒ spec 里没写成"三个分支都测过"。
- [x] `:198` 任务动态 = **部分**（第 1 轮复核把"可达"否掉后下调并补测）：
      第 6 条 = 未同步那一支（给「任务同步后可查看动态」）；第 7 条 = `serverId` 到位那一支（按 `_ActivitySection` 的 key `task-activities-…` 认，未同步那句改判 findsNothing）。
- [x] 详情页「指派执行人」与看板右键共用一个函数，且**原实现的陈旧响应守卫已补回**：
      `openTaskAssignAction(..., stillCurrent: () => mounted && widget.taskId == t.id)`（抽函数时我抄漏了这一句，见下面处置表 B3）。
- [x] `onAssignCard` 改必填，两处不可达判空删掉（复核 NIT：与 specs/044 撤证同形的"死防御分支"）。
- [x] #318 已**撤销关闭**：`sync_coordinator.dart:119-134` 缺行时插入 `id='inbox'`、`:145-158` 专门把它 upsert 进 outbox、
      `:839-856` 回写 serverId ⇒ "收集箱永远不会同步"是假的，我把 fixture 的形状当成了产品的形状。

## 六道门禁（全部跑在已提交终态 `37a06b0` 的字节上）

日志 `/tmp/g59/gates.log`（首行 `head=` + 跑前 `git status --porcelain`；末行 `pr_files` + 跑后状态）。

| 门禁 | 命令 | 读数 | rc |
| ---- | ---- | ---- | -- |
| 1 | `git diff --check HEAD~1 HEAD` | 无空白错误 | 0 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 4 个 dart 文件>` | `Formatted 4 files (0 changed)`，且日志里 `count=4` 与本轮显式文件数一致（不是 `Formatted no files` 那种假绿） | 0 |
| 3 | `flutter analyze` | `No issues found!` | 0 |
| 4 | `flutter test --tags golden` | `00:04 +9` 基线 9 张，**一张未重录** | 0 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:29 +906 ~26` | 0 |
| 6 | `flutter build web --release --dart-define=…todo-test… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0 |

跑完 `status_after_gates=[]`；`pr_files` 6 个（3 lib + 1 test + 2 specs），**`pubspec.lock` 不在里面**。

**用例数可加减核**：门禁 5 的 `+906` = 基线 `+898`（`/tmp/g58/baseline.txt`，移出本用例文件后重跑）
+ 本文件 **8** 条（第 1 轮复核时是 7 条，补了 `:198` 已同步那一支）⇒ 898 + 8 = 906，没有用例被顺带删掉或跳过。
（注：门禁日志是 21:10 那次跑的，`pr_files` 已含 `tasks.md`；上一版 `05d62fe` 的门禁读数在 `/tmp/g58/gates.log`，当时 PR 是 5 个文件。）

## 反向探针（每条断言都要能红，红不了就不算证据）

| # | 改法 | 期望 | 实际读数（日志） |
| - | ---- | ---- | ---------------- |
| P1 | 摘掉 `KanbanView.build` 里 `onAssignCard:` 接线 | 依赖菜单的 5 条红、两条判定用例仍绿 | `5` 条 `[E]`，第 5/6 条仍绿 ⇒ 菜单确由此接线驱动；`cmp -s` 确认还原。日志 `/tmp/g57/p1.txt` |
| P3b | 「任务尚未同步，无法指派」的 `Text` 换成空串 | 恰好第 2 条红 | 恰好第 2 条 `[E]`；`/tmp/g57/p3b.txt` |
| P4 | 菜单文案换成自创的「指派给」 | 依赖文案的 5 条红 | `5` 条 `[E]`；**重跑版** `/tmp/g57/p4b.txt` 里带上了它自己的 diff（原 `/tmp/g57/p4.txt` 与 P1 同 md5，分不清"没菜单"还是"换了字"，已被这条取代） |
| P3-real | 摘掉整块 `if (taskServerId == null) { … return; }` | 想看它是行为红还是编译红 | **编译红**：`task_assign_action.dart:40:23: Error: The argument type 'int?' can't be assigned to the parameter type 'int'`，计数停 `+0` ⇒ 这个 `if` 同时承担类型收窄，**不能当行为探针**。日志 `/tmp/g57/p3-real.txt` |
| P5 | 只删早退里那句 `return;`（保留提示） | 同上 | 同样编译红（`:43:23`），日志 `/tmp/g57/p5.txt` ⇒ 「未同步就不许 push」这件事由类型系统 + 第 3/4 条正反对照钉住，而不是靠这条探针 |

### 第 1 轮复核（`VERDICT: FAIL`，4 BLOCKING + 5 NIT）逐条处置

| # |  finding | 我的回源复验 | 处置 |
| - | -------- | ------------ | ---- |
| B1 | P3 行引用的 `/tmp/g57/p3.txt` 其实是一次**绿跑**（与 `green5.txt` 同 md5） | 成立。那次是 python 断言没匹配上、文件没改动就跑的测试，我却把它写成"编译红的证据" | 重跑 P3-real 与 P5 两份真日志并按实际读数改写这张表；把"编译红不算行为红"这条判据写明 |
| B2 | #318 的根因（收集箱永远不会同步）不成立 | 成立。复核给的 `sync_coordinator.dart:119-134`/`:145-158`/`:839-856`/`:1477-1497` 我逐条 `sed` 看过，确实是为"给收集箱拿 serverId"写的 | #318 撤单留言 + 关闭；spec 的缺陷段改成撤证；用例第 4 条换成工作清单演真实的"本地清单未同步" |
| B3 | "行为与原实现一致"不成立：抽函数时丢了 `if (!mounted || widget.taskId != t.id) return;` | 成立。`git diff` 的删除行里有这一句，而我的新函数只有 `context.mounted`；同函数的评论/成员分支仍留着 | 加 `stillCurrent` 回调并让详情页传回原判断；spec 取舍 2 改成"我说过头了 + 怎么补的" |
| B4 | `:198` 判"可达"夸大：用例走的是永远不构建 `_ActivitySection` 那一支 | 成立。`grep _ActivitySection` 全仓只在详情装配里出现一次，`test/activity_repository_test.dart` 是纯仓储测 | 判定下调为「部分」，补第 7 条用例钉住已同步那一支，spec/PR 文案同步改 |
| N1 | spec 里的用例编号与实际顺序不符 | 成立（我拆分成 8 条后没回头改编号） | spec 改引编号 + 用例名，并显式标"行号以本分支为基准" |
| N2 | `onAssignCard` 的可空 + 两处判空是不可达的死形状 | 成立：`_KanbanColumn` 私有、全仓仅一处构造且传无条件闭包 | 改必填、删判空（正是我在 specs/044 批评过的形状） |
| N3 | 日志说 5 个文件而 PR 现在 6 个 | 成立（门禁跑在 `05d62fe`，其后 docs 提交加了 `tasks.md`） | 本轮门禁重跑到 `37a06b0`，`pr_files` 6 项自证 |
| N4 | 「一个字节都没改」强于断言（只比 3 个字段、没看发件箱） | 成立；另「请先登录」那一支确实无用例 | 升级为整行 `toJson()` 比对 + 发件箱行数不涨；「请先登录」把"造不出这个状态"的原因写进 spec 当作结构缺口，不假装测过 |
| N5 | `find.text('任务动态')` 用 `findsWidgets` 偏松 | 成立：全 lib 只有两处该字样，另一处是「暂无任务动态」 | 改 `findsOneWidget`（并靠配对的未同步说明 findsOneWidget 保证不是恒真） |
| 驳回 | 我的自疑点 2（`:188` 被 fixture 特殊化） | **复核驳回我，我复验后接受**：长 tooltip 全文件只有 1 处（内嵌态），但 `_buildPage` 窄屏/宽屏各有一个入口（`Text('协作')` / `tooltip: '协作'`），三条分支都到得了 hub | 不改变判定；按复核的残留 NIT 在 spec 写明"用例只钉住内嵌态那串字，独立页标签是「协作」" |

## 仍缺（不谎称完成）

- `:188` 的独立页/窄屏两个入口没有用例；`:198` 的 `_ActivitySection` 内部"拉到动态 ⇒ 渲染列表"这一段仍无 UI 用例 ⇒ 这一格判「部分」。
- 「过期响应不覆盖新响应」：看板书这条路不跨 await，守卫只存在于详情页那条；`stillCurrent` 本身**没有独立用例**（要造"Sheet 开着时切任务"的时序）。
- 「请先登录」分支无用例（造不出"看得见卡片但库为 null"的状态）。
- 卡片右键菜单只有「分配给」一项；帮助中心没写看板右键的完整菜单，不补别的项，也不声称"右键菜单已复刻"。
- `:217`-`:219`「排序里把分组改成自定义」的前提仍未实现（specs/044 / PR !314 那条线）。
- 矩阵 #15 的行内证据要等本 PR 合并后才能写 SHA；回写内容挂在 izhaong/zh-cloud-docs Issue #104。

## 下一轮入口

1. 第 56 轮（已登记）：矩阵 #20「用分组和排序管理任务」去 WEB 化重判 + 两条 FL 缺口立单（已核实：档位含修改时间 `83e717c`；方向切换与智能分组六维度 `lib/` 内 0 命中，配对断言对照组 `TaskSort` 命中 5 文件）。
2. `:217`-`:219` 的「排序 → 分组改自定义」前提：判「做 / 不做 / 不可达」，再谈 #15 能否升「有」。
3. specs/044 撤证里那条「端到端『确认删除后列真的消失』红因未定位」仍待补。
