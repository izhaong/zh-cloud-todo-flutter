# 062 · 台账（第 119 轮：智能识别「裸时间点」/ FL Issue #387 / 矩阵 #83）

## 一、红测 → 最小实现

先写用例再实现。红测日志 `/tmp/r119/red1.log`：读数 `+2 -6: Some tests failed.` ⇒ 实现前 6 条红、2 条绿
（绿的两条是「不越面」与「带日期词仍走原分支」——它们本就该在旧代码上过）。

复算命令：`grep -oE "\+[0-9]+ -[0-9]+: Some tests failed\." /tmp/r119/red1.log` ⇒ 同上一条读数。

实现落在 `lib/state/nlp_date.dart`：新增 `_parseBareTime` 与 `_hourReadings`，并在 `parse` 的三条既有正则
之后（不之前）接一条兜底分支。规则来自判据源《05-智能识别》`:13`「最近有效的日期和时间」：候选集为
{AM, PM} 读法 × {今天, 明天}，取**严格晚于当前时刻**的最早一个；原文写了下午/晚上等提示时只留一种读法，
提示词从**未被预处理改写的原始输入**里读（预处理会删掉「上午 /早上 /晚上 」这类片段）。

用例文件 `test/nlp_date_bare_time_test.dart`，条数现算：`grep -c "    test(" test/nlp_date_bare_time_test.dart` ⇒ 9。

## 二、六道门禁（跑在**代码**最终字节 `9361307` 上，日志目录 `/tmp/r119b/`）

