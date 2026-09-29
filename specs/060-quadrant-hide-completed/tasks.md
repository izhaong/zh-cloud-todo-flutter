# 第 112 轮台账 — FL #384 四象限「隐藏已完成」（specs/060，矩阵 #36 ⑩）

- 仓库 / 分支：`zh-cloud-todo-flutter` `feat/384-quadrant-hide-completed`，基线 `origin/develop@9032005`
- 提交：`a37c7b2`（4 个 lib + 1 个 test）、`67d077c`（按交叉验证删掉一条冗余用例）、本笔台账
- 上一批（第 111 轮 PR !383）状态：`open` ⇒ 本轮不引用它的任何 SHA 作为"已合并"证据；
  它和本单**改的是同一个文件** `eisenhower_view.dart`，所以合并顺序上 !383 先来（下面 §七 记了冲突面）。

## 一、落地的三面（判据 `:131`/`:132`，见 `spec.md` §一）

1. 入口：`todo-sort-menu` 里加「隐藏已完成」（`task_workspace_header.dart:208-236`），
   默认隐藏（`tasks_by_list_page.dart:96`），只在四象限视图出现（其余四个视图该项不存在）。
2. 取数：`quadrantShowsCompleted`（`eisenhower_view.dart:396-399`）——清单筛选钉过完成态时以筛选为准，
   四象限不叠第二道闸；两处 `completed` 丢弃（`:176` 本机分档、`:224` 远程分档）与宿主
   `_reportInvalidSelection`（`tasks_by_list_page.dart:1385-1388`）都读这一个尺。
3. 持久化：`getQuadrantDisplay` / `saveQuadrantDisplay`（`task_view_action_repository.dart:147-162`），
   sourceType `quadrant_view`，与 develop 上既有的 `calendar_view` 同类 ⇒ **没有新增后端契约**。

## 二、六道门禁（全部跑在最终字节 `67d077c` 上，日志 `/tmp/r112/`）

