# 063 · 台账（第 120 轮：智能识别「创建提醒」/ FL Issue #388 / 矩阵 #83）

## 一、红测 → 最小实现

先写用例再实现，探针日志 `/tmp/r124/red1.log`：**同一份用例文件**、只把
`lib/features/task/task_quick_add_sheet.dart` 换回 `origin/develop` 的字节 ⇒ 读数 `+1 -3`，
三条红的是「该建提醒」的正例、「部分失败要保留 + 可见 + 不重建」的失败例、以及那条生产拓扑量法；
绿的那条正是**本该在旧代码上过**的反例（没识别就不建提醒）。
实现前我还跑过一次中途版本（只有三条用例时），那次读数是 `+1 -2` —— 差别就是后补的生产拓扑那条；
两个数都记在这里，免得后来的人以为 `+1 -3` 是笔误。还原后再跑同一文件 ⇒ `+4: All tests passed!`
（复算 `grep -E "Some tests failed|All tests passed" /tmp/r124/red1.log`）。

实现落在 `_TaskQuickAddSheetState._save()` 一处：接住 `TaskRepository.create` 的返回值（它本就返回
`Future<TodoTask>`），识别命中时用 `reminderRepositoryProvider` 建一条 `ABSOLUTE` 提醒，时刻等于识别到的时间。
没有新增 provider、没有新建界面、没有动 `NlpDateParser` 一个字符。

用例文件 `test/features/task/quick_add_nlp_reminder_test.dart`，条数现算：
`grep -c "  testWidgets(" test/features/task/quick_add_nlp_reminder_test.dart` ⇒ 4。

## 二、三道语义裁定与第二意见

判据源原文《03-特色功能/05-智能识别.md》:5 只到「创建日期和提醒」为止，往后没有任何一句规定提醒时刻怎么取、
什么时候该建、建失败了怎样。这三处都是**语义取舍**，按口径先走只读交叉验证通道，再回源复验：

第二意见来自 `cd /private/tmp/wt-fl-88 && cursor-agent --trust -p "$(/bin/cat /tmp/r123/crosscheck-388.md)"`，
输出 `/tmp/r123/crosscheck-388.out`（哨兵行 `CROSSCHECK: DONE` 在，字节数现量 `wc -c /tmp/r123/crosscheck-388.out` ⇒ 1729）。
四条裁定与我已写的实现一致，逐条回源复核后的落点：

| 取舍 | 结论 | 依据（自己回源核过的，不是抄它的） |
| --- | --- | --- |
| 提醒时刻 | 等于识别到的那个时间，`ABSOLUTE`，不预设提前量 | 原文「提前提醒 / 延后提醒」两节只有图片（`grep -c "!\[" 原文` 与 `grep -c "分钟" 原文` 两个读数一起看，复算见第五节）⇒ 没有数字依据；`ReminderRepository.create` 的 `anchorType` 默认就是 `'ABSOLUTE'`、`offsetMinutes` 可空 |
| 触发范围 | 只在识别命中时建 | `_nlpResolvedDueAt` 只由 `_maybeResolveDate` 写；`_addFromTemplate` 走的是另一条 `repo.create`，不碰这个字段（复算 `grep -n "_nlpResolvedDueAt" lib/features/task/task_quick_add_sheet.dart` 的赋值点只有一处） |
| 部分成功 | 不回滚、不关弹窗、原因可见、再点只补提醒 | 本仓刚为「静默早退 / 失败看不见」开掉 #289、#292 两单；关掉弹窗等于把部分成功播成全部成功 |
| `reminders == null` | 显式提示，不写 `?.` | 同一文件里未登录分支已经是 `_report('请先登录')` 的形状；`?.create(...)` 是那条纪律的反面 |

## 三、六道门禁（跑在最终字节上，日志目录 `/tmp/r124/`）

