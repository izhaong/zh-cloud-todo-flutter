# 045 · 台账（批次 1）

分支 `feat/375-keep-loaded-on-error`，基线 `origin/develop` = `90320057c`。
提交：`c234e34`（实现 + 用例 + spec/plan）→ `f24f122`（补 FR-004 防回归用例，取交叉验证意见）。
**门禁与探针全部跑在 `f24f122` 的字节上**（探针结束后复算 `git diff HEAD` = **0 字节**、`git status --porcelain` = **0 行**）。

## 一、红→绿顺序

1. 先写一次性量测探针 `test/features/habit/habit_page_probe_test.dart`（**不入库**，用完删除），
   在 develop 字节上跑 ⇒ 红在「刷新失败不该丢掉已加载的列表」那条断言上。
   这一步是为了**不靠猜**回答「Riverpod 到底保不保留 value」。
2. 形状量测（监听者在场，`invalidate` 后重取失败）：
   `kind=AsyncError isLoading=false hasValue=true valueOrNull≠null hasError=true`
   ⇒ 丢数据的是 `.when` 分支判别。该形状现由 `habit_page_test.dart` 第 1 条用例钉住，探针文件已删。
3. 改读法 → 9 条用例全绿（下表 §二）。

## 二、六道门禁（日志 `/tmp/gates-375/r2/`，产出器 `gates.sh`）

| 门禁 | 读数 | 日志 |
| --- | --- | --- |
| 1 `git diff --check` | rc=0（无空白错误） | `g1_diffcheck.log` |
| 2 `dart format --output=none --set-exit-if-changed` ×5 显式文件 | rc=0，`Formatted 5 files (0 changed)` | `g2_format.log` |
| 3 `flutter analyze` | rc=0，`No issues found!` | `g3_analyze.log` |
| 4 `flutter test --tags golden` | rc=0，`+9` ⇒ **9 张基线一张没重录**（基线全在 `test/goldens/todo_workspace/`，本面不触及） | `g4_golden.log` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0，`+907 ~26 All tests passed!` | `g5_full.log` |
| 6 `flutter build web --release --dart-define=…todo-test… --dart-define=TODO_TENANT_ID=1` | rc=0，`✓ Built build/web` | `g6_build.log` |

**基线比对**（不然分不清"存量红"与"我引入的"）：同一命令跑在 `origin/develop@9032005`
（一次性 worktree `/private/tmp/r68-baseline`）⇒ `+898 ~26 All tests passed!`（日志 `/tmp/gates-375/baseline.log`）。
907 − 898 = **+9** = 本分支新增用例数（习惯页 6 + 倒数日 3），且 develop 侧 0 红 ⇒ 没有存量欠债被本面掩盖。

⚠️ 一次性踩坑（如实记）：`dart format` 那两次的 `rc=0` 差点是假的——
第一次我把文件列表塞进 shell 变量 `$FILES`，zsh **不做词切分** ⇒ `dart format` 收到一个
"含空格的超长文件名"，报 `No file or directory found` 却仍然 `rc=0`（它格式化了 0 个文件）。
判据必须是 **`Formatted 5 files`** 这半行，不是 rc。第二次改成显式列文件才真跑。

## 三、反向探针（证明用例有牙齿；脚本 `/tmp/gates-375/r2/probes.sh`）

| 探针 | 做法 | 读数 |
| --- | --- | --- |
| PA | `lib/features/habit/habit_page.dart` 退回 develop 字节 | 6 条里 **5 红**：「刷新失败保留已加载的列表与统计」「首值就没读到才走失败态，「重试」成功后恢复列表」「FR-004 防回归」「提示条有独立读屏语义」「320px + 1.3 倍字号」；`PA_RESTORE_IDENTICAL` |
| PB | `lib/features/countdown/countdown_page.dart` 退回 develop 字节 | **3 红**（该文件全部 3 条）；`PB_RESTORE_IDENTICAL` |
| 还原 | 两文件合跑 | `+9 All tests passed!`（`restored.log`） |

PA 下**唯一不红的**是「两次连发刷新：过期的旧响应不得覆盖新响应」⇒ 它是**参考面**不是判据面：
那条测的是框架自身的行为（被顶替的 future 的结果不会覆盖新值），与本面的 `valueOrNull` 改法无关，
它在 develop 字节上也该绿。绿 = 不覆盖，**不等于**本面机制无病灶（这条判据由 PA 的其余 5 红承担）。
FR-004 那条在 PA 下变红的原因是列表侧的「重试」按钮同属本面新增（develop 的列表失败态只有一行错误文本）。

⚠️ 探针自己造的第二个坑（如实记）：`git checkout origin/develop -- <path>` **会把 develop 字节写进索引**，
`cp -p` 还原只还原工作树 ⇒ 跑完探针后 `git status` 是 `MM`，若当时直接 `git commit` 就等于
把"被审实现"退回 develop。已 `git restore --staged <两个文件>` 清掉，并复算
`git status --porcelain` = 0 行、`git diff HEAD` = 0 字节。
**配方修正**：探针脚本里改用 `git show <ref>:<path> > <path>`（只动工作树），或还原后强制 unstage。