| 门 | 命令 | 读数 | rc |
| --- | --- | --- | --- |
| 1 `git diff --check` | `git diff --check origin/develop HEAD` | 无输出 | 0（`/tmp/r119b/diffcheck.log`） |
| 2 format | `dart format --output=none --set-exit-if-changed lib/state/nlp_date.dart test/nlp_date_bare_time_test.dart` | `Formatted 2 files (0 changed)` | 0（`/tmp/r119b/format.log`） |
| 3 analyze | `flutter analyze` | `No issues found!` | 0（`/tmp/r119b/analyze.log`） |
| 4 golden | `flutter test --tags golden` | `00:03 +9: All tests passed!`（基线 9 张未重录） | 0（`/tmp/r119b/golden.log`） |
| 5 全量非 golden | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:22 +907 ~26: All tests passed!` | 0（`/tmp/r119b/full.log`） |
| 6 build web | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0（`/tmp/r119b/buildweb.log`） |

每份日志的 `--- rc=` 行是真退出码（复算：`grep -H "rc=" /tmp/r119b/*.log`）。

`9361307` 之后本分支只有动 `specs/` 的提交 ⇒ 门 2–6 的日志对终态继续有效，判据是两棵代码树没变：
`git rev-parse HEAD:lib HEAD:test` 与 `git rev-parse 9361307:lib 9361307:test` 相同
（现算 `git rev-parse HEAD:lib HEAD:test` ⇒ `76a96be2…`、`5066eaa0…`）；门 1 在终态重跑
`git diff --check origin/develop HEAD` ⇒ 无输出。

**跑过一遍又重跑的原因**：第一遍（`/tmp/r119/`）在 `8957739` 上判红——`dart format` 报
`Changed lib/state/nlp_date.dart`（一行 `RegExp(...)` 超 80 列）。复算：`head -6 /tmp/r119/format.log`。
按 `--output=none` 的语义它没改文件，只报判红；改完折行成 `9361307` 后六道全重跑，本表读数即重跑结果。
折行那一笔不含行为改动（`git show 9361307 --stat` ⇒ 只 `lib/state/nlp_date.dart`，`3 insertions, 1 deletion`）。

## 三、越界与卫生

- 本分支相对 develop 的触达文件：`git diff --name-only origin/develop..HEAD` ⇒ `lib/state/nlp_date.dart`、
  `test/nlp_date_bare_time_test.dart`、`specs/062-smart-add-bare-time/{spec,plan,tasks}.md`。无别的仓、无 SQL、无 CI。
- `pubspec.lock` 未进入**本次 PR 的提交**（复算 `git log --oneline origin/develop..HEAD -- pubspec.lock` ⇒ 空）。
  声明口径与 !364 同：该文件在 `origin/develop` 上本就被追踪，这句只说本 PR 没碰它，不说它不在仓库里。
- 提交本台账后工作树：`git status --short` ⇒ 无输出（`pubspec.lock` 也没被门禁跑脏，同一条命令即证据）。
- 四件套不适用：本轮零新增界面、零新增异步（判据：`git diff origin/develop..HEAD -- lib` 只出现纯函数体，
  不含 `Widget`/`Future`/`async`，复算 `git diff origin/develop..HEAD -- lib | grep -c "^+.*\(Widget\|Future\|async\)"` ⇒ 0）。

## 四、只读复核

**现欠第 1 轮 `VERDICT`**（审 `9361307` 及其后的 md 提交）。要它判的是：

1. 第二节六道读数是否与在盘日志逐字一致，且日志时间戳晚于被审提交；
2. 「最近有效」的实现是否真按原文 `:13` 那条规则，而不是按我的用例反推——特别要它自造第三种钟点形状
   （例：跨午夜、当前正好整点、只写「点」不写数字）投给 `_parseBareTime`，并给对照组绿样本；
3. 第三节两条「未进入本次 PR 的提交」「四件套不适用」是否成立；
4. `spec.md` 第五节两处订正是否已经和代码对齐（不要照信我的陈述，自己跑 `git grep` 对码）。

拿到 FAIL 就逐条回源复验再改；两轮无新结论停下请示，不刷循环求绿。

## 五、本轮查出并改掉的两处假主张（都在 `spec.md`）

- **正则锚点漂了一格**：原写「三条正则 `:30`、`:44`、`:68`」。以 `RegExp(` 声明行为准应是 `:30`、`:43`、`:67`
  （`:44`、`:68` 是它们各自的正则体行）。复算：`git show origin/develop:lib/state/nlp_date.dart | grep -n "RegExp("`。
  矩阵 #83 用的就是声明行那把尺，本轮已改成与矩阵一致，并在 `spec.md` 注明取哪把尺。
- **把开关说成解析接线**：原写解析「接在 `task_quick_add_sheet.dart:47-49` 与 `quick_add_bar.dart:280`」。
  `:280` 是 `useNlpDate` 开关的本地初值，不是解析点（复算 `git show origin/develop:lib/features/shell/quick_add_bar.dart | sed -n '280p'`）。
  真实解析调用点**三处**：`task_quick_add_sheet.dart:47`（保存时 `:75` 写 `dueAt`）、`home_shell.dart:523`、
  `tasks_by_list_page.dart:1393`（后两处是逐行的 `dueAtResolver` 回调）；
  复算 `git grep -n "NlpDateParser().parse" origin/develop -- lib` ⇒ 3 行。
  **我第一版把它订正成「只有一处」，那句本身也是错的**——只查了 sheet 一个文件就下了全称结论；
  上一行的复算命令就是补这道检查时跑出来的，现已按 3 处改写。
  这条原本是矩阵 #83 说明格里的措辞，被我的 `spec.md` 抄了一遍 ⇒ `spec.md` 已按上面那条复算命令给出的 3 处调用点改写，
  矩阵侧的同一格在 docs 分支同轮改。

顺带按原文查出的**真缺口（未做，已立单）**：原文 `:5` 是「创建日期**和提醒**」两半，提醒那半零命中
（复算 `git grep -in "remind" origin/develop -- lib/features/task/task_quick_add_sheet.dart` ⇒ 0）⇒ FL Issue #388。

## 六、矩阵回写

矩阵 #83 状态**不翻**：PR 未合并，按口径只能写「已实现、未合并」；且提醒那半（Issue #388）仍缺。
本轮对 #83 的改动只有两处（在 docs 分支，同轮提交）：说明格里被第五节否掉的两句措辞。

## 七、台账自扫（**跑的是副本**）

`python3 /tmp/r119b/check_spec_selfscan.py specs/062-smart-add-bare-time/tasks.md` ⇒ 失项 0 条；
`... spec.md` ⇒ 失项 0 条；`--selftest` ⇒ 与期望不符的判据 0 条。
副本来源声明：该脚本在本分支与 `origin/develop` 上都不存在（复算 `git cat-file -e HEAD:tool/check_spec_selfscan.py`
⇒ `fatal: path 'tool/check_spec_selfscan.py' does not exist in 'HEAD'`），它只在未合并的
`feat/361-calendar-list-timeline`（PR !364）里 ⇒ 本轮把它的当前版本复制到 `/tmp` 跑，**没有**为了跑自检而
把 `tool/` 塞进本 PR（那会与 !364 同文件相撞）。

自检判过红的是「覆盖性主张没带命令」这一类：本文件原写「两处都已按代码纠正」、`spec.md` 原写「取下一个有效点」。
改法是去掉不带命令的量词、把结论落回它自己的复算命令 ⇒ 上一段那几条命令现跑都读到 0。

## 八、下一轮入口

- 本规格：第 1 轮只读复核的 `VERDICT` → 回填第四节；合并授权另说。
- 矩阵 #83 的下一面：提醒那半（FL Issue #388）——把已识别的时间同时写成任务提醒。
