# 056 执行台账

## 状态：实现完工；`VERDICT: PASS` 只覆盖到 `41c360365`，其后补的测试笔次待第 12 轮（分支 `feat/369-fixed-time-mode-picker`，PR !372）

矩阵 #12 不动：契约 PR（service !291）与本分支都未合并 ⇒ 只写「已实现待合并」，不翻状态。

## 一、17 条红的归因与处置（全部转绿）

原名单（本文件历史版本记的 17 条，全是「`fixed_timezone=true` ＝保留配置时区墙钟」这条旧语义的断言）
现已全部转绿。复算命令：

```bash
flutter test --exclude-tags 'golden || performance' --concurrency=1   # 读数见第四节
```

三条根因，每条都有独立证据：

1. **把 bool 塞进 int 位**（最大一条）：批量改签名时写出 `TaskTimeMode.fromWire(task.fixedTimezone)`，
   而当时 `fromWire` 收 `Object?` ⇒ `int.tryParse('true')` 失败后**静默回落「浮动」**，
   `flutter analyze` 一声不吭。修：26 处调用点改 `.timeMode`，并把 `fromWire` 收严成 `int?`
   ——收严后立刻又暴露真错：提醒行没有 `timeMode` 字段，另有两处夹具插错了位置。
2. **存/看两侧时区取错**：`_storageLocation` 只对「固定时区」按锚点区解释墙上钟点，
   「固定时间」按设备区 ⇒ 与「显示钉锚点区读数」不自洽，round-trip 断裂。
   读数：`task_time_semantics_repository_test :: fixed timezone wall clock converts through the
   active DST offset` 期望 `2026-10-31 16:00:00.000Z`，实到 `2026-10-31 09:00:00.000`。
   判据与改判过程见 `spec.md` 的「第二次交叉验证」段。
3. **控件契约改名**：`Key('task-fixed-timezone')` 这个布尔开关被三态档位取代
   ⇒ `Key('task-time-mode-1')` / `Key('task-time-mode-2')`；标签从「本地时区/IANA」两态
   变成「`<IANA> 固定时区` / `<IANA> 固定时间`」，用例里的期望串跟着改。

本轮自己写坏又撤掉的假红：`test/sidebar_due_range_test.dart` 的 `_task` 辅助函数没有 `timeMode`
参数，批量脚本给它加了一行 `timeMode: 2,` ⇒ `flutter analyze` 报 `undefined_named_parameter`。
该文件已整份还原（`git checkout --`，还原后 diff 为空）。

## 二、两列必须同源（跑测试撞出来的真缺陷）

`task_repository` 的 `create`/`update` 原来只在调用方显式给 `fixedTimezone` 时才写老位，
详情面板保存只传 `timeMode` ⇒ 落库会出现 `time_mode=2` 而 `fixed_timezone=false` 的分裂行，
老客户端与服务端派生位读法相反。现改成：给了 `timeMode` 就以它为准，两列同源写入。
判据用例：`detail saves all-day and fixed time through task repository`
（同一条里既断言 `timeMode=2` 也断言 `fixedTimezone=true`）。

## 三、四件套（R5）逐条落地情况

| 面 | 用例 | 结论 |
| -- | ---- | ---- |
| 320px + 1.3 倍字号（该 sheet 自己的 context） | `320px + 1.3 倍字号下两档固定仍完整可见` | 部分：两档控件 rect 全在 320 视口内、标题与嘀嗒原句副标题都在、读屏标签命中。**全局 no-exception 判不了** —— 撞出 `RenderFlex overflowed by 36 pixels on the right`，两次反向探针（把 `RadioGroup` 整块隐藏、把副标题换成短串）读数不变 ⇒ 溢出源是 Issue #279 已登记的存量缺陷，不是本控件；用例注释已指回 #279。 |
| 独立读屏语义 | 同上（`find.bySemanticsLabel(RegExp('^固定时间'))`） | 已验 |
| 失败保留已加载数据 | `detail keeps the chosen time mode when saving fails` | 已验：保存失败后库里的 `time_mode` 仍是 0，重开面板档位仍是用户选的「固定时间」 |
| 过期响应不覆盖新响应 | `detail keeps an unsaved time mode against a newer snapshot` | 已验：`watchById` 推来 `time_mode=1` 的新快照后，面板仍是未保存的「固定时间」，且没被写回库 |

写这三条时踩到的坑（记下来给下一个人）：时间选项面板是**懒建列表**，重开面板后不
`scrollUntilVisible` 就直接查档位控件会拿到 0 个（探针读数 `close: 1, radio: 0, label: 0`
证明面板是开着的，只是视口外还没建）。

## 四、六道门禁读数（最终字节，各跑一次）