| 门 | 命令 | 读数 | rc |
| --- | --- | --- | --- |
| 1 `git diff --check` | `git diff --check` 与 `git diff --check origin/develop HEAD` | 两条都无输出 | 0、0（`/tmp/r124/g1_diffcheck.log`） |
| 2 format | `dart format --output=none --set-exit-if-changed lib/features/task/task_quick_add_sheet.dart test/features/task/quick_add_nlp_reminder_test.dart` | `Formatted 2 files (0 changed) in 0.01 seconds.` | 0（`/tmp/r124/g2_format.log`） |
| 3 analyze | `flutter analyze` | `No issues found! (ran in 3.1s)` | 0（`/tmp/r124/g3_analyze.log`） |
| 4 golden | `flutter test --tags golden` | `00:03 +9: All tests passed!`（基线 9 张未重录） | 0（`/tmp/r124/g4_golden.log`） |
| 5 全量非 golden | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:20 +902 ~26: All tests passed!` | 0（`/tmp/r124/g5_full.log`） |
| 6 build web | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0（`/tmp/r124/g6_buildweb.log`） |

`/tmp/r124/head.txt` ＝ `c977dc6c1b6e9de18e0764ddb1667a22e88d007b`；六条 rc 的汇总在同一目录 `summary.txt`
（复算 `cat /tmp/r124/summary.txt`）。门 5 的读数现取：
`grep -oE "\+[0-9]+ ~[0-9]+: All tests passed" /tmp/r124/g5_full.log | tail -1`。

## 四、四件套

本轮没有新增界面，但**新增了一条面向用户的提示文案**，所以按本路由自己量一次，不继承上一轮的结论：

- 320px + 1.3 倍字号：新用例「生产形态（320×568 + 1.3 倍字号 + 键盘）…落在键盘上方」用生产拓扑
  （`showModalBottomSheet` + `viewInsets.bottom = 260`）量 `todo-quick-add-feedback` 那行的底边 ≤ `568 - 260`；
  复算 `grep -c "568 - 260" test/features/task/quick_add_nlp_reminder_test.dart` ⇒ 1。
- 失败保留数据：正例与失败例都直接查库（任务行在、提醒行数符合预期），不看控件文案。
- 过期响应不覆盖新响应：**这条我没有满足，也不假装满足**。`_save()` 从来没有防重入的闸门
  （模板那条路径倒是有 `_applyingTemplate`，复算 `grep -n "_applyingTemplate" lib/features/task/task_quick_add_sheet.dart`）；
  这是 develop 上就有的形状，但本面把它切成两种后果不同的重叠：
  **建成功之后再点**已被 `_savedTaskId` 兜住（只补提醒，不建第二遍任务，复算
  `grep -c "_savedTaskId" lib/features/task/task_quick_add_sheet.dart` ⇒ 4），
  真正仍然没防的是**首次 `create` 还在飞行中就连点两次** ⇒ 那时 `_savedTaskId` 还没写进状态，会建两遍任务。
  本面把一次 `await` 变成两次、又把弹窗留在失败态，等于把"可连点"的时间窗整体拉长 ⇒ 不能写成"不适用"。
  已立 FL Issue #391 跟踪（第十节），核心形状按上一句写；不在本 PR 顺手加标志位：
  加不加、加在哪（按钮 disabled 还是 in-flight 标志）该由那条单独的红测决定。
  **本条已由 FL Issue #391 的实现轮闭合**（第十一节），上面这段是当时的判定，不改写。
- 读屏语义：提示走的是既有 `todo-quick-add-feedback` 那一行（同一路由里已有的、被上一条测试钉住的可见节点），
  本轮没引入新的图标-only 按钮或裸 `Semantics` 包裹。

## 五、本轮写下的主张与它的复算命令

- 「develop 上没有提醒这半」：复算 `git grep -in "reminderRepositoryProvider" origin/develop -- lib/features/task/task_quick_add_sheet.dart` ⇒ 无输出。
- 「提醒能力本地已经齐、不需要动后端」：复算 `git grep -n "Future<TodoReminder> create(" origin/develop -- lib/state/repositories/reminder_repository.dart` ⇒ 命中一行。
- 原文那三节只有图片：复算 `grep -c '!\[' /tmp/wt-docs/todo/99_参考资料/dida365-help-center/03-特色功能/05-智能识别.md` ⇒ 4，
  而 `grep -c "分钟" 同一文件` ⇒ 0 ⇒ 「提前多少分钟」在原文里没有文字依据。

## 六、越界与卫生

- 本分支相对 develop 的触达文件：`git diff --name-only origin/develop..HEAD` ⇒ `lib/features/task/task_quick_add_sheet.dart`、
  `test/features/task/quick_add_nlp_reminder_test.dart`、`specs/063-nlp-create-reminder/{spec,plan,tasks}.md`。无别的仓、无 SQL、无 CI、无新依赖。
- `pubspec.lock` 不进本 PR：新 worktree 首跑 `flutter test` 会 `pub get`，提交前 `git status --short` 只列我自己的四个文件（复算 `git log --oneline origin/develop..HEAD -- pubspec.lock` ⇒ 空）。
- 与 specs/062（PR !389）不撞同一文件：那笔改 `lib/state/nlp_date.dart`，本笔改 `_save()`，
  两边都不碰对方的文件（复算两条 `git diff --name-only` 的交集为空）。

## 七、矩阵回写

矩阵 #83 状态**不翻**：本 PR 未合并，且 specs/062 那半也没合。口径与上一轮一致 ⇒ 只能写「已实现、未合并」。
#83 说明格里"提醒那半缺"这一句要改成"已实现待合并（specs/063、#388、本 PR）"，
这条改动要落 docs，本轮没动 `!102`（它处于六道绿 + VERDICT PASS + merge-tree 无冲突、只等合并授权的状态；
为一个未合并的 PR 把它推回复核不划算），留在下一轮 docs 轮次做。

## 八、台账自扫（**跑的是副本**）

副本来源声明：`tool/check_spec_selfscan.py` 在本分支与 `origin/develop` 上都不存在
（复算 `git cat-file -e HEAD:tool/check_spec_selfscan.py` ⇒ `fatal: path 'tool/check_spec_selfscan.py' does not exist in 'HEAD'`），
它只在未合并的 `feat/361-calendar-list-timeline`（PR !364）里 ⇒ 本轮跑的是上一轮复制出来的
`/tmp/r119b/check_spec_selfscan.py`，**没有**为了自检把 `tool/` 塞进本 PR（那会与 !364 同文件相撞）。

- `python3 /tmp/r119b/check_spec_selfscan.py specs/063-nlp-create-reminder/tasks.md` ⇒ 失项 0 条
- `python3 /tmp/r119b/check_spec_selfscan.py specs/063-nlp-create-reminder/spec.md` ⇒ 失项 0 条
- `python3 /tmp/r119b/check_spec_selfscan.py --selftest specs/063-nlp-create-reminder/tasks.md` ⇒ 与期望不符的判据 0 条

写这三条读数用的是"先跑后抄"的顺序；若这三条里有任何一条被自己新写的句子判红，改法是去掉量词、
把结论落回它自己的复算命令（上一轮栽过的两类：`数量词 + 都已`、`数字 + 条 + 紧跟括号`）。

## 九、只读复核

**第 1 轮（只读，被审代码字节 `c977dc6`，其后只有一笔动 `specs/` 的台账笔 `f33ba74`）⇒ `VERDICT: PASS`，两条 NIT。**
判定只认 result 块里以 `VERDICT:` 开头的行（复算 `python3 /tmp/r125/verdict_from_result.py /tmp/r124/review-r1.jsonl`
⇒ 恰好一行 `VERDICT: PASS`）；整份日志 `grep -c "VERDICT: PASS"` 会把提示词里"最后一行必须是 VERDICT:"
那句要求一起数进来 ⇒ 不算判定（同一形状的坑记在 specs/019 第 3 轮）。

⚠️ **这一轮的取证面被削掉大半，这件事必须进账，不能只抄它的 PASS。**
`claude -p` 的文件访问只放行会话工作目录（本轮是 `/private/tmp/wt-fl-88`），所以它读 `/tmp/r124/*`
的门禁日志和 `/tmp/wt-docs/…/05-智能识别.md` 原文全被权限层拦下。拦了多少：
复算 `python3 /tmp/r125/review_tmp_access.py /tmp/r124/review-r1.jsonl` ⇒ 调用 31 次、成功 2、被拦 29。
它没有把没读到的说成读过（报告里逐节标了"沙箱拦截，未复算"），这一点属实。

**它自己现跑核过的**（这些不依赖 `/tmp`，每条在它报告里都带着命令）：语义裁定的代码依据、
`_nlpResolvedDueAt` 赋值点唯一（复算 `git grep -n "_nlpResolvedDueAt =" HEAD -- lib` ⇒ 1 行，落在 `_maybeResolveDate` 内）、部分成功状态机把失败路径都留在可见区、#289/#292 未被反向破坏、
四件套该项"未满足"属实、用例断言查的是库（复算 `grep -c "remindersOf(fixture.database)" test/features/task/quick_add_nlp_reminder_test.dart` ⇒ 3），
`git rev-parse HEAD:lib HEAD:test` 与 `c977dc6:lib c977dc6:test` 两两相同、
触达文件（复算 `git diff --name-only origin/develop..HEAD`）、`pubspec.lock` 未进本 PR、门 1 现跑 rc=0。

**它取不到、由我在同一台机器上补核的**（我有 `/tmp` 读权，它没有）：

- `cat /tmp/r124/head.txt` ⇒ `c977dc6c1b6e9de18e0764ddb1667a22e88d007b`，与 `git rev-parse c977dc6` 逐字相同；
  `cat /tmp/r124/summary.txt` ⇒ 六行 `rc=0`。
- 门 3/4/5 的读数逐字对第三节表格（`tail -2` 会把日志末尾那行 `rc=0` 一起带出来，故取 `grep` 形）：
  `grep -m1 "No issues found" /tmp/r124/g3_analyze.log` ⇒ `No issues found! (ran in 3.1s)`、
  `grep "All tests passed" /tmp/r124/g4_golden.log | tail -1` ⇒ `00:03 +9: All tests passed!`、
  同形命令跑 `g5_full.log` ⇒ `02:20 +902 ~26: All tests passed!`。
- 红测探针：`grep -c "\[E\]$" /tmp/r124/red1.log` ⇒ 3、`grep -oE "\+[0-9]+ -[0-9]+: Some tests failed\." /tmp/r124/red1.log`
  ⇒ `+1 -3: Some tests failed.`，同文件 `--- 还原校验 ---` 段有 `RESTORE-OK`、末段 `00:00 +4: All tests passed!`
  ⇒ 与第一节"红的是三条、绿的那条本该在旧代码上过"自洽。
- 判据源原文：`grep -c '!\[' /tmp/wt-docs/todo/99_参考资料/dida365-help-center/03-特色功能/05-智能识别.md` ⇒ 4、
  `grep -c "分钟" 同一文件` ⇒ 0；`sed -n '5p;13p' 该文件` 与 spec.md 引的 `:5`/`:13` 逐字相同
  （`:13` 末尾那个孤立「)」是原文自带的，不是我抄错）。
- 合并试算（它被拦）：`git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0、输出仅 1 行（无冲突段）。

### NIT 处置

| 复核员留的 | 处置 | 判据 |
| --- | --- | --- |
| NIT-1 判据源的 `!\[`/`分钟` 计数与在盘日志它未能独立复算，建议在有权读 `/tmp` 的环境补核 | 已按上一节逐条补核，读数与台账一致，无一项对不上 | 上一节那批命令现跑都在同一台机器上出数 |
| NIT-2 「窗口被拉长」写得不够精确：`_savedTaskId` 其实已把"建成功后再点"从建两遍降成只补提醒，真正没防的是**首次 `create` 飞行期内的双击** | 采纳。第四节那条已按它的口径改写：拉长的不是"再点会建两遍"，而是"弹窗存续期变长 + 飞行期双击仍会建两遍"；FL #391 的核心形状也改成后者 | 复算 `grep -c "_savedTaskId" lib/features/task/task_quick_add_sheet.dart` ⇒ 4（声明、写入、两处读取） |

## 十、下一轮入口

- 本规格：第 1 轮 `VERDICT: PASS` 已回填第九节，两条 NIT 也已处置 ⇒ 合并前置三格（门禁 rc 全 0 + 本 PASS +
  `git merge-tree --write-tree origin/develop HEAD` rc=0 无冲突段）齐了，**只等「合并」二字**。
  合并后要做的是把 `tool/check_spec_selfscan.py` 从 !364 挪进 develop 的那一轮里复跑一遍第八节三条读数
  （现在跑的是 `/tmp` 副本）。
- 复核通道 itself 的欠账（不属本面，但记在这儿免得忘）：`claude -p` 的会话工作目录只放行被审仓，
  下一轮起派单要带 `--add-dir /private/tmp`，否则第九节那种"复核员读不到在盘日志"的缺口每轮都要由我自己补核。
- 矩阵 #83 还欠的两处：specs/062 与 specs/063 合并后翻状态；FL Issue #390（带日期词丢分钟，develop 上就错）。
- **本面自己留下的那条**：FL Issue **#391**「快速添加『保存』无重入闸门，连点两次会建两遍任务」——
  第四节把它记成**未满足**而不是"不适用"，因为本面把一次 `await` 变成两次、窗口被拉长；
  develop 上的主张复算见那条 Issue 正文（`_applyingTemplate` 计数 4、`_saving`/`inFlight` 无输出）。
- docs 侧待办：#83 说明格补「提醒那半已实现待合并」与 #390 的指针；
  另有一条历史快照表（改判聚合表）里的 #83 行仍带着被 specs/062 第五节否掉的旧锚点，
  下一轮 docs 轮次要显式标它是快照、不是当前主张。

## 十一、第 145 轮：FL Issue #391 落地（§四 那条「未满足」的闭合）

分支 `fix/391-quick-add-save-gate`。实现只碰两个文件：
`lib/features/task/task_quick_add_sheet.dart` 与 `test/features/task/quick_add_save_reentry_test.dart`
（复算 `git diff --name-only origin/develop HEAD | tr '\n' ' '`）。

- 形状取 Issue #391 列的第二种：`_save()` 入口 `if (_saving) return;`，原实现改名 `_saveOnce()`
  并包在 `try/finally` 里复位。选它的理由是不动视觉 ⇒ §四 那套量法不必再扩一项；代价写在下面。
- 红测先红在哪：`flutter test test/features/task/quick_add_save_reentry_test.dart` 在实现前给
  `Expected: <1>` / `Actual: <2>`，失败点是**第二次点击之后**那条断言；第一次点击后的
  `createCalls == 1` 先通过，说明飞行窗口是真的，不是在测空气。
- 反向探针把两条用例分开了：只摘掉 `finally` 里的复位、保留入口早退 ⇒ 第一条仍绿，
  第二条变 `Expected: <2>` / `Actual: <1>`（第二次点击被吞 = 按钮锁死）。
  探针字节用 `cp` 备份、`cmp -s` 还原，输出 `restored byte-identical rc=0`。
- 实现后同一条命令：`00:00 +2: All tests passed!`。
- 六道门禁跑在已提交字节上（head 写在日志首行），日志 `/tmp/r136/gates391.log`；
  复算 `grep -E '^gate[1-6] rc=' /tmp/r136/gates391.log` ⇒ 六个 rc 全 0。

| 项 | 读数 |
| --- | --- |
| 1 `git diff --check origin/develop HEAD` | rc=0。跑在差集上而不是工作树上：提交后工作树是干净的，空跑不带信息 |
| 2 `dart format --output=none --set-exit-if-changed` + 两个 .dart 的字面量路径 | `Formatted 2 files (0 changed)`、rc=0。这里的 2 要等于 `git diff --name-only origin/develop HEAD -- '*.dart' \| wc -l` |
| 3 `flutter analyze` | `No issues found! (ran in 3.5s)`、rc=0 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、rc=0，基线 9 张没重录（`find test -name '*.png' \| wc -l` ⇒ 9） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:06 +1198 ~26: All tests passed!`、rc=0。1198 里 2 条是本轮新增（单文件跑 ⇒ `+2`），余下 1196 是本分支基线字节上的数，本轮没单独复跑基线，所以这个拆分是从两次读数相减得来的 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、rc=0 |

- 卫生：`status_before_gates=[]` 与 `status_after_gates=[]` 都在同一份日志里（第 45 轮复核立的
  规矩：只记 head 不记工作树，`pubspec.lock` 就会漏进提交）；`### lock_in_pr=0`、`goldens_dirty=0`。
- 这把尺本身是活的：`python3 tool/check_spec_selfscan.py --selftest specs/063-nlp-create-reminder/tasks.md`
  ⇒ `与期望不符的判据 = 0 条`，里面既有"期望红→实际红"也有"期望绿→实际绿"的对照。
  反面记账：我自己手工注入的坏样本这次**没**被判红，因为注入的行不触发任何一条词表判据
  ⇒ 那种绿不含信息。判"尺是活的"只认上面 `--selftest` 那条读数，不认我手投的样本。

## 十二、本轮仍留的（不谎称完成）

- 飞行期的第二次点击是**静默吞掉**，没有任何可见反馈。判据源《02-功能指南/01-任务/01-添加任务.md》
  逐字只写「点击随处可见的「+」，输入任务后，点击「完成」图标，即可轻松创建任务」，
  没有规定重复点击的行为 ⇒ 这条不能拿嘀嗒原文当依据，只是健壮性收口。
  是否换成形状 A（按钮 in-flight 置灰）要先补一条「禁用态仍在可见区」的量法，
  本轮不自行加视觉态；等 FL Issue #391 那条 PR 的第 1 轮只读复核意见再定。
- 交叉验证通道：第一次派发回 0 字节（按「没执行」记账），补跑那次回了 5334 字节、
  带 `CROSSCHECK:` 一到四。它的第 3 条主张「提醒段飞行期连点没有对称断言」**判为不成立**，
  理由是代码形状：闸门的 `if (_saving) return;` 包在 `_save()` 外层，而
  `await reminders.create(...)` 就在 `_saveOnce` 里（复算
  `grep -n "await reminders.create" lib/features/task/task_quick_add_sheet.dart`），
  同一个标志覆盖两段 await ⇒ 行为上没有缺口，它指的只是用例覆盖面。
  同目录既有用例 `quick_add_nlp_reminder_test.dart` 里那条「提醒没建成 ⇒ 再点保存不建第二遍任务」
  也钉着这条路径（复算 `grep -n "再点保存不建第二遍任务" test/features/task/quick_add_nlp_reminder_test.dart`）。
  其余三条（静默无反馈是 B 的代价、`finally` 在 pop/dispose 后写标志安全、`_savedTaskId` 语义未被破坏）
  与我自己读码的结论一致，采纳为第二意见但不当 VERDICT。
- 矩阵不翻：本轮 PR 未合并，#7「添加任务」与 #83「智能识别」两行的状态仍等合并后
  由 docs 轮次按已合并 SHA 收口。

## 十四、PR !412 的第 2 轮 `VERDICT: PASS` 与合并事实（第 156 轮，2026-09-30）

!412 = FL Issue #391「快速添加的『保存』无重入闸门」，它把 §十三 记的那条『四件套该项被本轮改动拉长 ⇒ 记未满足』真正补上了。第 2 轮只读复核报告 `/tmp/r136/review-412-r2.result.md`：A（闸门本身）、B（用例咬得住，含反向探针留痕）、C（门禁读数）、D（覆盖面与 sha）、E（诚实性）、F（判据器）六节全 PASS，结论 `VERDICT: PASS`。

复核留的 NIT-2（「静默吞二次点击」这一代价只在 §十二 有一句话，没归进可追踪待办；换形状 A『置灰』要先补『禁用态仍在可见区』的量法）处置：本条不改代码，先按复核建议在**这里**登记为可追踪项，留给后续轮决定是否换成置灰；不在本轮顺手改形状，避免把一次闸门修复扩成界面重构。

合并：!412 合进 develop，合并提交 `aee15c06f7`。合并产物门禁同 §十四 的口径：一次性 worktree `/private/tmp/wt-fl-mp412` 真 merge 后 `flutter analyze` rc=0（`/tmp/r152/mp412-analyze.log`）、全量 `flutter test` 得 `03:17 +1249 ~26: All tests passed!` rc=0（`/tmp/r152/mp412-test.log`）。
