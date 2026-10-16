# 140 任务表 — 看板卡片「分配给」与团队看板三面判定（Issue #317）

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
- [x] 详情页「指派执行人」与看板右键共用同一份实现（复算：`git grep -c openTaskAssignAction <head> -- lib` = 3 个文件命中 ⇒ 定义 1 处、调用 2 处），且**原实现的陈旧响应守卫已补回**：
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

**第 2 轮复核后的增量提交 `282ffa8`**：只改这两份 markdown（`git diff --name-only 6f4efd8 HEAD` 实得
`specs/140-kanban-card-assign/{spec.md,tasks.md}`），Dart 与用例字节一丁点没动 ⇒ 上表 2-6 号的读数对最终字节仍然成立，
不为 markdown 重跑 30 分钟的门禁；门禁 1 换新范围重跑：`git diff --check origin/develop HEAD` **rc=0**（复核 R2-7 指出上一版只扫了 `HEAD~1 HEAD`）。

## 反向探针（每条断言都要能红，红不了就不算证据）

| # | 改法 | 期望 | 实际读数（日志） |
| - | ---- | ---- | ---------------- |
| P1 | 摘掉 `KanbanView.build` 里 `onAssignCard:` 接线 | 依赖菜单的 5 条红、两条判定用例仍绿 | `5` 条 `[E]`，第 5/6 条仍绿 ⇒ 菜单确由此接线驱动；`cmp -s` 确认还原。日志 `/tmp/g57/p1.txt` |
| P3b | 「任务尚未同步，无法指派」的 `Text` 换成空串 | 恰好第 2 条红 | 恰好第 2 条 `[E]`；`/tmp/g57/p3b.txt` |
| P4 | 菜单文案换成自创的「指派给」 | 依赖文案的 5 条红 | `5` 条 `[E]`；**重跑版** `/tmp/g57/p4b.txt` 里带上了它自己的 diff（原 `/tmp/g57/p4.txt` 与 P1 同 md5，分不清"没菜单"还是"换了字"，已被这条取代） |
| P3-real | 摘掉整块 `if (taskServerId == null) { … return; }` | 想看它是行为红还是编译红 | **编译红**：`task_assign_action.dart:40:23: Error: The argument type 'int?' can't be assigned to the parameter type 'int'`，计数停 `+0` ⇒ 这个 `if` 同时承担类型收窄，**不能当行为探针**。日志 `/tmp/g57/p3-real.txt` |
| P5 | 只删早退里那句 `return;`（保留提示） | 同上 | 同样编译红（`:43:23`），日志 `/tmp/g57/p5.txt` ⇒ 「未同步就不许 push」这件事由类型系统 + 第 3/4 条正反对照钉住，而不是靠这条探针 |

**探针基准（第 2 轮复核点的，写在这里免得读数被当成对最终文件负责）**：P1/P3b 跑在**7 条用例**的那份文件上
（`/tmp/g57/p1.txt` 里第 4 条还叫「清单未同步时不 push 指派页」，提交前才改名），P4b 的 diff
（`index cb366f6..0b251af`）连 `onAssignCard` 必填化那一整块一起带上 ⇒ 这三条都跑在 `37a06b0` **尚未提交**的工作树上。
这不推翻任何一条结论（探针判的是"摘掉这处会不会红"，与用例数无关），但**每条读数只对它当时那份文件成立**，
拿日志去对最终字节会数不上。

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
| N4 | 「字节级未变」这句强于它自己的断言（只比 3 个字段、没看发件箱） | 成立；另「请先登录」那一支确实无用例 | 升级为整行 `toJson()` 比对 + 发件箱行数不涨；「请先登录」把"造不出这个状态"的原因写进 spec 当作结构缺口，不假装测过 |
| N5 | `find.text('任务动态')` 用 `findsWidgets` 偏松 | 成立：全 lib 只有两处该字样，另一处是「暂无任务动态」 | 改 `findsOneWidget`（并靠配对的未同步说明 findsOneWidget 保证不是恒真） |
| 驳回 | 我的自疑点 2（`:188` 被 fixture 特殊化） | **复核驳回我，我复验后接受**：长 tooltip 全文件只有 1 处（内嵌态），但 `_buildPage` 窄屏/宽屏各有一个入口（`Text('协作')` / `tooltip: '协作'`），三条分支都到得了 hub | 不改变判定；按复核的残留 NIT 在 spec 写明"用例只钉住内嵌态那串字，独立页标签是「协作」" |