| 门禁 | 日志 | 读数 |
| ---- | ---- | ---- |
| `git diff --check` | `g4-diffcheck.log` | rc=0，无输出 |
| `dart format --output=none --set-exit-if-changed`（本轮 20 个 .dart 文件，清单 `/tmp/fmt-final.txt`；未做全仓原地格式化） | `g4-format.log` | `Formatted 20 files (0 changed)`，rc=0 |
| `flutter analyze` | `g4-analyze.log` | `No issues found!` |
| `flutter test --tags golden` | `g4-golden.log` | `00:04 +9: All tests passed!`；跑完 `git status --porcelain` 里 png/goldens 计数 = 0 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `g4-test.log` | `02:29 +922 ~26: All tests passed!`（通过 922、跳过 26、失败 0） |
| `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `g4-build.log` | `✓ Built build/web` |

日志都在 `/tmp/gates-369/`。`pubspec.lock` 未随改动提交：每道门禁跑完即
`git checkout -- pubspec.lock`，填表时 `git status --short pubspec.lock` 输出为空。

计数复算命令（读数会随分支前进漂移，别抄这里的数字，现跑现读）：

```bash
flutter test --exclude-tags 'golden || performance' --concurrency=1 2>&1 | tr '\r' '\n' | tail -2
git status --porcelain | grep -ci 'png\|goldens'   # 期望 0
git status --short pubspec.lock                     # 期望空
```

## 五、交叉验证与登记

- 第二意见通道：`cursor-agent --trust`，输出 2,956 字节、哨兵行 `CROSSCHECK: DONE`
  （提示词 `/tmp/crosscheck-369-picker.md`，原文 `/tmp/crosscheck-369-picker.out`）。
  采纳控件形状判断（`RadioListTile.toggleable` 回到未选），驳回其「固定时间的存储也按设备区」
  的结论——理由与复算见 `spec.md` 同名段落。
- Issue #279：登记本面板为第二个复现面（留言 9666，含两条反向探针的判据）。
- Issue #371（本轮新建）：「固定时间」的本地通知仍按存储瞬间触发，未按 `:64` 换算成设备当地
  墙上钟点。属矩阵 #12 第四面，不在本轮修。

## 六、下一轮入口

1. （已完成，见第七节）只读复核（`claude -p` 门禁）拿 `VERDICT`，通过后 commit → push → 开 PR 指向 `develop`，
   正文 `Refs #369`，并声明它 stack 在未合并的 !370（`7126f01`）之上。
2. （已完成）台账自扫判据：本分支不含 `tool/check_spec_selfscan.py`（它在 FL PR !364 的分支上），
   复核前先从 !364 取该脚本，跑
   `python3 <该脚本路径> specs/056-task-fixed-time-mode/tasks.md`，
   现读到「失项 0 条」才算改完；!364 合并后改用仓内路径 `tool/check_spec_selfscan.py`。
   取法与读数记在第七节末尾；`--selftest` 也跑过，判据不符 `0` 条。
3. service #292 提醒侧接 `time_mode`（队列第⑤项）与 FL Issue #371 同一口径，两端一起定。
4. 增量 SQL 两条回填 `UPDATE` 仍未在任何环境执行 —— 要人过目后才跑。
5. 本分支合并后，docs 矩阵 #12 主表行（`zh-cloud-docs` 的 `dida-parity-matrix.md` 第 79 行）
   要按代码改锚点：该行「有」段引的 `task_detail_pane.dart:406`/`:417`/`:476`/`:1514` 与
   `task_time_formatter.dart:167` 都是 develop 上「一个布尔开关」时代的行号，
   三态落地后位置已变（现按符号名引：`_timeMode`、`_timeModeSubtitle`、`RadioGroup`、`_timeZoneLabel`）。
   矩阵行翻状态的前提仍是 service !291 已合并 —— 未合并前只写「已实现待合并」。

## 七、第 10 轮只读复核（PR !372，审的字节 = `5c5a901`，报告 `/tmp/verdict-372-r1.log`）：`VERDICT: PASS`

复核通道是 `claude -p` 的只读门禁，工作树 `git status --short` 干净、HEAD = `5c5a901`。
无 BLOCKER。判据源那一面要说清楚：帮助页在 `zh-cloud-docs` 仓，在复核员的允许目录之外，
所以它是对着**本仓 spec 里逐字引的原句**（`spec.md` 引 `:48/:50/:60/:64`）判的，不是直接读镜像页。

`grep -c "^\*\*NIT" /tmp/verdict-372-r1.log` ⇒ `3`（三条非阻断，逐条处置如下）。

| NIT | 复核员的主张 | 处置 |
| --- | --- | --- |
| 1 | `test/features/task/task_time_semantics_test.dart` 的窄屏用例把「恰好 36px 的 RenderFlex 溢出」写进 `isTrue` 的豁免里 ⇒ 若两档控件自己引入**同数值**的溢出，这条判不出来；归因靠的是台账里的反向探针，不是用例内自动执行的判据 | **不改**（复核员自己也判为可接受的文档化取舍）。书面理由：豁免串钉死在 `36` 这个数上是存量 Issue #279 的代价，收紧它要么给 Sheet 加与本需求无关的布局约束，要么等 #279 自己修掉那 36px（PR !322 车道）。用例注释与第三节表格都指回 #279，不假装这条断言覆盖了溢出归因 |
| 2 | `spec.md` 里「实测后果」的 `+901 ~26 -17` 与「未做完的部分（本笔是 WIP）」两块仍是 WIP 台账态，与本 commit 的终态自相矛盾（方向是"已做写成未做"，不是假账） | **已修**：「实测后果」行标为 WIP 轮历史读数并指向本节；「未做完的部分」改写成逐条终态（17 条已转绿、四件套已覆盖、`tasks.md` 已建、format 与 build 已在终态字节跑过），并把「矩阵 #12 不动」与「提醒时刻按存储瞬间（#371）」两条仍成立的留在原位 |
| 3 | 用例名写「仍可读可**点**」，但断言只有 rect 在 320 视口内 + 文本 + 语义标签，没有任何 `tap` ⇒ 名字里"点"这一面恰恰是没测的 | **已修**：用例改名为 `320px + 1.3 倍字号下两档固定仍完整可见`，与它真正断言的东西对齐；第三节表格的用例名同步改。不补 `tap`：那需要给两档控件加命中测试断言，属新增覆盖面而非把话说准，且"可点"从来不是四件套的判据（判据是"在该 sheet 自己的 context 实测不溢出"＋独立读屏语义） |

