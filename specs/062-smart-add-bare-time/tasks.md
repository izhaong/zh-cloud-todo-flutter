# 062 · 台账（第 119 轮：智能识别「裸时间点」/ FL Issue #387 / 矩阵 #83）

## 一、红测 → 最小实现

先写用例再实现。红测日志 `/tmp/r119/red1.log`：读数 `+2 -6: Some tests failed.` ⇒ 实现前 6 条红、2 条绿
（绿的两条是「不越面」与「带日期词仍走原分支」——它们本就该在旧代码上过）。

复算命令：`grep -oE "\+[0-9]+ -[0-9]+: Some tests failed\." /tmp/r119/red1.log` ⇒ 同上一条读数。

实现落在 `lib/state/nlp_date.dart`：新增 `_parseBareTime` 与 `_hourReadings`，并在 `parse` 的三条既有正则
之后（不之前）接一条兜底分支。规则来自判据源《05-智能识别》`:13`「最近有效的日期和时间」：候选集为
{AM, PM} 读法 × {今天, 明天}，取**严格晚于当前时刻**的最早一个；原文写了下午/晚上等提示时只留一种读法，
提示词从**未被预处理改写的原始输入**里读（预处理会删掉「上午 /早上 /晚上 」这类片段）。

用例文件 `test/nlp_date_bare_time_test.dart`，条数现算：`grep -c "    test(" test/nlp_date_bare_time_test.dart` ⇒ 16。
（其中「半」那组与 AM/PM 那组是复核回来后补的，见第九、十节。）

## 二、六道门禁（跑在**代码**最终字节 `d580ac5` 上，日志目录 `/tmp/r122/`）