| # | 命令 | 读数 | 日志锚 |
| --- | --- | --- | --- |
| 1 | `git diff --check` | rc=0 | `/tmp/r112/g1-check.log:2` |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 5 个文件>` | `Formatted 5 files (0 changed)` ⇒ rc=0 | `/tmp/r112/g2-format-rerun.log:2-3` |
| 3 | `flutter analyze --no-pub` | `No issues found!` rc=0 | `/tmp/r112/g3-analyze-final.log:3-4` |
| 4 | `flutter test --tags golden` | `+9: All tests passed!`；基线 png `9` 张、`git status --short test/goldens` 0 行 ⇒ 没重录 | `/tmp/r112/g4-golden-final.log:76-79` |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `+914 ~26: All tests passed!` rc=0 | `/tmp/r112/g5-full-final.log:1173-1174` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0，跑完 `git status --short pubspec.lock` 空行 ⇒ 没把本机镜像扫进 PR | `/tmp/r112/g6-build-final.log:80-82`（全文 82 行；`:82` 是 `-- pubspec.lock --` 那行，其后无输出） |

⚠️ 门禁跑了两遍这件事要按事实记：第一遍（`g3-analyze.log` / `g4-golden.log` / `g5-full.log` / `g6-build.log`）
跑在"删掉那条冗余用例但还没 `dart format`"的字节上，格式化确实改了字节（`cmp` 判不等），
所以 g3-g6 在 `67d077c` 上**重跑**了一遍，上表引的是 `*-final.log`。
复算：`git rev-parse --short HEAD` ⇒ `67d077c`。

本面用例计数与两条独立互证：`flutter test test/features/task/eisenhower_hide_completed_test.dart` ⇒
`+16: All tests passed!`（`/tmp/r112/g-test-6.log:65`）。全量 `+914` = develop 基线 `898` + 本面 `16`；
第 111 轮同一 develop 基线上报的是 `+913` = `898 + 15` ⇒ 两个分支的差值互相咬住基线，不是各抄各的数。

## 三、反向探针（脚本 `/tmp/r112/probes.py`，只改**实现**字节，跑完还原并 `filecmp` 逐字节核对）

| 探针 | 改坏的地方 | 实际红掉的用例 | 日志 |
| --- | --- | --- | --- |
| P1 | `quadrantShowsCompleted` 去掉"以筛选为准"那一支 | 2 条：纯函数那条 + 页面「清单已按完成态筛过」 | `/tmp/r112/probes.log:1-3` |
| P2 | 菜单项 `enabled` 写死 `true` | 2 条：页面置灰那条 + 组件层正反对照那条 | `/tmp/r112/probes.log:4-6` |
| P3 | 视图两处 `completed` 丢弃条件摘掉（永远显示） | 4 条：含「默认已完成不出现在任何象限」这条回归防线 | `/tmp/r112/probes.log:7-11` |
| P4 | 宿主 `_reportInvalidSelection` 退回"四象限一律丢已完成" | 1 条：新增的选中态失效那条 | `/tmp/r112/probes.log:12-13` |

哨兵：`/tmp/r112/probes.log:14` ⇒ `PROBE-BAD=0`；`/tmp/r112/porcelain-after-probes.log:1` ⇒ 探针跑完工作树只剩本单自己的两处改动
（测试文件 + specs 目录），没有探针残留。

## 四、交叉验证（`cursor-agent --trust`，日志 `/tmp/r112/crosscheck-384b.out`，6005 字节，末行 `CROSSCHECK: DONE`）

| 它的判断 | 我的处置 |
| --- | --- |
| D.1「反向对照：判据不是恒真」那条用例与上一条同输入、只把 `isTrue` 换成 `isNot(isFalse)`，不提供独立失败信号 | **采纳**：删掉（`67d077c`），本面 17 → 16 条；该支的真判据本来就由 P1 提供（改坏实际红 2 条，`/tmp/r112/probes.log:1-3`） |
| D.2 两条 320px 用例里 `pumpAndSettle` 之后的 `expect(tester.takeException(), isNull)` "基本恒真" | **驳回**：溢出是布局期抛给 flutter_test 的错误记录，不会在 `pumpAndSettle` 处抛出；这条断言正是把它转成失败信号的口子。P3 改坏实现时「默认隐藏已完成」那条真红（`/tmp/r112/probes.log:8`），说明这条用例不是死重 |
| E 附注：`saveQuadrantDisplay` 不交 `viewType` ⇒ 行内 `viewType` 兜底成 `'list'` | **记为已知偏差**（§六 第 3 条），不改代码：四象限这一面没有"视图模式"这个轴，硬塞一个模式名反而是在造一个不存在的状态 |
| A 置灰 + 原因文案"相对原文是加码，相对本仓 spec 不算越界"；B「用户看得见开关却点不动」的风险成立但已被副文案 + 读屏同句缓解 | 采纳其判据顺序：置灰比"直接隐藏菜单项"更贴近 `:132`「右上角『...』里**有**这一项」的形态（`spec.md` §三 2 方案 A 不变） |

## 五、本轮自己抓到、并修掉的错（不写"顺手改好了"，逐条给现象）

1. **两条断言我写错了对象**，不是实现缺陷：`expect(queued.length, 1)` 与 `expect(rows, isEmpty)`
   都被"切到四象限"那一下既有行为污染（宿主 `_changeMode` 自己会写一行 `task_view` 偏好并入队一次）。
   复算出来的实际值是 outbox `2` 行、偏好表 1 行 `sourceType: task_view` ⇒
   改成只数量含 `quadrant_view` 的那一条。**先证明判据写错，再动实现**这条顺序守住了，两处都没去"顺手改实现"。
2. `Duration.zero` 写成 `const Duration.zero` ⇒ 解析失败（它是静态字段不是 const 构造器）。
3. `excludeSemantics` 挂到 `Text` 上 ⇒ 编译错；它是 `Semantics` 的属性（放在后代那一侧）。
4. 测试辅助函数把 `tester` 写成位置参数、调用处写 `tester:` ⇒ 报的是"Too few positional arguments"，
   看着像实现问题，其实是自己的签名不一致。
5. Drift 伴随类名记错：`TodoTaskCompanion` ⇒ 真实是表名复数 `TodoTasksCompanion`
   （复算 `grep -n "class TodoTasksCompanion" lib/core/db/app_database.g.dart` ⇒ 命中，数据类才是单数 `TodoTask`）。
6. 页面级用例少了仓内既有的收尾排水步骤（`pumpWidget(SizedBox.shrink())` → `pump()` →
   `container.dispose()` → `pump(Duration.zero)` → `db.close()`，同 `task_section_workspace_test.dart:87-90`）⇒
   9 条页面用例全红在 `A Timer is still pending`，报错长得像"页面有动画没停"，
   栈里第 6 帧 `StreamQueryStore.markAsClosed` 才说明是 Drift 关流的零延时定时器。
7. 探针脚本自己先崩过一次：用了不存在的 `shutil.cmp`；第二版 P4 的锚点又是按格式化**之前**的字节写的
   ⇒ `assert 命中 0` 挡住没跑出红（脚本在写盘前 assert，所以没留下改坏的树）。这两条都是"探针没跑成"，
   不能当"实现没问题"的证据 —— 第三版才拿到 §三 那 4 行读数。

## 六、仍缺 / 已知偏差（不藏）

1. **`!383` 未合并**：两单都改 `eisenhower_view.dart`（!383 在 `_QuadrantTile` 外层包 `DragTarget`/`LongPressDraggable`，
   本单改同文件的分类函数与构造参数）。本轮测试跑在未含 !383 的 develop 基线上，
   合并 !383 之后本单的字节需要在它之上重跑一遍门禁。
   2026-09-28 收口：!383 已合并（`GET /repos/izhaong/zh-cloud-todo-flutter/pulls/383` 读到 `merged=true`、`merge_commit_sha=6b4771c292`），本单分支也已把它合进来（`db8896b`，第二父 `b4604c3fe1`）；重跑读数见 §九·补。这一格是**本轮补的注记**，不是原文。
2. 四象限的完成态显隐**只有这一条路径**（菜单项）：源页本节没写键盘/右键的替代入口，
   与 !383 那条"只有拖动"的可达性缺口是同一族问题，留给下一个 Issue，不在本轮偷偷补。
3. 偏好行的 `viewType` 兜底值 `'list'`（§四 E 附注）：四象限没有模式轴，这列对本面无语义。
4. 菜单项**没有**"当前已隐藏/已显示"的勾选图形，只有文字 + 读屏语义里的档位（`隐藏已完成，当前已隐藏`）；
   图形勾选要做成什么样，源页本节没给 ⇒ 不自创。

## 七、只读复核（VERDICT）

### 第 1 轮（被审 head = `221c68b`）⇒ `VERDICT: PASS`

- 派单：`claude -p`，提示词 `/tmp/r112/review-384-prompt.md`，原始流 `/tmp/r112/verdict-385-r1.jsonl`
  （19329164 字节、92367 行事件），结论已从结果块导出到 `/tmp/r112/verdict-385-report.md`。
- **判据只认结果块里的 `VERDICT` 行**：`/tmp/r112/verdict-385-report.md:138` ⇒ `VERDICT: PASS`。
  不做整份 grep：第 108 轮 service !291 那次就是整份 grep 命中 6 处，全是提示词回显造出的假 PASS。
- 它逐节的结论（判据细节在报告里）：A 忠实度成立（`置灰 + 原因` 是本 spec 自己的决定，不是发明交互）；
  B「三道硬丢是否同尺」成立且**没有第 4 处漏网**；C 置灰死角的可见文案 + 读屏同句兜底已缓解；
  D 假绿排查 ⇒ 16 条逐条有可失败路径，点名三条全为真判据；E 同步链路成立
  （`quadrant_view` 走 develop 上已有的 `calendar_view` 通用路径，`task_view` 的两处特例既不漏也不误伤）；
  F 四件套四件各有真实失败路径；G 台账数字与日志逐字一致。**被审 head 它是自己 `git rev-parse` 复算的**
  （报告「字节基准」节），不是我告诉它的。
- **它自报的边界，照抄不遮**：全程只读日志与 git 对象，该节自陈「**未运行任何 flutter/dart 命令**」
  ⇒ 六道门禁"跑过"这件事，它靠日志字节 + 时间戳先后序背书（`67d077c` 01:01:36 早于 g3-final 01:02:30、
  探针 00:52:35 早于最终字节门禁），不是独立重跑的证据。独立重跑的证据在我这边的 `/tmp/r112/*.log`。
- **它抓到一条 NIT，已就地改**：门禁表第 6 行原写 `/tmp/r112/g6-build-final.log:80-81`、`:83`，
  而该日志实长 82 行（复算 `wc -l < /tmp/r112/g6-build-final.log` ⇒ 82）⇒ `:83` 是死锚，
  读数本身（`✓ Built build/web`、rc=0、pubspec.lock 未改）没错。已改成 `:80-82` 并写明 `:82` 是那行
  `-- pubspec.lock --`。顺带一条账给判据器：这种"跟在路径后面的裸 `:N`"它照不到
  （specs/057 第 113 轮已实测它**能**抓带完整路径的越界锚）⇒ 这条是复核员抓的，不是自扫抓的。
- **它自报的边界，照抄不遮**：全程只读日志与 git 对象，**没有重跑任何 flutter/dart 命令**
  （报告"字节基准"节最后一行自陈"未运行任何 flutter/dart 命令"）⇒ 六道门禁"跑过"这件事，
  它靠的是日志字节 + 时间戳先后序（`67d077c` 01:01:36 早于 g3-final 01:02:30、探针 00:52:35 早于最终字节门禁）
  背书，不是独立重跑的证据。独立重跑的证据在我这边的 `/tmp/r112/*.log`。
- 合并前置的快进试算（我这侧现跑，非复核员跑）：`git merge-tree --write-tree origin/develop HEAD`
  的结果树 = `HEAD^{tree}` = `1915b717616f428566834817b65a2e97b127bd27`（跑在 `221c68b` 上）⇒ 快进零冲突；
  `git merge-base --is-ancestor origin/develop HEAD` 退出 0，`origin/develop` 本轮 fetch 后仍是 `90320057`。
  本节这条 markdown 提交会换掉 tree，但快进性质只取决于 develop 是不是祖先 ⇒ 该判据在回写后复跑仍成立。
- 状态：**达成**。矩阵 #36 ⑩ 在合进 develop 前仍只写「已实现、未合并」（校验器拒「待合并」字样）。

## 八、下轮入口

1. ✅ 本轮 PR 的 VERDICT 已回写 §七（`VERDICT: PASS`；它点名的那条死锚已就地改，见 §七 的 NIT bullet）；
   矩阵 #36 ⑩ 合并前保持"已实现、未合并"。

2. 合并顺序：!383（拖动）在前，本单在后 —— 同文件，`git merge-tree` 的试算结果要在 !383 落地后重跑。
   2026-09-28：!383 已在前（`6b4771c292`），本单分支已合入 develop；本轮现量 `git merge-tree --write-tree --name-only origin/develop b599309` 的 rc 记在下面「下轮入口」段。
3. specs/061：年视图「点击日期 → 周视图并高亮」（矩阵 #28 剩的一格，判据 `:64`）。
4. 队列项 ①（service !291）本轮已把第 3 轮续的 `VERDICT: PASS` 与两条 NIT 回写台账并推上去，
   剩下的仍是等「合并」二字。

## 九、第 2 轮只读复核（被审 SHA = PR head `b599309`）⇒ `VERDICT: FAIL`，唯一失项 ③ 已在本节闭环

派单：`claude -p --permission-mode plan --add-dir /private/tmp`，提示词 `/tmp/fl385-r2-prompt.md`，
原始结论流 `/tmp/fl385-r2-verdict.stream.jsonl`（结果块自报 `num_turns=55`、`duration_ms=3398747`、
`subtype=success`）。判据仍只认结果块 `type=="result"` 里以 `VERDICT` 开头的行，不整份 grep
（第 108 轮 service !291 那次整份 grep 命中 6 处，全是提示词回显造出的假 PASS）。

它给的六项：**① 解冲突没丢 !383 的拖动逻辑、② 显隐判定没有第二份事实源、④ 合并没改本单语义、
⑤ spec 里那条复算命令可原样跑通、⑥ 合并前置 —— 均判成立**；
**③ 门禁是否覆盖被审 SHA —— 判不成立**，理由我复算过：
`26deaa9 docs(specs/060): 回写第 1 轮只读复核 VERDICT: PASS，并改掉它抓到的死锚` 是 tasks.md 的末次提交，`b599309` 只动 `spec.md` ⇒ 合并 !383 之后本单字节
从没被 §二 那套读数覆盖。这是**真失项**，不是复核员误判：§二 写的是 `67d077c`，
而 `67d077c` 不含 !383（`git merge-base --is-ancestor b4604c3fe1 67d077c` 退出码非 0 就说明这点）。

复核员自报的现场污染也照抄不遮：它跑 `flutter analyze` / `flutter test` 时 pub get 把
`pubspec.lock` 的镜像源 url 重写了，属它自己引入、不属本 PR ——
`git diff-tree -r b599309 --name-only` 里 pubspec 出现 `0` 次（本单没带 lock 进 PR），
我这侧 `git checkout -- pubspec.lock` 后 `git status --short pubspec.lock` 得 0 行。

### 九·补 六道门禁重跑在被审字节 `b599309` 上（日志目录 `/tmp/r133/gates-b599309/`）

| # | 命令 | 读数 | 日志锚（绝对路径:行号） |
| --- | --- | --- | --- |
| 1 | `git diff --check` | 无输出 | `/tmp/r133/gates-b599309/g1-check.log:2` 是 `rc=0` |
| 2 | `dart format --output=none --set-exit-if-changed` 本单 5 个 .dart 显式文件 | `Formatted 5 files (0 changed)` | `/tmp/r133/gates-b599309/g2-format.log:2`，`:3` 是 `rc=0` |
| 3 | `flutter analyze --no-pub` | `No issues found! (ran in 3.7s)` | `/tmp/r133/gates-b599309/g3-analyze.log:3`，`:4` 是 `rc=0` |
| 4 | `flutter test --tags golden` | 摘要行 `00:04 +9: All tests passed!` | `/tmp/r133/gates-b599309/g4-golden.log:12`，`:13` 是 `rc=0` |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 摘要行 `03:07 +1058 ~26: All tests passed!` | `/tmp/r133/gates-b599309/g5-full.log:1267`，`:1268` 是 `rc=0` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | `/tmp/r133/gates-b599309/g6-build.log:18`，`:19` 是 `rc=0` |

下面几条把上面这些数钉住（每条自带命令，不靠本节别处的表）：

- 基线分解：`/tmp/r133/base-b4604c3-full.log` 摘要行 `03:09 +1042 ~26: All tests passed!` ⇒
  **1042 + 16 = 1058**，右边等于门禁 5 的 `+1058`；本面用例数取
  `flutter test test/features/task/eisenhower_hide_completed_test.dart` 的末行（**实跑 16 条**，
  不是 `grep -c testWidgets` 的声明数）。跳过数 `26` 与 §二 的 `~26` 同值。
- golden 没重录：`git status --short test/goldens` 得 0 行；
  `git ls-files test/goldens` 数到 9 个受版本控制的基线文件。
  ⚠️ 我第一版探针写的是 `ls test/goldens | wc -l` ⇒ 得 **1**，那数的是子目录条目不是 png
  （真实目录是 `test/goldens/todo_workspace/*.png`）⇒ **取错字段的 1 不能当证据**，本行改按 `git ls-files` 数。
- 门禁 1 单独跑过（它吃台账自己的空白，不在"md-only 可承接"的范围里）：
  `git diff --check` 在 `b599309` 上无输出，见 `/tmp/r133/gates-b599309/g1-check.log:2`。

### 九·状态

- **达成**：第 2 轮唯一失项 ③ 已用"在 `b599309` 上重跑六道门禁并把读数写进本节"闭环；
  §二 那份 `67d077c` 的读数**保留原文不改**，它是第 1 轮 PASS 绑定的字节，重写等于伪造历史。
- **仍欠**（该条写于第 3 轮派发之前，判过之后的账见 §十一，本节保留原文不改）：第 3 轮只读复核（本节提交后 head 会变；变的是 markdown，
  `git rev-parse` 出来的 `lib`/`test` 两棵树号不变 ⇒ 覆盖面靠"三棵树号逐字节相等"承接，
  这条口令与第 133 轮合并 !347/!367 用的是同一条）。矩阵 #36 ⑩ 在合进 develop 之前仍写「已实现、未合并」。

## 十、下轮入口（第 134 轮）

1. 派第 3 轮只读复核，审的字节 = 本次 §九 提交后的新 head；覆盖面用 `git rev-parse <head>:lib` 与 `:test` 两个树号对 `b599309` 逐字节比下来承接六门，门禁 1 另跑（`git diff --check` 吃的就是台账自己的空白）。
2. 三条前置都过才谈合并：六道门禁全绿（§九·补）、`VERDICT: PASS`（待第 3 轮）、真实合并试算 rc=0（不加 `--quiet`——它会把冲突也报成 rc=0，第 133 轮实测）。与 !370/!372 同撞 `settings_route.dart` 的那批排在 !360 合并之后。

## 十一、第 3 轮只读复核与合并产物门禁（第 151 轮，2026-09-30）

- 复核通道 = `claude -p --permission-mode plan`，输出 `/tmp/r136/review-385-r1.jsonl`，结论 `VERDICT: PASS`。
  审的字节 = `816a12ab9`（复核自报 `parent1=cbd93c7`、`parent2=f361be4`，与 `git log --format=%P -1 816a12ab9` 一致）。
- 该轮唯一 NIT：§九·补 的六门跑在 `b599309`，其时 develop 是 `f361be4`；后来 develop 又吃了
  `5a831a1`（看板列绑分组）与 `0c7bce9`（标签参与筛选求值），而区间 `f361be4..0c7bce9` 里动过本分支同一份
  `lib/features/task/tasks_by_list_page.dart` 的提交有 5 笔（判据 `git log --oneline f361be4..0c7bce9 -- lib/features/task/tasks_by_list_page.dart | wc -l` = 5）
  ⇒ 「门禁覆盖的是旧基线」这条成立，**不能用树号承接**。
- 修法是把真合并结果落成一棵工作树，在产物字节上重跑六门：产物提交 = `git commit-tree` 出的 `f500669337f2`，
  两个父为 `0c7bce9c4d74` 与 `816a12ab9`，工作树 `/private/tmp/wt-fl-385prod`，日志 `/tmp/r136/prod385.log`。

| # | 命令（跑在产物上） | 读数 |
| --- | --- | --- |
| 2 | `dart format --output=none --set-exit-if-changed` 本单 5 个 .dart（清单见日志 `gate2_files=` 行） | `Formatted 5 files (0 changed)` rc=0 |
| 3 | `flutter analyze` | `No issues found! (ran in 3.8s)` rc=0 |
| 4 | `flutter test --tags golden` | `00:05 +9: All tests passed!` rc=0，`png=9`、`dirty=0` ⇒ 基线未重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:14 +1247 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

门 1 不在这张表里：它吃的是台账自己的空白，随本节提交单独跑（`git diff --cached --check`），
产物侧的 `g5` 从 §九·补 的 `+1058` 涨到 `+1247` 不是本分支多写了用例：本面自己仍是 §九·补 实跑的 16 条
（`flutter test test/features/task/eisenhower_hide_completed_test.dart`），多出来的是 develop 侧带进来的测试提交，
判据 `git log --oneline f361be4..0c7bce9 -- test | wc -l` = 7。

- **状态**：第 3 轮 PASS + 产物六门绿 + 合并试算 `git merge-tree --write-tree --name-only origin/develop 816a12ab9`
  rc=0、`CONFLICT` 0 行 ⇒ 三条前置齐，本节提交后合 !385。矩阵 #36 面 ⑩ 的翻转**只引合并后的 SHA**，落在 docs 仓的
  对照表 PR 里，不在本仓写。