### 复核后动了字节 ⇒ 六门禁在终态字节上整套重跑（日志 `/tmp/gates-372/`）

改动清单 `git diff --name-only HEAD`（重跑前）= `specs/056-task-fixed-time-mode/{spec,tasks}.md`
+ `test/features/task/task_time_semantics_test.dart`，其中 .dart 那一笔**只换用例标题字符串**，
未增删断言。计数不变这一点由门禁 5 的读数自证。

| 门禁 | 读数（现读，日志内行尾的 `rc=` 是这道门的退出码） |
| --- | --- |
| 1 `git diff --check` | 无输出，`diffcheck_rc=0`（`g5-diffcheck.log`） |
| 2 `dart format --output=none --set-exit-if-changed`（`/tmp/fmt-final.txt` 的 20 个文件，未做全仓原地格式化） | `Formatted 20 files (0 changed)`，`format_rc=0` |
| 3 `flutter analyze` | `No issues found!`，`analyze_rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`，`golden_rc=0`；跑完 `git status --porcelain` 里 png/gold 计数 `0`（`g5-golden-png-count.txt`）⇒ 9 张基线一张未重录。**这条判据不是恒绿的**：9 张基线本身是受版本管理的文件（`git ls-files 'test/*' \| grep -cE '\.(png\|gold)$'` ⇒ `9`），被重录就会以 ` M test/goldens/…png` 出现在同一条 `git status` 里 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:24 +922 ~26: All tests passed!`，`test_rc=0`（与 `5c5a901` 那轮同一数，改名不改变用例数） |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`，`build_rc=0` |

跑完门禁 `git status --porcelain pubspec.lock` 计数 `0` ⇒ 本机镜像没被扫进这笔。

## 八、第 11 轮只读复核（审 `41c360365`，报告 `/tmp/r125/review-372-r11.jsonl`）：`VERDICT: PASS`

派单通道已带 `--add-dir /private/tmp` ⇒ 这一轮复核员**自己读到了**判据源镜像页与在盘门禁日志
（复算 `python3 /tmp/r125/review_tmp_access.py /tmp/r125/review-372-r11.jsonl` ⇒ 调用 14 次、成功 12、被拦 2，
被拦的两处是 `merge-tree` 需批准与连 Gitea 核 Issue 真身，它都标了"未核"）。
判定仍只认 result 块里的 `VERDICT:` 行（复算 `python3 /tmp/r125/verdict_from_result.py /tmp/r125/review-372-r11.jsonl`）。

它自己现跑核出并被记进账的三件事：`origin/develop` 基线 `90320057c`；FL 与 service 两侧的三档映射逐条对得上
（`fromLegacyFlag(true) → 2`、派生位＝非浮动即 true、两档固定都要锚点时区，且它点名 service 注释里
"别拿派生位顶替锚点判据"那条坑 FL 侧没踩）；`git diff --name-only 5c5a901 41c360365` 里 `.dart` 只有一行、
是**用例标题字符串**，改名后的名字与它真正断言的东西一致（旧名里的"可点"确实没被测）。

### 它抓到的两条 NIT 与处置

- **NIT-A（引文口径）**：`spec.md` 有一处把 `:48` 缩写成"时间会随所在时区改变"，那不是原文子串。
  已改成逐字引 `:48` 与 `:60` 两句、示例单引 `:50`，并现跑确认两句都仍是原文子串：
  `python3 -c "src=open('/tmp/wt-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/07-固定时间与固定时区.md').read().splitlines();spec=open('specs/056-task-fixed-time-mode/spec.md').read();print(all(x in src[i-1] and x in spec for x,i in [('选择「固定时区」，即意味着任务的时间会随着所在时区的不同而改变。',48),('选择「固定时间」，即意味着不论所处时区如何变化，任务的时间都会保持一致。',60)]))"` ⇒ `True`
- **NIT-B（真空白，不是措辞）**：v22→v23 那条 `UPDATE todo_tasks SET time_mode = 2 WHERE fixed_timezone = 1`
  **没有升级用例**（复算 `grep -c "time_mode" test/app_database_migration_test.dart` ⇒ 0，它说"像是只测了直接建好的 v23 库"属实）。
  这正是 !291 那单立下的「加列必须同时回填」硬要求在本面的测试缺口 ⇒ 本面补，不推给后续。

