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
四处改成逐字：`:50` 的引文、`:64` 的引文、第 105 行跨行断开的那条 `:64` 引文、以及转述里同样的数字空格。
新尺子 `/private/tmp/r123/quote_check.py`（只做 `git show`，不写盘），**两端都跑过**：
- 坏基线 `python3 /private/tmp/r123/quote_check.py . 170b029b4` ⇒ `带行号引文 9 条，非逐字 3 条`、`rc=1`
- 修完 `python3 /private/tmp/r123/quote_check.py . a602da8894` ⇒ `非逐字 0 条`、`rc=0`

第一版尺子在坏基线上只报得出 3 条里的 2 条（`:N` 与引号之间隔着"示例 1"就没匹配上），
把识别语法放宽成允许 14 字内的说明后才对齐 —— 只看绿的那端会把自己骗过去。

### 同一类错误是否还在别处（换 develop 的 specs 用同一把尺扫）
复算 `python3 /private/tmp/r123/sweep.py`（读数已存 `/private/tmp/r123/sweep.txt`）⇒
`develop specs 带行号引文 55 条；语料里找不到 18 条；数字空格型 0 条`。
这 18 条是台账自用的短语句（自造的流程名之类），不是声称来自原文某行的引文，本尺不判它们；
本轮这型的复发数读出来是 0。

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