### 第 2 轮复核（`VERDICT: PASS`，无 BLOCKING，7 项 NIT）逐条处置

复核确认了第 1 轮四处 BLOCKING 的修复到位：B3 守卫回原位（并逐行比对 develop `_resolveList` 就是同一句 SQL）、
B4 用例组里那条 `task-activities` 用例（组内序号 7）是真证据，组内条数复算：`git grep -c "testWidgets(" <head> -- test/features/task/kanban_card_assign_menu_test.dart` = 8；该 key 全仓唯一且落在 `serverId != null` 那支、B1 的探针表已与五份日志逐一对齐（`md5 p4.txt == md5 p1.txt`、`md5 p3.txt == md5 green5.txt` 复算一致）、
用例数可加减核 `898 + 8 = 906` 与 `pr_files=6` 都对得上。以下 NIT 的处置：

| # | finding | 处置 |
| - | -------- | ---- |
| R2-1 | `spec.md:16` / `tasks.md` 把**改写**放进「」里当引用（`「先在『排序』中将『分组』改为『自定义』才可管理分组」`） | 改引 `:218` 逐字整句，并写明"上一版那是改写不是引用"（本轮已改：spec 的 `:217`-`:219` 那段 + 本文件「仍缺」对应条） |
| R2-2 | 四件套"过期响应"那格写"②由详情页既有用例路径承载"，会把读者引向"有覆盖"——实测 `grep -rln "指派执行人" test/` 只有新用例第 5 条，且它只断言该项存在、**未点击** | 该格改成"守卫挂在详情页那条路上，而该路目前没有任何用例"（本轮已改） |
| R2-3 | 探针 P1/P3b/P4b 跑在 7 条用例 / 未提交的工作树上，表头没写基准 | 在探针表下方补"探针基准"一段（本轮已加） |
| R2-4 | 「请先登录」无用例的解释成立，但可造"菜单已弹、库后失"的时序 | spec 取舍 3 补一句：那种时序判的不是用户可见状态，本轮不做、不当已覆盖（本轮已加） |
| R2-5 | `openTaskAssignAction` 在任何 await 前捕获 `ScaffoldMessenger.of(context)`，develop 是在守卫之后现场取 | **不改 Dart**：该差异只在"await 期间被 reparent 到另一棵 Scaffold 且 `mounted` 仍为 true"时才显形，本页面形状走不到；为一句话注释重跑六道门禁不值。理由写进 spec 取舍 8（本轮已加） |
| R2-6 | 看板卡片右键未做 `desktopMode` 判定，清单行是 `task_row_host.dart:186` 显式 gate ⇒ 同一手势两处平台口径不一致 | 记为 spec 取舍 7（本轮已加），**另立一轮再改**：那是行为变更，要重测触屏路径与整组门禁 |
| R2-7 | gate1 用的是 `HEAD~1 HEAD`，只覆盖 fix commit | 复核自己补跑 `git diff --check origin/develop HEAD` rc=0；本轮把这条覆盖面差异记在这里，不再为一句 markdown 改动重跑全部门禁 |

## 仍缺（不谎称完成）

- `:188` 的独立页/窄屏两个入口没有用例；`:198` 的 `_ActivitySection` 内部"拉到动态 ⇒ 渲染列表"这一段仍无 UI 用例 ⇒ 这一格判「部分」。
- 「过期响应不覆盖新响应」：看板书这条路不跨 await，守卫只存在于详情页那条；`stillCurrent` 本身**没有独立用例**（要造"Sheet 开着时切任务"的时序）。
- 「请先登录」分支无用例（造不出"看得见卡片但库为 null"的状态）。
- 卡片右键菜单只有「分配给」一项；帮助中心没写看板右键的完整菜单，不补别的项，也不声称"右键菜单已复刻"。
- `:217`-`:219` 的前提仍未实现，原句逐字是：需要先在清单右上角的「排序」中将「分组」改为「自定义」，才可以管理分组。
  （specs/044 / PR !314 那条线）
- 矩阵 #15 的行内证据要等本 PR 合并后才能写 SHA；回写内容挂在 izhaong/zh-cloud-docs Issue #104。
- 看板卡片的右键入口**没有 `desktopMode` 判定**，与清单行（`task_row_host.dart:186` 显式 gate）口径不一致（spec 取舍 7）；
  本分支不修，因此"触屏端右键无处可点"这件事在两处分别是"隐式不给"和"显式不给"，**不算已对齐**。