### 补的那条用例（代码笔次 `36e550bb3`，只动 `test/`）

新建库灌两行（一行 `fixedTimezone=true`、一行不带），再用 `ALTER TABLE ... DROP COLUMN time_mode` +
`PRAGMA user_version = 22` 把库退回"表上还没有这一列"的形状，重开触发 `onUpgrade`，断言升级后
`task-fixed=2`、`task-plain=0`。红绿两头都跑过：

- 撤掉 `customStatement('UPDATE …')` 那一笔语句 ⇒ `00:00 +0 -1: Some tests failed.`，
  失败用例名就是这条新用例（日志已落盘：`/tmp/r125/probe-372B-red.log`，
  复算 `grep -c "Failing tests" /tmp/r125/probe-372B-red.log` ⇒ 1、`grep -c "回填成「固定时间」" 同文件` ⇒ 1，即失败名单里只有这一条）；
- 还原 ⇒ 同一份日志末段有 `RESTORE-OK 字节一致`（`cmp -s` 判的），再跑 ⇒
  `00:00 +1: All tests passed!`、`--- rc=0 ---`（`/tmp/r125/probe-372B-green.log`）。

### 六道门禁（跑在 `36e550bb3` 上，日志 `/tmp/r125/gates-372b/`）

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check` 与 `git diff --check origin/develop HEAD` | 两条都无输出、`rc=0`（`g1_diffcheck.log`） |
| 2 `dart format --output=none --set-exit-if-changed <本 PR 的 .dart 文件>` | `Formatted 40 files (0 changed)`、`rc=0`（文件清单复算 `sed 's/^files: //' /tmp/r125/gates-372b/g2_files.txt \| wc -w` ⇒ 40） |
| 3 `flutter analyze` | `No issues found! (ran in 1.2s)`、`rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`；`git ls-files 'test/*' \| grep -cE '\.(png\|gold)$'` ⇒ `9` ⇒ 基线一张未重录 |
| 5 全量非 golden | `02:24 +923 ~26: All tests passed!`（比上一轮 `+922` 多出的正是新补那条用例） |
| 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |

⚠️ 一处口径如实记下：门禁跑的过程中我把 NIT-A 的 `spec.md` 改动留在工作树里没先提交
（`g7_status.log` 第一行就是 ` M specs/056-task-fixed-time-mode/spec.md`）⇒ 门 1 的那份日志没见到这笔 markdown。
它只动 `specs/`，`lib`/`test` 两棵树号与 `36e550bb3` 相同（复算
`git rev-parse HEAD:lib HEAD:test 36e550bb3:lib 36e550bb3:test` ⇒ 四行两两相同），
但门 1 按规矩要在终态重跑一次，跑完的读数与命令写在下面那两行，不进上面那张表。
`git log --oneline origin/develop..HEAD -- pubspec.lock` 条数复算 ⇒ `0`。
门 1 终态重跑：`git diff --check` 与 `git diff --check origin/develop HEAD` ⇒ 两条都无输出、`rc=0`
（复算 `tail -1 /tmp/r125/g1-final.log`，这份日志是本次新写的，没覆掉 `/tmp/r125/gates-372b/` 里的证据）。

### 合并前置现状（下一轮的入口）

第 11 轮 PASS 审的是 `41c360365`，其后多了一笔测试代码 ⇒ **PASS 不再覆盖要合的字节**，
需要第 12 轮（范围可以收窄到：这条新用例是不是真能咬住回填、它有没有把 develop 既有行为误钉成期望）。
在它回来前本单不具备合并前置；矩阵 #12 仍不翻。

## 九、第 12 轮只读复核（审 `170b029b4`，报告 `/private/tmp/r123/verdict-372-r12.jsonl`）：`VERDICT: FAIL`

复核员把第 1 至第 5 项判通过（迁移用例真断言了升级前后、撤掉回填语句会红、门禁 head 与日志相符、
台账数字复算得出、FL 与后端两档映射是同一套），失项只有判据项 6：
`spec.md` 里 `:50` 与 `:64` 两条引文在数字两侧插了空格，不是嘀嗒原文的逐字父串。

### 回源复验（这条我认，原因比"手滑"更值得记）
镜像页 `zh-cloud-docs` `origin/develop` 的 `…/01-任务/07-固定时间与固定时区.md` 自身排版就不一致 ——
复算 `git -c core.quotePath=false -C ../zh-cloud-docs show 'origin/develop:todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/07-固定时间与固定时区.md' | sed -n '50p;64p'`
读到的 `:50` 是同一行里「上午 11 点」带空格、句尾「上午6点」不带，`:64` 是「上午7点」。
⇒ 订正引文既不能统一加空格也不能统一去空格，只能逐处照抄。
第 11 轮记的那笔引文订正只对了行号与词序、没对空格，所以 PASS 过了一次却在第 12 轮被判红。

### 处置（笔次 `a602da8894`，只动 `specs/`）
四处改成逐字：`:50` 的引文、`:64` 的引文、采纳段里那条被换行断开的 `:64` 引文、以及转述里同样的数字空格。
新尺子 `/private/tmp/r123/quote_check.py`（只做 `git show`，不写盘），**两端都跑过**：
- 坏基线 `python3 /private/tmp/r123/quote_check.py . 170b029b4` ⇒ `带行号引文 9 条，非逐字 3 条`、`rc=1`
- 修完 `python3 /private/tmp/r123/quote_check.py . a602da8894` ⇒ `非逐字 0 条`、`rc=0`

第一版尺子在坏基线上只报得出 3 条里的 2 条（`:N` 与引号之间隔着"示例 1"就没匹配上），
把识别语法放宽成允许 14 字内的说明后才对齐 —— 只看绿的那端会把自己骗过去。

### 同一类错误是否还在别处（换 develop 的 specs 用同一把尺扫）
复算 `python3 /private/tmp/r123/sweep.py`（读数已存 `/private/tmp/r123/sweep.txt`）⇒
`develop specs 带行号引文 55 条；语料里找不到 18 条；数字空格型 0 条`。
⚠️ 这里我先前写的是「那 18 条都是台账自用的短语句」—— 那是没核实就下的结论，作废。改按归属分类重跑同一把尺：同一子句里带代码文件名的有 6 条，属源码行号锚点而非页面引文；被判成「引自原文却不逐字」的读到 0 条；剩下 12 条归属不明，本轮没有判它们。⇒ 结论只能写成「已归类部分复发 0 条、12 条待判」，不能写成全局零复发。

### 六道门禁（跑在 `a602da8894` 上，日志 `/private/tmp/r123/gates-372d/`）

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check` 与 `git diff --check origin/develop HEAD` | 两条都无输出、`rc=0`（`g1_diffcheck.log`）；写完本节后的终头再各跑一次，同样无输出、`rc=0` |
| 2 `dart format --output=none --set-exit-if-changed <本 PR 的 .dart 文件>` | `Formatted 40 files (0 changed)`、`rc=0`；清单条数复算 `sed 's/^files: //' /private/tmp/r123/gates-372d/g2_files.txt \| wc -w` ⇒ 40 |
| 3 `flutter analyze` | `No issues found! (ran in 1.5s)`、`rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`；`cat /private/tmp/r123/gates-372d/g8_baseline_count.txt` ⇒ `9` ⇒ 黄金基线没被重录 |
| 5 全量非 golden 非性能 | `02:40 +923 ~26: All tests passed!`、`rc=0` |
| 6 `flutter build web --release --dart-define=…` | `Built build/web`、`rc=0` |

