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
- 门 3/4/5 的读数逐字对第三节表格：`tail -2 /tmp/r124/g3_analyze.log` ⇒ `No issues found! (ran in 3.1s)`、
  `tail -2 /tmp/r124/g4_golden.log` ⇒ `00:03 +9: All tests passed!`、
  `tail -2 /tmp/r124/g5_full.log` ⇒ `02:20 +902 ~26: All tests passed!`。
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