- 详情页那条指派路（`指派执行人` → Sheet → `openTaskAssignAction`）**没有任何用例**：
  用例第 5 条只断言 Sheet 里有这一项、未点击 ⇒ `stillCurrent` 守卫目前无人守。

## 第 56 轮的去向（记在这里，免得下轮重复劳动）

原计划「矩阵 #20 去 WEB 化重判 + 两条 FL 缺口立单」**有一部分是重复劳动**：#20 早在 docs **!102 的 `164455c`**
（第 52 轮）就按同一份帮助页改判成「部分 / BE/FL」，且取证比我这轮那份更细（智能分组轴、时间分桶、术语「已逾期/已过期」）。
根因：开工前只看了 develop，没读 !102 的 diff。
处置：**不另开 PR**（那会造成第 8 条同文件互撞），把真正的净增量折进 !102 —— 提交 `ba287db` 给 #20 补第五条缺口
「排序方向切换」（`:173/:175/:176`，0 命中判据 + `TaskSort` 44 命中正向对照），并挂上 **todo-flutter #320 / #321**。
本地那份重复分支（`docs/matrix-20-grouping-sorting@8a333c0`，已推远端）**不开 PR、等一次授权再删**。

## 下一轮入口

1. **本 PR 合并后**：把 #15 的行内证据换成合并 SHA（矩阵回写走 docs Issue #104 那条线），并按 !102 里 #15 那一行的「部分」重核剩项 —— 合并前不翻状态。
2. 看板卡片右键补 `desktopMode` 判定（与 `task_row_host.dart:186` 对齐）：这是**行为变更**，要连带补触屏端用例并整组重量门禁。
3. 详情页那条指派路补一条用例（点开 `指派执行人` 并验证 `stillCurrent` 在切任务时不 push）—— 现缺口见「仍缺」。
4. `:217`-`:219` 的「排序 → 分组改自定义」前提：判「做 / 不做 / 不可达」，再谈 #15 能否升「有」。
5. specs/044 撤证里那条「端到端『确认删除后列真的消失』红因未定位」仍待补。

## 与 develop 收口（本轮终头 `8062b0d7e`）

**为什么有这一节**：前几轮 PASS 绑 `37a06b0`，其 `37a06b0:lib = f831c69f8`，
本轮 head 的 `:lib = 5799c2132` ⇒ 代码字节变了，覆盖面必须重绑。

**冲突与解法**：冲突只在 import 段：本单把详情页「指派执行人」那整段抽成 `openTaskAssignAction`（内部仍推 develop 已有的 `TaskAssignPage`，不是第二份实现），develop 同期把 `ListMemberPage` 搬进了 `../list/list_actions.dart`。⇒ 取 `task_assign_action` + `list_actions` 两条，撤掉两条已不直用的 import（`task_assign_page` 改由 helper 引、`list_member_page` 已被挪走）。另核过 develop 的 `_resolveList` 本体就是 `db.listByLocalId` 的一行转发（`git show origin/develop:lib/features/task/task_detail_pane.dart | grep -A3 '_resolveList(AppDatabase'`），helper 用同一口径，没有分叉。
本轮触达 `6` 个文件，其中 `.dart` `4` 个：`lib/features/task/task_assign_action.dart`、`lib/features/task/task_detail_pane.dart`、`lib/features/task/views/kanban_view.dart`、`test/features/task/kanban_card_assign_menu_test.dart`。
合并提交 = `d91b3e9ac`（HEAD 的第一父）。

**六道门禁跑在终头 `8062b0d7e` 上**（门禁日志在仓外 `/tmp/gates-360-319.log`；下面每个读数旁给了复算命令）：

| 门禁 | 读数 |
| ---- | ---- |
| 1 `git diff --check origin/develop...HEAD` | rc=0、输出 0 行 |
| 2 `dart format --output=none --set-exit-if-changed`（全部 4 个 `.dart` 触达文件） | rc=0 |
| 3 `flutter analyze` | No issues found! |
| 4 `flutter test --tags golden` | +9: All tests passed!（基线 9 张未重录） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 03:07 +1050 ~26: All tests passed! |
| 6 `flutter build web --release --dart-define=…` | ✓ Built build/web |

门禁脚本在两个仓之间串跑时记录的 `pubspec.lock` 脏行数 = 0（本机镜像不随 PR 走）。

**矩阵行**：本 PR 未合并 ⇒ docs 矩阵对应行仍写「已实现待合并 + PR 号」，不翻状态；
合进 develop 后由 docs 侧换成合并 SHA。