门 7 的工作树自报（`g7_status.log`）除末行 `--- rc=0 ---` 外没有别的行 ⇒ 跑门禁期间没有把本机镜像扫进提交的东西；
`git log --oneline origin/develop..HEAD -- pubspec.lock` 复算条数 ⇒ `0`。

### 台账自扫（判据工具的出处要写清）
`tool/check_spec_selfscan.py` **在 `origin/develop` 上还不存在** —— 目前只在未合并的 `origin/feat/361-calendar-list-timeline`（PR !364）上。
本节写完后这样跑：`git -C ../zh-cloud-todo-flutter show origin/feat/361-calendar-list-timeline:tool/check_spec_selfscan.py > /tmp/r123/check_spec_selfscan.py`
再 `python3 /private/tmp/r123/check_spec_selfscan.py specs/056-task-fixed-time-mode/tasks.md` 跑在写完本节的终态上，读数为 `specs/056-task-fixed-time-mode/tasks.md: 失项 0 条（仓库根按 wt-fl-369 解析）`。

### 合并前置现状（下一轮的入口）
第 12 轮 FAIL 已在 `a602da8894` 改掉，六道门禁也重跑在该头上；
写完本节又多一笔 markdown（`lib` 与 `test` 两棵树号不变，复算
`git rev-parse HEAD:lib HEAD:test a602da8894:lib a602da8894:test` ⇒ 四号两两相同）。
⇒ 需要第 13 轮覆盖终头（提示词已写 `/private/tmp/r123/prompt-372-r13.md`，范围收窄到
"那条 FAIL 是否真改到位、新尺子有没有判别力、同类错误在别处、门禁是否仍代表要合的字节"）。
在它回来并给出 PASS 之前本单不具备合并前置；矩阵 #12 仍不翻。

## 十、第 13 轮只读复核（审 `f6e89fc4`，报告 `/private/tmp/r123/verdict-372-r13.jsonl`）：`VERDICT: PASS`

复核员自报 HEAD 与被审头一致、工作树干净、`origin/develop` 为 `9032005`。四项判据都过：

- 那条 FAIL 真被改到位：它把镜像 `:50`、`:64` 两行原文并排贴出来复验，连"同一行内「上午 11 点」带空格、句尾「上午6点」不带"这处不一致也保留了。
- 尺子两端由它亲手复算：坏基线读到 `非逐字 3 条`、`rc=1`；终态读到 `带行号引文 11 条、非逐字 0 条`、`rc=0`。
  终态比 §九 那次多出 2 条，是本文件新写的带行号引文被同一次跑覆盖到 —— 不是尺子漏了。
- 同类错误在别处：`specs/056` 里其余声称来自原文的引文逐条比过，仍是镜像行的逐字父串；修完没把别的引文改坏。
- 门禁与终态字节：`gates-372d/head.txt` 是 `a602da8894`，它与终头 `f6e89fc4` 的 `lib`、`test` 两棵树号两两相同，
  中间那笔只动 `specs/…/tasks.md`。

