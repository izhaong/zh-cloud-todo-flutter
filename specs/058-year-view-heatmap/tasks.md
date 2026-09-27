# 058 年视图按日热力图 — 执行台账

基线：`origin/develop@9032005`。代码终态 head = `cff9e13`（其父 `4c42297` 是实现笔次）。
Gitea Issue #381；矩阵 #28 缺口「无按日热力」。**PR 尚未合并 ⇒ 矩阵状态不得翻转，只写「已实现、未合并」。**

## 一、红测（两轮，都是编译期红）

| 轮 | 日志 | 读数 |
| --- | --- | --- |
| 草稿测试 | 统计行 `00:00 +0 -1: Some tests failed.` 在 `/tmp/r110/g-red.log:96`、全文 99 行 | 5 条 `Error: Method not found: 'calendarHeatmapLevel'`（测试文件 `:63`-`:75`） |
| 定稿测试 | 统计行 `+0 -1` 在 `/tmp/r110/g-red2.log:128`、全文 131 行 | 8 条编译错（括号内为测试文件行号）：`calendarHeatmapLevel` ×5（`:134/:140/:152/:102/:103`）、`No named parameter 'showHeatmap'` ×1（`:74`）、`getter 'showHeatmap' isn't defined` ×2（`:268/:284`） |

计数判据（现跑）：`grep -c "Error:" /tmp/r110/g-red2.log` 读 8（其中 2 条是同一批错误的重复回显段，
所以 `grep -oE "Error: [^']*'([a-zA-Z]+)'` 命中 3 个不同符号：`calendarHeatmapLevel` / `showHeatmap` 参数 / `showHeatmap` getter）。

**红的性质要说清**：这是编译红 ⇒ 16 条用例**一条都没执行**，不是"15 条断言红、1 条绿"。
真正的行为红要到实现后才出现（见 §三的门禁首轮）。

## 二、六项门禁（终态跑在 `cff9e13`，`status_before_gates=[]` ⇒ 已提交的干净树）

日志 `/tmp/r110/gates-cff9e13.log`，各门禁原始输出 `/tmp/r110/raw-<n>.out`。

| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` + 1b `git diff --check origin/develop HEAD` | 两条都 `rc=0`、无输出 |
| 2 `dart format --output=none --set-exit-if-changed <5 个文件>` | `Formatted 5 files (0 changed) in 0.04 seconds.`、`rc=0` |
| 3 `flutter analyze --no-pub` | `No issues found! (ran in 1.7s)`、`rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（**9 张基线未重录**：`git status --short test/goldens` 为空、`find test -name '*.png' \| wc -l` = 9） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:22 +914 ~26: All tests passed!`、`rc=0` |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、`rc=0` |

**rc 口径**：每个门禁单独 `"$@" > raw.out 2>&1; rc=$?`（见 `/tmp/r110/gates.sh` 的 `runc`），
退出码不来自管道尾部的 `tail` —— 上一轮我就是靠这条抓到假绿。
**跑完后** `status_after_gates=[]` ⇒ `flutter test` / `build` 没有把 `pubspec.lock` 扫进工作树。

### 门禁首轮是红的，两处都是我自己的错（不是存量欠债）

首轮 head 是 `4c42297`（日志 `/tmp/r110/gates-4c42297.log`）：G3 `rc=1` 报 4 条，G4 `+9 -1`。逐条：

1. **漏了第三个调用点** —— `test/task_view_action_repository_test.dart:532` 也调 `saveCalendarDisplay`，
   我加必传参数时只 grep 了 `lib/` 和那两个日历测试文件。判据：
   `grep -rn saveCalendarDisplay --include=*.dart lib test` 命中 5 处（`lib/…:197`、`lib/…:136`、
   两个日历测试的 override、以及被我漏掉的 `test/task_view_action_repository_test.dart:532`）。
   ⇒ 教训：**改必传参数要先对全仓 grep，别按"我改过的文件"圈范围**。
2. `Color.opacity` 已 deprecated（`test/features/task/calendar_year_heatmap_test.dart:133`）⇒ 改 `.a`。
3. 日格语义串多余插值花括号 ×2（`lib/features/task/views/calendar_view.dart:1007`）⇒ 去掉。

三处修完 = `cff9e13`，六个 rc 才全 0。

### 计数可复算

`+914 = develop 基线 898 + 本轮新增 16`。两侧都是现量：
基线 `+898 ~26: All tests passed!` 在 `/tmp/r109/baseline-develop.log:1152`、全文 1153 行（该文件另有
`baseline rc=0` 一行；运行目录是 `origin/develop@90320057` 的一次性检出）；
新增判据 `git diff origin/develop HEAD -- test/ | grep -cE '^\+[[:space:]]*(test|testWidgets)\('` = 16、
去掉的用例 `grep -cE '^\-[[:space:]]*(test|testWidgets)\('` = 0。
文件内分布：`test/features/task/calendar_year_heatmap_test.dart` 声明 11 条 `testWidgets` + 5 条纯函数 `test` = 16
（判据：`grep -c 'testWidgets(' 该文件` = 11、`grep -cE '^    test\(' 该文件` = 5）。

## 三、反向探针：分母下限不是白加的

把 `calendarHeatmapLevel` 的分母下限从 4 改成 1（等价于"纯按当年最大值归一"），
只跑热力图测试：统计行 `00:01 +15 -1: Some tests failed.` 在 `/tmp/r110/probe-floor.log:88`、全文 91 行；
失项清单长度判据 `awk '/^Failing tests:/{f=1;next} f&&NF' /tmp/r110/probe-floor.log | wc -l` = 1，
内容 = `稀疏年份不把唯一一次完成画成最深档` ⇒ 探针只打中这一项（`+15 -1` 的 15 就是其余未受影响条数），
这条用例**确实**在量下限，不是恒真断言。
还原判据：`cp /tmp/r110/impl.bak lib/... && cmp -s` 通过（脚本内打印 `RESTORE: identical to pre-probe`），
备份随即删除，探针没有留下字节差异。

## 四、交叉验证（`cursor-agent`，第二意见）

`/tmp/r110/crosscheck-381.out` 共 4414 字节、末行 `CROSSCHECK: DONE` ⇒ 真跑了（不是空返回）。

| 它说什么 | 我怎么处置 |
| --- | --- |
| ①「热力图不跟『显示已完成』」成立；沿用 `_visibleTasks` 会让默认态全年最浅，与 `:98` 矛盾 | **采纳**，并补一条专门用例（`热力图数的是完成频率，不跟「显示已完成」一起被滤空`） |
| ②开启后必须非懒加载，否则"360px 下找 12 月日格"会因没构建而**假红** | **采纳**；这条直接解释了我为什么分叉出 `_MonthHeatmap`（见 spec §三 3） |
| ③反对我的分母：纯 year-max 会让"全年只完成 1 项"那天落最深档，建议给分母垫下限 | **采纳**（下限 4，见 `calendarHeatmapLevel`），并补 §三 的探针证明这条判据会红 |
| 事实复核 A/C 成立；B 成立但**子判断有错**：它说「工作区未检出 `test/goldens/**/*.png`」 | **驳回**（复算）：`find test -name '*.png' \| wc -l` = 9，9 张基线就在盘上；B 的结论本身另有硬证据 = 门禁 4 `+9: All tests passed!` 且 `git status --short test/goldens` 为空 |
| 它自报 `flutter analyze` 被环境拒绝 ⇒「无法验证」 | 不采信也不反驳：analyze 由门禁 3 在本机跑，`No issues found!` |

## 五、四件套落点（对应 spec §五 A7）

| 项 | 用例 | 关键判据 |
| --- | --- | --- |
| 320px + 1.3 倍字号 | `320px + 1.3 倍字号下开启热力图不溢出，且 12 月的日格真的被构建` | 同一条里既断言 `takeException() isNull`，又断言 `calendar-year-day-2026-12-03` **和** `-01-03` 各 1 个 —— 防止"没画出来所以没溢出"的假绿 |
| 独立读屏语义 | `每个日格有独立读屏语义（日期 + 当天完成数）` | 先 `ensureSemantics()`，再 `getSemantics(find.byKey(日格))` 量**带 key 节点自己**的 `label`，不用全树 `bySemanticsLabel`（会被旁侧 `Text` 满足） |
| 失败保留已生效状态 | `存盘失败时热力图仍留在界面上，并给可见提示` + `未配置仓储时开关仍然生效，只是不持久化` | 前者用 `_ThrowingRepository` 真抛异常走 catch 分支；后者 repository 传 `null` ⇒ 是"没有库"不是"写失败"，两条不混用 |
| 过期响应不覆盖新响应 | `偏好读取在途时用户已开启热力图，迟到的旧值不得回滚` | `_SlowRepository` 卡住 `getCalendarDisplay`，用户先开热力图，再 `release.complete()`；旧值 `showHeatmap: false` 到达后日格必须还在 |

## 六、台账自扫

判据（现跑）：`python3 /tmp/wt-fl-361/tool/check_spec_selfscan.py specs/058-year-view-heatmap/spec.md`
与同脚本跑本文件 ⇒ 两份都 0 失项。
（该脚本 develop 上没有，来自未合并的 FL !364；本机副本 `/tmp/wt-fl-361/tool/check_spec_selfscan.py`。）

## 七、只读复核（VERDICT）

| 轮 | 被审 head | 日志 | 结论 |
| --- | --- | --- | --- |
| 第 1 轮 | `cff9e13` | `/tmp/r110/verdict-381-r1.log` | **尚未拿到 VERDICT**（复核进行中，提示词 `/tmp/r110/verdict-381-r1-prompt.md`，10 项待判，其中第 5/6 项是我点名请它专项判的：计数口径与分母下限算不算发明规则） |

**这一格没绿就是没绿**：合并前置条件（六项门禁全绿 + `VERDICT: PASS` + 真实合并试算）里，
门禁已达成、合并试算已达成（下一条），**VERDICT 未达成**。

快进性判据（现跑）：`git merge-tree --write-tree origin/develop HEAD` = `d9c7752ae62a076396f41bbdc92fe07080615392`，
与 `git rev-parse HEAD^{tree}` 逐字相等 ⇒ 与 develop 无冲突、可直接快进。
**审的是代码字节 `cff9e13`，PR head 在它之后还多两笔 markdown**（`c06bbbc` 本台账、`d0b3bd4` 补 plan.md）。
差异判据（现跑）：`git diff --name-only cff9e13 d0b3bd4` 只列 `specs/058-year-view-heatmap/*.md`；
若复核按 `HEAD` 数列触达文件而多出一个 `plan.md`，那是它读到了 markdown 增量，不是代码变了。

## 八、本轮踩到与下轮入口

**我自己的两处错要写在台面上**：

1. 第一版测试里 `存盘失败时热力图仍留在界面上` 那条是**假用例** —— 传的是空列表、断言的是 `findsNothing`，
   无论实现对错都会绿。定稿时改成"真数据 + 真抛异常的仓储 + 断言日格仍在"。
2. `saveCalendarDisplay` 加必传参数时漏了第三个调用点（§二），让门禁 3/4 首轮红。

**下轮入口**：
- 等 `/tmp/r110/verdict-381-r1.log` 出 `VERDICT:` 行 ⇒ FAIL 就逐条回源复验后修，PASS 就回填本表第七节并开 PR。
- 矩阵 #28 的说明列要按**本轮终态代码**重测锚点：本轮改动使 `calendar_view.dart` 长了约 190 行，
  docs !102 上那版 #28 行引的 `:106/:807/:819/:828` 已漂；
  现值判据 `grep -nE "class _YearView|class _MonthHeatmap|int calendarHeatmapLevel" lib/features/task/views/calendar_view.dart`
  ⇒ 年视图 `:846`、热力格 `:972`、档位函数 `:1043`。
  状态仍写「部分」，缺口从「无按日热力」改记为「:64 点击日期→周视图并高亮」这一面。
- 顺带欠账（不属于本轮，别混进这个 PR）：FL !364/!365/!367/!372/!380 与 docs !102 的 `VERDICT` 回填，
  其中 !379 的第 1 轮复核因 `claude` CLI 报 `unrecognized_model` 直接退出（stderr 1036 字节那一档），
  已按判活方法重派，落在 `/tmp/verdict-379-r2-dedd329.log`。