| 门 | 命令 | 读数 | rc |
| --- | --- | --- | --- |
| 1 `git diff --check` | `git diff --check` 与 `git diff --check origin/develop HEAD` 各跑一次 | 两条都无输出 | 0、0（`/tmp/r122/g1_diffcheck.log`） |
| 2 format | `dart format --output=none --set-exit-if-changed lib/state/nlp_date.dart test/nlp_date_bare_time_test.dart` | `Formatted 2 files (0 changed) in 0.01 seconds.` | 0（`/tmp/r122/g2_format.log`） |
| 3 analyze | `flutter analyze` | `No issues found! (ran in 1.5s)` | 0（`/tmp/r122/g3_analyze.log`） |
| 4 golden | `flutter test --tags golden` | `00:04 +9: All tests passed!`（基线 9 张未重录） | 0（`/tmp/r122/g4_golden.log`） |
| 5 全量非 golden | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:20 +915 ~26: All tests passed!` | 0（`/tmp/r122/g5_full.log`） |
| 6 build web | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0（`/tmp/r122/g6_buildweb.log`） |

`/tmp/r122/head.txt` ＝ `d580ac5a63d7550d80ef082d138bc01ada514779`；六条 rc 的汇总是
`/tmp/r122/summary.txt`（复算 `cat /tmp/r122/summary.txt`）。

`d580ac5` 之后本分支只有动 `specs/` 的提交 ⇒ 门 2–6 的日志对终态继续有效，判据是两棵代码树没变：
`git rev-parse HEAD:lib HEAD:test` 与 `git rev-parse d580ac5:lib d580ac5:test` 逐字相同
（现算得 `2c1084d6…`、`df1364d2…` 两个号，两条命令各返回同样的一对）；门 1 在终态重跑 ⇒ 同上表第一行。

**这一段之前跑过四轮、读数各在 `/tmp/r119/`（`8957739`，判红）、`/tmp/r119b/`（`9361307`）、
`/tmp/r120/`（`e2954ab`）、`/tmp/r121/`（`f748e86`）**：代码每改一笔就得重跑，旧目录留着是因为
第 1 轮复核是按 `/tmp/r119b/` 对的数（它的 NIT-1 就是那张表的 elapsed 读数和日志不一致）。
第一遍判红的那次：`dart format` 报 `Changed lib/state/nlp_date.dart`（一行 `RegExp(...)` 超 80 列），
复算 `head -6 /tmp/r119/format.log`；按 `--output=none` 的语义它没改文件，只报判红，折行成 `9361307` 后六道全重跑。
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

**第 1 轮已回 `VERDICT: PASS`**（审 `18133d778`，即 `9361307` 及其后的 md 提交），留 5 条 NIT。
全文在 `/tmp/r119c/review-r1.md`（复算 `tail -1 /tmp/r119c/review-r1.md` ⇒ `VERDICT: PASS`），
逐条处置见第九节。第 1 轮没改出一处 FAIL，但它的 NIT-4（「9点半」被静默读成整点）
和 NIT-5（它自己没读判据源原文）都变成了本轮的实质工作，见第九、十节。

**第 2 轮已回 `VERDICT: PASS`**（审代码字节 `d580ac5` 及其后的 md 提交，提交时 head 自报 `dc448fb2a`），
留三条 NIT（处置见第十一节）。判定只认 result 块里以 `VERDICT:` 开头的行
（复算 `python3 /tmp/r125/verdict_from_result.py /tmp/r122/review-r2.jsonl` ⇒ 恰好一行 `VERDICT: PASS`）；
整份日志 `grep -c "VERDICT: PASS"` 会把提示词里那句要求一起数进来 ⇒ 不算判定。

⚠️ **这一轮它有一半取证面没够着，这件事必须进账。** `claude -p` 的文件访问只放行会话工作目录
（本轮是 `/private/tmp/wt-fl-83`），它读 `/tmp/r122/*` 的门禁日志、`/tmp/r121/probe.log` 与
`/tmp/wt-docs/…/05-智能识别.md` 原文全被权限层拦下。拦了多少：
复算 `python3 /tmp/r125/review_tmp_access.py /tmp/r122/review-r2.jsonl` ⇒ 调用 56 次、成功 2、被拦 54。
它没有把没读到的说成读过（逐节标了"沙箱拦截"），判词里也按"无相反证据"而非"核过"来用 ⇒ 这点属实；
但**"PASS"的含义因此被缩小了**：它核的是仓内可跑的那半。

它自己现跑核过并给出读数的（不依赖 `/tmp`）：树号 `git rev-parse HEAD:lib HEAD:test` 与
`d580ac5:lib d580ac5:test` 两两相同（`2c1084d6…`、`df1364d2…`）、触达文件清单、`pubspec.lock` 空、
门 1 现跑 rc=0、`git grep -n "_halfFollows" -- lib` ⇒ 三处调用点齐全、`merge-base origin/develop HEAD`
就是 `origin/develop` 本身、用例条数 17、`grep -c "→ null"` ⇒ 4、`git cat-file -e` 双仓 `tool/` 缺位。

由我在同一台机器上补核的（我有 `/tmp` 读权）：`cat /tmp/r122/head.txt` ⇒ 与 `git rev-parse d580ac5`
全 SHA 逐字相同；`cat /tmp/r122/summary.txt` ⇒ 六行 `rc=0`；`grep "All tests passed" /tmp/r122/g4_golden.log | tail -1` ⇒
`00:04 +9: All tests passed!`、同形命令跑 `g5_full.log` ⇒ `02:20 +915 ~26: All tests passed!`；判据源 `sed -n '5p;13p'` 与 spec 引文逐字相同
（`:13` 末尾那个孤立「)」是原文自带，不是我抄错）、`grep -c '!\['` ⇒ 4、`grep -c "半" 同一文件` ⇒ 0
⇒ 「N点半」在原文里确实没有任何规则。合并试算也现跑：
`git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0、输出仅 1 行（无冲突段）。

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
本轮（第 119 轮）对 #83 的改动只有两处（在 docs 分支，同轮提交）：说明格里被第五节否掉的两句措辞。

**新查出的缺口 #390 这轮不进矩阵**，理由写在账上而不是暗地里跳过：
矩阵 #83 行在 docs 收口线 `!102`（分支 `docs/parity-replay-combined`，提交 `41626e3`）上已经被改过，
而那条 PR 现在处于"六道绿 + VERDICT PASS + merge-tree 无冲突、只等『合并』二字"的状态。
为一条 Issue 编号去追加提交，会把一条 ready 的收口 PR 重新推回复核队列——代价落在用户身上，收益只是一个指针。
⇒ 处置：#83 的「说明/缺口」格里引 #390 这件事，等 `!102` 合并后作为下一条 docs 轮次做；
本轮先由本台账与 FL Issue #390 自身承载证据。


## 七、台账自扫（**跑的是副本**）

`python3 /tmp/r119b/check_spec_selfscan.py specs/062-smart-add-bare-time/tasks.md` ⇒ 失项 0 条；
`python3 /tmp/r119b/check_spec_selfscan.py specs/062-smart-add-bare-time/spec.md` ⇒ 失项 0 条；
`python3 /tmp/r119b/check_spec_selfscan.py --selftest specs/062-smart-add-bare-time/tasks.md` ⇒ 与期望不符的判据 0 条。
（第三句原先只写成裸 `--selftest`，第 1 轮复核抓到它**不可复跑**：该脚本 usage 是 `[--selftest] target`，
少 target 会 `error: the following arguments are required: target` ⇒ 已把参数补全。）
副本来源声明：该脚本在本分支与 `origin/develop` 上都不存在（复算 `git cat-file -e HEAD:tool/check_spec_selfscan.py`
⇒ `fatal: path 'tool/check_spec_selfscan.py' does not exist in 'HEAD'`），它只在未合并的
`feat/361-calendar-list-timeline`（PR !364）里 ⇒ 本轮把它的当前版本复制到 `/tmp` 跑，**没有**为了跑自检而
把 `tool/` 塞进本 PR（那会与 !364 同文件相撞）。

自检判过红的是「覆盖性主张没带命令」这一类（被点名的句型是「数量词 + 都已 / 每个」却不带命令）。
改法是去掉那种量词、把结论落回它自己的复算命令 ⇒ 上一段那几条命令现跑都读到 0。

本轮补写第九、十节后，这把尺又咬了一次真错：把「落进 `spec.md` 验收**第 8 条（**明写…」照写进台账，
被 ⑤ 判「数与项对不上」（复算 `python3 /tmp/r119b/check_spec_selfscan.py specs/062-smart-add-bare-time/tasks.md`
⇒ 改前 1 条失项、改后 0 条）。⇒ 不是判据错，是"数字 + 量词 + 紧跟括号"这个形状本身有歧义，写成「（编号 8）」就两清。


## 八、下一轮入口

- 本规格：第 2 轮 `VERDICT: PASS` 已回填第四节、三条 NIT 见第十一节 ⇒ 合并前置三格齐
  （门禁六条 rc 全 0 + PASS + `git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0 无冲突段），
  **只等「合并」二字**。矩阵 #83 状态仍不翻（未合并）。
- 一处后续精化（未做，理由见第十一节 NIT-1）：「9点、半」这类"点与半之间夹标点"仍会给 9:00。
- 矩阵 #83 的下一面：提醒那半（FL Issue #388）——把已识别的时间同时写成任务提醒。
- FL Issue #390（带日期词的「N点M分」丢分钟）是既有缺口，与 #388 同属 #83 这一行，可同轮做也可分开做。

## 九、第 1 轮 5 条 NIT 的处置

| NIT（复核员原话要点） | 处置 | 现在能复跑的判据 |
| --- | --- | --- |
| 1 golden 台账 elapsed `00:03` 与日志末行 `00:04` 不一致 | 订正为在盘读数 | `grep "All tests passed" /tmp/r122/g4_golden.log \| tail -1` ⇒ `00:04 +9: All tests passed!` |
| 2 `--selftest` 那句没带 target、不可独立复跑 | 命令补全（见第七节） | `python3 /tmp/r119b/check_spec_selfscan.py --selftest specs/062-smart-add-bare-time/tasks.md` |
| 3 AM/PM 提示词同现没有规则、代码按分支顺序取 PM | 写进 `spec.md` 的验收段（编号 8），明写"未定义、不认领语义"；另加一条钉现状的用例 | `grep -c "AM 与 PM 提示词同现" specs/062-smart-add-bare-time/spec.md` ⇒ 1；`grep -c "早上晚上9点" test/nlp_date_bare_time_test.dart` ⇒ 2，用例名与用例体各一处 |
| 4 「9点半」会被静默解析成 9:00 | 改成拒识（`e2954ab`），再收窄到"只看命中处"（`f748e86`）；用例与探针见第十节 | `grep -c "→ null" test/nlp_date_bare_time_test.dart` ⇒ 4（四条拒识用例的标题都带这个箭头） |
| 5 它自己没读判据源原文、矩阵行与 PR 正文（工具上限 + `gh` 不在本机） | 第 2 轮提示词把"必须自己读原文页"写成显式条目 | 见 `/tmp/r122/prompt-r2.md` 第 1 条 NIT-5 |

NIT-5 里还有一句要紧的：`gh` 不在本机，所以第 1 轮无法直读 !389 正文。这条不是我的判据，
但它说明**任何"PR 正文写了什么"的主张都不该由复核员背书**；台账里对 PR 正文只写可由 `git` 复算的部分。

门 1 的带范围读数：台账提交后现跑 `git diff --check origin/develop HEAD` ⇒ 无输出、rc=0。
这条判据吃的就是台账自己的空白，所以**每改一次台账都要重跑**（本轮它就红过一次，见第十节丙）。

## 十、第 1 轮之后我自己查出的事（改了代码的、也记我自己的错的）

**(甲) 我第一版的「半」守卫过度拒识。** `e2954ab` 把守卫放在 `parse` 入口做全文扫
`\d\s*[点时]\s*半` ⇒ 「明天9点开会，下午3点半」这种前半句本来能识别的输入被后半句牵连、整条返回 `null`。
`f748e86` 改成只看命中位置之后的紧跟（`_halfFollows`，尾锚 `^\s*[点时]?\s*半`），
并补两条用例：「不牵连前半句」与「空格也算紧跟」。

红名单只有前者：反向探针在同一份用例、只把 `lib/state/nlp_date.dart` 换回 `e2954ab` 的字节上跑，
读数 `+15 -1`，`[E]` 落在「后半句的「半」不牵连前半句」这一条（复算 `grep "\[E\]" /tmp/r121/probe.log`）；
「9点 半」那条在旧实现下**也是绿的**（全文扫当然也能抓它）⇒ 不能把它算作"本轮修好"，
它钉的是新写法仍然覆盖得住。还原后再跑同一文件 ⇒ `+16: All tests passed!`。

**(乙) 交叉验证通道抓到本分支自己造的自信错值。** 第二意见来自只读通道
`cd /private/tmp/wt-fl-83 && cursor-agent --trust -p "$(/bin/cat /tmp/r121/crosscheck.md)"`，
输出 `/tmp/r121/crosscheck.out`（哨兵行 `CROSSCHECK: DONE` 在，字节数现量 `wc -c /tmp/r121/crosscheck.out` ⇒ 2514）。
它给的形状里有一条「9点 30分」会被读成 9:00。我不接受"记为相邻缺口"就完事，
先把同一批输入分别投给**本分支**与 `origin/develop` 的解析器对读
（两份输出留在 `/tmp/r121/cases_branch.txt` 与 `/tmp/r121/cases_develop.txt`，同一批 18 条输入），
读到的是：develop 上这条是 `null`，本分支给出 09:00 ⇒ **是本轮新带进来的错值，必须本面修**，
于是先写用例跑红（`+16 -1`，`[E]` 那条正是它），再在分钟段前补 `\s*`（`d580ac5`），
同一文件 `+17: All tests passed!`。

同一次对读里另外两条的形状与归属，按证据分开记：
「明天9点30分」丢分钟在 develop 上**就错** ⇒ 既有缺口，立 FL Issue #390，不在本 PR 顺手改；
「9点、半」（夹标点）本分支给 9:00 ⇒ 记录不修，理由是守卫跨标点就会把正常输入误毙，写进 `spec.md` 的顺带效果段。

**(丙) 门 1 判红在我的台账自己身上。** 写完第九、十节提交后端 1 现跑报
`specs/062-smart-add-bare-time/tasks.md:165: new blank line at EOF.`、rc=2 ——
是我这次追加内容时在文件末多留了一个空行。修掉后同一条命令 rc=0（复算
`git diff --check origin/develop HEAD`），提交是 `3f58e09`。
这条不是"门禁误报"：`git diff --check` 吃的就是台账自己的空白，所以每改一次台账都得重跑它。

**(丁) 我把代码树号凭旧记忆抄进台账，抄成了上一个提交的值。** 第二节那句原本写的是
`2225d88a…`、`3df608c7…` —— 那是 `f748e86` 的两棵树；`d580ac5` 又改了 `lib` 与 `test`，
终态实际是 `2c1084d6…`、`df1364d2…`。现跑对账命令：
`git rev-parse HEAD:lib HEAD:test d580ac5:lib d580ac5:test` ⇒ 四行两两相同。
教训与第五节同一条：凡是"现算"两个字后面的数字，必须在那句话写完之后再跑一次取回来，
不能引用本轮早前量到的值。

## 十一、第 2 轮 3 条 NIT 的处置

| 复核员留的 | 处置 | 判据 |
| --- | --- | --- |
| NIT-1 「9点、半」逃过守卫，且 `spec.md` 为"不跨标点"举的例子不成立（那句真正会被误毙的是「明天9点，半小时后」） | 采纳。例子已换成真的那个，并把两个尾巴的真假值现算出来写进 `spec.md`。**实现不动**：加宽守卫要同时排除紧跟「小时」的时长读法，那是带实现改动的活 ⇒ 要重跑门禁与用例，不混在本轮的 markdown 提交里 | `spec.md` 里那条 `python3 -c "...re.compile..."` 现跑 ⇒ `True False False` |
| NIT-2 台账写 `+15 -1` 时没说清探针跑的是哪个版本的用例文件 | 采纳，见下面那段算术。`+15 -1` 与还原后的 `+16` 都对得上"16 条版本" ⇒ 探针跑在 `f748e86` 的字节上，第 17 条「9点 30分」是 `d580ac5` 才加的 ⇒ 不是 17−1 | 复算 `for r in e2954ab f748e86 d580ac5; do echo "$r $(git show "${r}:test/nlp_date_bare_time_test.dart" \| grep -c '    test(')"; done` ⇒ 14、16、17；同笔新增用例数 `git show d580ac5 -- test/nlp_date_bare_time_test.dart \| grep -c '^+    test('` ⇒ 1 |
| NIT-3 它这一轮没读到判据源原文，`:13` 引文末尾的孤立「)」要对一次 | 由我补核（第四节）。原文确实是「…会被识别成今天晚上9点)」，那个右括号是镜像页自带的，spec 与 tasks 的引文都是它的逐字前缀 ⇒ 不是我抄错 | 复算 `sed -n '13p' /tmp/wt-docs/todo/99_参考资料/dida365-help-center/03-特色功能/05-智能识别.md` 对 `grep -n "今天晚上9点" specs/062-smart-add-bare-time/*.md` |

「9点、半」这一格**不立 Issue**，理由写在这儿供后续复核：该形状要求用户在「点」与「半」之间打一个标点，
而本仓已有的同族输入（「9点半」「9点 半」「9时半」）都已拒识 ⇒ 立单只会给这种形状的输入排队——它既不来自原文，也几乎不出现在真实输入里。若哪天要收，判据是「加宽后 `明天9点，半小时后` 仍为 09:00」这条不能红。

### 复核通道的一条自我更正（本轮我自己的错）

派单后我一度报告"复核员读 `/tmp` 没问题"，依据是统计它发起的含 `/tmp/` 的工具调用条数 ⇒ **数的是请求，不是结果**。
按结果重数（`python3 /tmp/r125/review_tmp_access.py /tmp/r122/review-r2.jsonl` ⇒ 56 次里 54 次被拦）
才知道那句话是错的。归到"计数要数对字段"那一族：**一个判据如果只读得到"我做没做"而读不到"成没成"，它就不是判据**。
下一轮起派 `claude -p` 带 `--add-dir /private/tmp`，让复核员自己够得着在盘日志，而不是每轮由我补核。

## 带日期词的分钟（Issue #390，第 144 轮）

红测先行：新增 `test/nlp_date_dated_word_minute_test.dart` 在 `origin/develop@f361be4` 的字节上跑 ⇒ **`+4 -7`**
（复算 `sed -n '134p' /tmp/r136/red390.log` ⇒ 该行即汇总行，该文件全文 141 行）。7 条红就是缺陷本身：三形掉分钟、识别文本只框到「明天9点」、三种非法分钟给了自信错值。
实现后这个文件 11 条用例全绿（条数复算 `grep -c '  test(' test/nlp_date_dated_word_minute_test.dart` ⇒ 11；
绿的那次读数取全量套件 g5 段，`sed -n '15p' /tmp/r136/gates390.log` ⇒ `03:08 +1207 ~26: All tests passed!`，该文件全文 22 行）。

| 面 | 处置 | 判据 |
| --- | --- | --- |
| 「明天/后天/今天 + N点M分」吃进分钟 | `nlp_date.dart` 两条正则各补 `(?:\s*(\d{1,2})分?)?`；新组把 `am\|pm` 从第 5 组顶到第 6 组 ⇒ `_adjustHour(hour, tm.group(6) ?? tm.group(4))` 必须跟着改，不改就把分钟当钟点提示 | 用例 `明天9点30分`／`后天9点30分`／`今天9点30分` 三条各自钉日期档位与分钟 |
| 认领文本 | 高亮短语从 `明天9点` 扩成 `明天9点30分` | 用例 `识别出来的短语要覆盖整串`（改前 Actual = `明天9点`，是红的） |
| 非法分钟守卫 | `minute > 59 ⇒ return null`，新旧两形同一条判断（冒号形 `明天9:75` 以前会 `DateTime(9,75)` 静默滚成 10:15） | 用例 `明天9点75分`／`今天9点75分`／`冒号形明天9:75` 三条都断 null |
| 「半」的既有取舍不被冲掉 | `_halfFollows` 用的 `tm.end` 仍在「点」处结束（`半` 不是数字，补的分钟段不认领）⇒ 「明天9点半」「今天9点半」仍整条不识别 | 用例两条，改前改后都绿（这正是它的作用：证明我没把 `半` 当成 30 分） |
| 四件套 | **不适用**：纯解析函数，无新增界面、无异步、无失败路径（快速添加框那一侧的消费没改） | `git diff --name-only origin/develop...HEAD` 里不含 `lib/features/**` |

**行为改变要认账（不是纯加法）**：`明天9:75` 由「滚成 10:15」改成「不识别」。同一条守卫若只管新形、放过冒号形，就会留下「`9点75分` 拒识、`9:75` 吞错值」两套口径 —— 那比统一改成不认领更糟。此处取舍已请 cursor CLI 出第二意见，结论与本单处置的异同记在 PR 正文里，不在此抄结论。

## 十二、在 head `0df3d2ce3` 上重跑六门（第 149 轮，2026-09-30）

**为什么重跑**：第四节那两轮 `VERDICT: PASS` 绑的是旧字节（`18133d778`、`d580ac5`/`dc448fb2a`），而本分支后来重堆到最新 develop 上（tip = `0df3d2c`），**`0df3d2c` 在本台账里当时出现 0 次** ⇒ 覆盖面不成立，不能拿旧读数去合。门禁日志：`/tmp/r136/g411/`（工作树 `/private/tmp/wt-fl-411`，`git worktree add -f --detach … 0df3d2ce3`，跑完 `git status --short` 无输出 ⇒ `pubspec.lock` 未被本机镜像改动）。

| 门禁 | 读数（各附 `日志文件:行号`，全文行数即该锚点） | rc |
| --- | --- | --- |
| 1 `git diff --check origin/develop...HEAD` | 空输出（`/tmp/r136/g411/g1-check.log:0`，全文 0 行） | rc=0 |
| 2 `dart format --output=none --set-exit-if-changed`（本 PR 两个显式 dart 文件） | `Formatted 2 files (0 changed) in 0.01 seconds.`（`/tmp/r136/g411/g2-format.log:1`，全文 1 行） | rc=0 |
| 3 `flutter analyze` | `No issues found! (ran in 3.6s)`（`/tmp/r136/g411/g3-analyze.log:66`，全文 66 行） | rc=0 |
| 4 `flutter test --tags golden` | `00:05 +9: All tests passed!`（`/tmp/r136/g411/g4-golden.log:75`，全文 75 行；基线 9 张，**未重录**） | rc=0 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:06 +1207 ~26: All tests passed!`（`/tmp/r136/g411/g5-full.log:1496`，全文 1496 行） | rc=0 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`（`/tmp/r136/g411/g6-build.log:81`，全文 81 行） | rc=0 |

`+1207` 比第二节记的 `+915`（`/tmp/r122/g5_full.log:1174`，全文 1175 行）多 292 条（`echo $((1207-915))`）。
这 292 条不是本 PR 新增：本 PR 在 test 侧只带一个文件、这个文件 11 条用例
（复算 `git diff --name-only origin/develop...HEAD -- test/` ⇒ 仅 `test/nlp_date_dated_word_minute_test.dart`；
`grep -c '  test(' test/nlp_date_dated_word_minute_test.dart` ⇒ 11），
其余 281 条（`echo $((292-11))`）不在这条 PR 的差集里，是分支重堆到最新 develop 时一起带进来的他人用例。

**待办（合并前置三格）**：六道绿 = 已成（本节）；真实合并试算 rc=0 = 已成（`git merge-tree --write-tree --name-only origin/develop 0df3d2ce3` 产出 tree 且无 `CONFLICT` 行）；**`VERDICT` 仍欠** ⇒ 第 3 轮只读复核的字节 = 本节提交之后的新 head，覆盖面按「`lib`/`test` 两棵树号与 `0df3d2ce3` 逐字节相等」承接门 2–6，门 1 在新 head 上另跑。矩阵 #83 在合进 develop 之前保持「已实现待合并」。

## 十三、第 3 轮只读复核 `VERDICT: FAIL` 的处置（第 152 轮，2026-09-30）

日志 `/tmp/r136/review-411-r3.jsonl`（result 块复算 `grep -c '"type":"result"' /tmp/r136/review-411-r3.jsonl` ⇒ 1；
`num_turns` 102、`duration_ms` 5840247）。被审 head = `4dea36b`。A（功能面）、D（术语与判据源）、E（诚实性）、
F（台账自扫）它在判词里都写成通过；它开出的 FAIL 与 NIT 都成立、都改了，逐条见下。

- **C（FAIL，采纳）**：第十二节把基线写成 `+898`、差值写成 309，并称这两个数是「第四节记的」。回源：`## 四、只读复核`
  这一节通篇没有 `+898` 这个读数；门禁表里记基线的是第二节第 5 行 = `+915`
  （`sed -n '26p' specs/062-smart-add-bare-time/tasks.md` 可见）。所以那句是**指错小节 + 引错数**，
  `echo $((1207-898))` 只是拿不存在的基线自证。已改按 `+915` 写，差值取 `echo $((1207-915))` ⇒ 292；
  本 PR 自己在 test 侧的贡献改成带复算命令的口径（见第十二节同一段）。
  ⚠️ 复核员给的佐证 `git grep -c 898 … ⇒ 0 条` 本身不准 —— 改前那份 `tasks.md` 在第十二节这句引用里就含 `898`。
  成立的部分是「没有任何一节把 `+898` 当读数记下来」，我按这条改，不照抄它那条 grep。
- **B（NIT，采纳）**：第 144 轮小节里 `+4 -7` 与「实现后 11 条」只报了数、没给日志。已锚到
  `/tmp/r136/red390.log:134`（`sed -n '134p'` ⇒ `00:00 +4 -7: Some tests failed.`，全文 141 行）与
  `/tmp/r136/gates390.log:15`（`sed -n '15p'` ⇒ `03:08 +1207 ~26: All tests passed!`，全文 22 行）。

**覆盖面（本轮只动 `specs/`）**：`git rev-parse HEAD:lib HEAD:test 0df3d2ce3:lib 0df3d2ce3:test` ⇒
`lib` 两侧都是 `38b6b3b3f769455df926d62c0adce457c84d9465`、`test` 两侧都是 `ce1558e95c875d4a07d7f747bcf6abcd0f6a5cfe`
⇒ 门 2–6 的读数由第十二节承接；门 1 在新 head 上另跑 `git diff --check origin/develop...HEAD` ⇒ rc=0、空输出。

**下一格欠什么**：第 3 轮判的是 FAIL ⇒ 合并前置的 `VERDICT` 仍欠一个 PASS，要派第 4 轮（审本轮之后的新 head，
覆盖面按上面两条树号承接）。矩阵 #83 继续保持「已实现待合并」。