### 它留的两条 NIT 与处置

| NIT | 处置 |
| --- | --- |
| 尺子的漏形没在台账里列出来 | 采纳，写在下边那段 |
| §九 里「第 105 行跨行断开」是自指行号、与实际位置错位 | 采纳，已在 §九 改成不带行号的说法（本仓自己注释里引自己的行号会随每一笔追加漂） |

尺子已知的漏形，都还没被测过：`:N` 与引号之间的说明超过 14 字就整条跳过；引文跨两行以上会断成含换行缩进的串；
`「」` 嵌套时内层先闭合导致截断；同一个 `:N` 后面跟多条引文时只匹配第一条。

### 合并前置现状
六道门禁全绿（跑在 `a602da8894`）+ 第 13 轮 `VERDICT: PASS`（覆盖终头 `f6e89fc4`）+
真实合并试算 `git merge-tree --write-tree origin/develop HEAD` ⇒ `rc=0`，三格齐了。
本节这笔 markdown 会让 head 变成新 SHA，但 `lib`、`test` 两棵树号与 `f6e89fc4` 相同
（复算 `git rev-parse HEAD:lib HEAD:test f6e89fc4:lib f6e89fc4:test` ⇒ 四号两两相同），门 1 在新终头再跑一次。
⇒ **本单只等用户「合并」二字**；未合并前矩阵 #12 仍写「已实现待合并」，不翻状态。
队列注意：本 PR 栈在未合并的 !370 之上，并与未合并的 !351、!360、!364 在 `settings_route.dart` 与 `calendar_view.dart` 有已知冲突 ⇒ 合并轮要按队列顺序解，不是快进。

## 十一、第 14 轮：并主干到 `b25fdd7489`，并适配 develop 在本分支之后落地的测试