⚠️ 本轮还自造过第三个坑（同属"写台账"这一步）：往 `tasks.md` 补内容时用了**不带引号的 heredoc**，
markdown 里的行内代码反引号被 zsh 当成命令替换执行 ⇒ 那两条判据被掏空成
「产出 tree 〈空〉」「`ls tool/` 只有 〈空〉」。已在**提交前**发现并整段重写
（复算：`grep -n "产出 tree" specs/045-keep-loaded-on-refresh/tasks.md` 现在指得出 sha）。
**配方**：写含反引号的中文 markdown 时，heredoc 分隔符一律加引号（`<<'PY'`），或用编辑工具逐段替换。

## 四、交叉验证（cursor CLI，与 VERDICT 不互替）

`cursor-agent --trust -p`（提示词 `/tmp/gates-375/crosscheck.txt`）⇒ 输出 **4075 字节**、
哨兵 `grep -c CROSSCHECK` = **1**（判成败只看字节数与哨兵，不看 exit code）。
两个待判取舍的结论，逐条回源复验后处置：

| 待判 | 它的裁决 | 我的复验与处置 |
| --- | --- | --- |
| J1「统计格首屏失败仍不渲染 = 缺陷漏了一半」 | **不成立**（首屏没有可保留的旧值，不属 keep-loaded 缺陷类）；但它指出**本批没有钉 FR-004 的用例** | 采纳它指的那处缺：补 `FR-004 防回归` 用例（`f24f122`）。判断本身与 spec FR-004 一致，不改口径 |
| J2「`calSubscription` 的失败以 data 到达 ⇒ `valueOrNull` 无效」 | **成立**，并给出最小修法（provider 去 catch + 页面同形读法 + 停用 `s.error` 整页盖列表） | 与 plan 取舍 5 一致 ⇒ 修法照抄进批次 2 的入口（§七） |

## 五、矩阵与 docs：**本轮不改**（不是遗漏，是不该改）

本面不是嘀嗒的功能面，对照矩阵没有对应行；`zh-cloud-docs` 一字未动。
复算：`git diff --name-only origin/develop..HEAD` 见 §六，其中没有任何矩阵/docs 路径。
FL Issue **#375** 已用留言订正两点（前提坐实、`calSubscription` 机制不同）＝ comment id 9822。

## 六、触达文件（`git diff --name-only origin/develop..HEAD`）

`lib/core/widgets/app_widgets.dart`、`lib/features/countdown/countdown_page.dart`、
`lib/features/habit/habit_page.dart`、`specs/045-keep-loaded-on-refresh/{spec,plan,tasks}.md`、
`test/features/countdown/countdown_keep_loaded_test.dart`、`test/features/habit/habit_page_test.dart`。
**`pubspec.lock` 不在其中**（复算 `git log --oneline origin/develop..HEAD -- pubspec.lock` 应为空）。

## 七、只读复核 VERDICT 与下轮入口

- [ ] 只读复核（`claude -p`，被审 head `f24f122`）——回来后把轮次、被审 SHA、失项逐条处置写回本节。
- [x] 合并前置的机械项已齐：六道门禁 rc=0（§二）+ 反向探针（§三）+ 真实合并试算。
      试算命令 `git merge-tree --write-tree origin/develop f24f122` ⇒ rc=0，
      产出 tree `da64de837f8407ffe6599a11c9ac2df962f3a4ef`，与 `git rev-parse f24f122^{tree}` 逐字节相等
      ⇒ 对 develop（`90320057c`）快进零冲突。试算跑在**代码终态** `f24f122` 上；
      本台账这一笔只动 `specs/045-keep-loaded-on-refresh/`（markdown 不参与合并冲突面）。
- [x] 台账自扫判据：`python3 tool/check_spec_selfscan.py specs/045-keep-loaded-on-refresh/tasks.md`
      ⇒ 读数「失项 0 条」，rc=0。
      ⚠️ 诚实登记：这台判据器**目前不在 develop 上**——develop 的 `ls tool/` 只有
      `test_jenkinsfile_runtime_contract.sh`，`check_spec_selfscan.py` 只存在于未合并的 PR !364 分支。
      本轮跑的是那份分支的副本（`/tmp/wt-fl-361/tool/check_spec_selfscan.py`）⇒
      !364 合并后应以仓内那一份对本台账复跑一次。

- **矩阵 #19/#45 等行的状态不因本面翻转**：#375 是客户端健壮性欠账，不是嘀嗒功能面。
- **批次 2**（#375 剩余 A 组）：`taskAssign`/`listMembers`/`taskComments` 三处按同一形改读法；
  日历订阅页按 §四 J2 的修法（去 catch 让 `AsyncError` 可达 + 同形 `valueOrNull`/提示 + 停用 `s.error` 整页盖列表）。
  ⚠️ 每一处**先跑「出过值 → 再失败」探针**再决定修不修：!351 第 2 轮复核把本面三处判成「无保留值语义」，
  而实测证明那是同一个病灶 ⇒ 静态读判不准这一口径要带进批次 2。
- **批次 3**：B 组 5 处 `StreamProvider`（#353 口径）。
- 顺带发现、**不在本轮**：`recommendation_panel.dart:151/167` 已有同形 `liveRegion` 提示（已合并先例），
  但 `achievement_wall`/`inbox` 等页的失败态是否也走 `.when` 折值，留给批次 2 的探针清账。