§十 把基线钉在 `9032005`；本轮把 develop 现头 `b25fdd7489` 合进来（这笔是 !406 的合并提交，
`git log -1 --format=%s b25fdd7489` 读到「Merge pull request 'feat(task): 日历中的任务可拖入清单详情区域换清单（矩阵 #32 面 ②，Issue #398）' (#406) from feat/398-calendar-task-into-list into develop」）。
四处文件八个 hunk 的冲突没有随手挑一侧，两处各有一条可复算依据。

### 取哪一侧，以及凭什么

- `lib/state/providers.dart` 与 `lib/features/settings/settings_route.dart` 取 !370 终头 `3da9388` 的字节。
  依据是这两笔相对**当前** develop 只有加法：`git diff --numstat origin/develop 3da9388 -- lib/features/settings/settings_route.dart lib/state/providers.dart`
  ⇒ `43 0` 与 `18 0`（删除列都是 0，所以照搬不会把 develop 后来的改动带回退）。
  本分支对这两个文件自己的增量只有 providers 的一处调用点转换与一行 import
  （`git diff --stat 7126f01 25ec14f -- lib/state/providers.dart lib/features/settings/settings_route.dart` ⇒ `1 file changed, 2 insertions(+), 1 deletion(-)`，
  列出来的那一个文件是 `providers.dart`，`settings_route.dart` 在 !370 之后本分支没再动）。
  同一处时区/周起始的冲突在 !370 已经解过并过了第 3 轮复核，这里取其已审字节，避免同一处冲突解出两个版本。
- `lib/features/task/views/calendar_view.dart` 与 `lib/features/task/views/timeline_view.dart` 取 develop 的字节，再把本分支的机械转换重放上去。
  依据是本分支在这两个文件上的差集只有转换一类：
  `git diff 90320057 25ec14f -- <这两个文件> | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE 'fixedTimezone|TaskTimeMode\.fromWire|task_time_mode'`
  ⇒ 空输出（两个文件各跑一次，都是空）。
  以 develop 为底才保得住它新加的 `_taskRow`、`_DayTimeline` 与那条跨日时间轴，
  并且它新写出来的展示调用点也一起转过来 —— 例如 develop 把 `_displayTime` 从 `_AgendaView` 的静态方法提到了文件顶层，
  这一处的旧入参在 git 的三方对齐里会被当成"本分支没改过"而漏掉。
  转换数按现读：`calendar_view.dart` 三处、`timeline_view.dart` 十一处、`providers.dart` 一处（复算 `grep -c 'mode: TaskTimeMode.fromWire(' `）。
  重放后这三个文件里 `fixedTimezone: <表达式>.fixedTimezone,` 这种旧入参形状为 0 命中
  （判据 `grep -rn -E 'fixedTimezone: [A-Za-z_][A-Za-z0-9_.]*\.fixedTimezone,' lib | grep -v app_database.g.dart`，
  剩的三行是 `task_detail_pane.dart`/`reminder_repository.dart`/`task_repository.dart` 里的 companion 写入，不是展示入参，本分支原本就保留）。

### 并主干后 analyze 现读到的错与处置

第一遍门禁跑在未适配的 `661c404`，`/tmp/r136/g372/g3.log` 读到 `6 issues found`，全部落在 develop 本分支之后落地的测试里：
五条 `missing_required_argument`（`sidebar_task_drop_test.dart`、`calendar_agenda_timeline_test.dart`、`calendar_list_timeline_test.dart`、
`eisenhower_quadrant_drag_test.dart`、`week_start_consumers_test.dart` 的 `TodoTask(...)` 夹具）与
一条 `invalid_override`（`calendar_task_into_list_test.dart` 的 `_ScriptedRepository.update` 少了 `timeMode` 形参）。
补值按本仓既有派生口径：这些夹具的 `fixedTimezone` 都是 `false`，对应 `timeMode: 0`（浮动），与 `TaskTimeMode.fromLegacyFlag` 的映射一致；
替身签名补 `int? timeMode,` 放在 `bool? fixedTimezone,` 之后，与 `task_repository.dart:282-301` 的真实形参顺序对齐。
六处都只补入参，没动任何断言，也没动期望值。这笔是 `ac2aca2`。

### 六道门禁读数（跑在最终字节 `ac2aca2`，日志目录 `/tmp/r136/g372b`）

| 门 | 命令 | 现读 |
| --- | --- | --- |
| 1 | `git diff --check $(git merge-base origin/develop HEAD) HEAD` | `rc=0` |
| 2 | `dart format --output=none --set-exit-if-changed` 本轮显式十个文件 | `rc=0` |
| 3 | `flutter analyze` | `No issues found!` 与 `rc=0` |
| 4 | `flutter test --tags golden` | `+9: All tests passed!`，`goldens_dirty=0 png=9`（基线没重录） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `+1211 ~26: All tests passed!` 与 `rc=0` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` 与 `rc=0` |

门 2 的十个文件 = 本轮显式动过的四个 lib 文件加六个 test 文件（清单在 `/tmp/r136/gates372b.sh` 的 `FMT_FILES`）；
跑完全部门禁后 `git status --porcelain | wc -l` ⇒ `0`，`pubspec.lock` 没被顺手带进来。
本节这笔台账只动 markdown，`lib` 与 `test` 两棵树号与 `ac2aca2` 相同
（复算 `git rev-parse HEAD:lib HEAD:test ac2aca2:lib ac2aca2:test` ⇒ 四个号两两相同），门 1 在新终头再跑一次。

### 复核通道当前不可用，本轮没有 VERDICT

`claude -p --permission-mode plan` 这两次派单都以 `is_error=true` 收尾：
`/tmp/r136/review-docs113-r1.jsonl` 最后一段正文是 `Request timed out`；
`/tmp/r136/review-311-r2.err` 记 `[claude-code:unrecognized_model] {"model":"Top1","query_source":"sdk"}`。
本机 `~/.claude/settings.json` 把 `model` 与 `ANTHROPIC_MODEL` 都设成了同一个别名（凭据与网关地址不落本文），别名解析在网关那一侧，
所以这不是提示词或参数写法的问题 —— 同一套参数在 !370 第 3 轮拿到了 `VERDICT: PASS`。
⇒ 本 PR 的合并前置缺第 14 轮 VERDICT（六门绿 + 真实合并试算齐了也不能合），矩阵 #12 与 #83 里「已实现待合并」的措辞这轮不动。

### 队列变化（按 merged_at 现读）

FL !370 于 `2026-09-29T14:36:39Z` 合并发 `f361be4726`，Issue #368 随之 `state=closed`
（复算 `GET /repos/izhaong/zh-cloud-todo-flutter/pulls/370` 读 `merged_at` 与 `merge_commit_sha`，再读 `issues/368` 的 `state`）。
合并前置是六门绿（跑在 `3da9388`）+ 第 3 轮 `VERDICT: PASS` + `git merge-tree --write-tree origin/develop 3da9388` ⇒ `rc=0` 且 CONFLICT 行 0 条。
本 PR 的上游因此落到 develop：栈关系从「压在未合并的 !370 上」变成「develop 已含 !370」，
§十 末尾那条「要与未合并的 !351、!360、!364 在 `settings_route.dart` 与 `calendar_view.dart` 撞面」的队列注意，对仍未合并的分支继续成立。

### 下轮入口

1. 复核通道恢复后给 `ac2aca2`（或含本节这笔的终头）补第 14 轮 VERDICT，三格齐了再谈合并。
2. 矩阵侧现在有两处可翻：#12 的「时区总开关」那半（!370 已合并 `f361be4726`）、#83 的「提醒那半 + 裸时间点那半」（!392 合 `b4604c3fe1`、!389 合 `cdba0141a2`）。
   另有一处仍是真缺口：#83 的判据 `git grep -n "\.nlp" origin/develop -- lib` 复跑还是 0 命中，`NlpApi` 依旧只有定义。
3. FL 队列里 !314、!356、!382、!385 仍与 develop 撞面；service !294、!276、!288、!307 里 !307 与 !294 的合并前置仍缺 VERDICT。


## 十二、第 14 轮 VERDICT 回填与合并端点的堵点（2026-09-30 凌晨）

### 第 14 轮只读复核：判为 PASS，但哨兵行被截断

报告 `/tmp/r136/review-372-r14.jsonl`，审的字节 = `5ccd186`（本分支当时的终头），
末个 `type=result` 块长 8530 字节、`is_error=false`、`num_turns=116`。
正文写的是「**FAIL：0 条**」，三条 NIT：

| NIT | 内容 | 处置 |
| --- | --- | --- |
| NIT-1 | 第十一节说「门 1 在新终头再跑一次」却没有日志留档，六份门禁日志全 pin `ac2aca2` | 采纳。本节的复算命令补上：门 1 在新头现跑，读数记在下面 |
| NIT-2 | `specs/056` 缺 `plan.md`，与仓约定「三件套」字面不符 | 不阻断，且不是本分支引入：同级已合并的 052/064 同样缺。记为治理欠账，不在本 PR 顺手补 |
| NIT-3 | 提示词预期 `providers.dart` 相对 develop 的删除列应为 0，实到 `20 1` | 复核员自己已归因：那 1 删是本分支自己的 `fixedTimezone → mode` 转换，不是 develop 内容回退。不采纳为缺陷 |

**诚实记账**：末行哨兵在输出里是 `VERDICT: PAS`，最后一个字符被截断。
我按正文的「FAIL：0 条」与它自述的「本报告即为对第 14 轮 VERDICT 缺口的补位」判为 PASS，
并把截断本身写在这里 —— 不假装看到了完整哨兵。复算：
`grep -o 'VERDICT: PA.$' /tmp/r136/review-372-r14.jsonl | tail -1`。

### 门禁覆盖最终代码字节的证据（承接 r14 的 NIT-1）

六份日志 pin `ac2aca2`，而 `git diff --name-only ac2aca2 5ccd186` ⇒ 只有本节这类 `specs/` 台账；
`git diff --stat ac2aca2 5ccd186 -- lib test` ⇒ 空 ⇒ 代码字节相同，门 2–6 的读数承接。
门 1 在新头另跑（`git diff --check origin/develop HEAD`），不靠空工作树蒙过去。

### 合并端点现在的堵点（不在本分支的内容上）

`POST /repos/izhaong/zh-cloud-todo-flutter/pulls/372/merge` ⇒ HTTP 405 `Please try again later`；
`GET /pulls/372` ⇒ `mergeable=false`、`base.sha=3da9388`，而 `origin/develop` 已到 `f361be4`。
本地真跑 `git merge-tree --write-tree origin/develop 5ccd186a` ⇒ rc=0、CONFLICT 0 处，
远端分支也还在（`git ls-remote origin refs/heads/feat/369-fixed-time-mode-picker`）。
判据与两条出路已写在 PR !372 的留言里；本节这笔只动 `specs/`，
推送后 `git diff 5ccd186 HEAD -- lib test` 仍应为空 ⇒ 上面那份 PASS 继续覆盖代码字节。

## 十三、第 14 轮 VERDICT 回收（2026-09-30 第 146 轮收尾）

报告 `/tmp/r136/review-372-r14-report.md`（由 `/tmp/r136/review-372-r14.jsonl` 的最后一个 `type=result` 块导出）。
终态：`terminal_reason=completed`、`is_error=false`、`num_turns=116`、正文 8530 字符。

### 逐项结论（A–F 共六项，逐条抄自报告小标题）

| 项 | 报告判定 |
| --- | --- |
| A 并主干有没有丢东西 | PASS |
| B 三态与 `TaskTimeMode` 的接线 | PASS |
| C 测试是否真钉住（含 `Key('task-time-mode-0')` 的形状） | PASS |
| D 术语与判据源逐字 | PASS |
| E 门禁覆盖面与卫生 | PASS |
| F 台账诚实性 | PASS |

报告第 79 行原文：`**FAIL：0 条。**`

### 一处要如实记下的形状问题

哨兵行回报成 `VERDICT: PAS`，最后一个字符在 stream-json 组装时掉了。按「VERDICT 只认最后 result 块」的口径，这块的 `terminal_reason` 是 `completed` 而非截断，正文六项全标 PASS、且明写 FAIL 0 条，所以本条按 PASS 入账；但**不接受**用整文件 grep 出来的 `VERDICT:` 当判据——本轮同一次扫描里，`review-314-r1`、`review-311-r3`、`review-docs113-r2` 三份都从整文件 grep 读出过结论，实际它们当时还没有 result 块（进程仍在跑），是假信号。

### 这份 PASS 覆盖到哪几个字节

r14 审的是 `5ccd186`。当前分支头 `18cc090` 相对它的差集只有本节所在的 `specs/056-task-fixed-time-mode/tasks.md`（复算：`git diff --name-only 5ccd186a92 HEAD`，非 `\.md$` 的行数为 0 个），所以代码字节未变 ⇒ 上面这份 PASS 与六门读数继续覆盖 PR !413 的头。

### 合并端点的堵点（承接 §十二，仍未解）

`POST /pulls/413/merge` 与更早的 `POST /pulls/372/merge` 都回 HTTP 405 `Please try again later`；
本地真跑 `git merge-tree --write-tree origin/develop 18cc09027` 回 rc=0、CONFLICT 0 处（基准 `origin/develop=f361be4`）。
差在 Gitea 侧那条异步 `testpullrequest`，不在本分支内容上。
