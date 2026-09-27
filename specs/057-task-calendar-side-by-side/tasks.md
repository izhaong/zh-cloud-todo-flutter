# 057 · 任务与日历同时显示 — 执行台账

基准：`zh-cloud-todo-flutter` `origin/develop@90320057c836841bf6e4dce2f2923e0725cf275d`
分支：`feat/379-task-calendar-side-by-side`（工作树 `/tmp/wt-fl-379`）
Gitea：Issue #379 · 判据源见 `spec.md` §一

## 一、本轮范围（只做开关 + 并列布局）

源页 `:17`/`:21`/`:27`/`:31`/`:39` 五句 = 三个菜单项 + 两条排布 + 一条关闭路径。
`:45-63`「拖动排期」四面**不在本轮**，另立单（见 §八）。

改动落点四件事：`lib/features/home/workspace_companion.dart`（新增：三态枚举 + 存储 +
`NotifierProvider`）、`todo_workspace.dart`（模块图标右键 + 副栏槽位）、
`home_shell.dart`（菜单与方向决策、`_buildContent` 拆成 `_buildPane(Section)` 让主副两栏共用一份渲染）、
`test/features/home/workspace_companion_test.dart`（新增）。

## 二、六道门禁读数（第 113 轮：修复后的最终字节各跑一次）

第 109 轮那张表量的是 `dedd329` 的字节；本轮 G 项改了 `lib/features/home/home_shell.dart`、
并给 `test/features/home/workspace_companion_test.dart` 加了一条用例 ⇒ **整表作废重跑**。
日志目录 `/tmp/r114/`，跑法 `bash /tmp/r114/gates.sh`（命令序列与 `/tmp/r109/gates.sh` 一致，
只去掉 g0 原地格式化、换日志目录），每条 rc 单独落 `/tmp/r114/rc.txt` ⇒ 六条全 0。

| 门禁 | 命令 | 读数 | 日志 |
| ---- | ---- | ---- | ---- |
| g1 | `git diff --check` | rc=0、输出 0 字节（`/tmp/r114/g1-final-size.txt:1`）。**它先红过一次**：本节写完时文件尾多了一个空行 ⇒ rc=2、正文 `new blank line at EOF`，删掉后复跑才 0；那次红没单独留档（留的是修完后这次），写在这里是为了说明"0 字节"不是第一次读数 | `/tmp/r114/g1-diffcheck-final.log` |
| g2 | `dart format --output=none --set-exit-if-changed <本轮 4 个文件>` | rc=0、`Formatted 4 files (0 changed)` 在 `/tmp/r114/g2-format.log:1` | `/tmp/r114/g2-format.log` |
| g3 | `flutter analyze --no-pub` | rc=0、`No issues found!` 在 `/tmp/r114/g3-analyze.log:2` | `/tmp/r114/g3-analyze.log` |
| g4 | `flutter test --tags golden` | rc=0、`+9: All tests passed!` 在 `/tmp/r114/g4-golden.log:75`（全文 75 行） | `/tmp/r114/g4-golden.log` |
| g5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0、`+916 ~26: All tests passed!` 在 `/tmp/r114/g5-test.log:1174`（全文 1174 行） | `/tmp/r114/g5-test.log` |
| g6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web` 在 `/tmp/r114/g6-build.log:81` | `/tmp/r114/g6-build.log` |

跑门禁的字节 = 本轮提交前的工作树；`git status --short | wc -l` 在六条跑完后仍是 **4**
（`/tmp/r114/porcelain-count.txt:1`，逐行清单见 `/tmp/r114/porcelain-final.txt`）⇒ 只有本轮那 4 个文件，
`pubspec.lock` 没被 `pub get` 顺手改写、也没随 PR 带出去。

用例数不是靠减法推出来的：基线在**被测对象副本**上直接跑
（`/private/tmp/r68-baseline` 检出 `origin/develop@90320057`），
统计行 `+898 ~26: All tests passed!` 在 `/tmp/r109/baseline-develop.log:1152`（全文 1153 行）；
本轮没重跑基线，因为**基的 ref 没动**：`git rev-parse --short=8 origin/develop` ⇒ `90320057`
（复算于本轮，`/tmp/r114/develop-tip.txt:1`）。
本分支同一命令 ⇒ `+916 ~26`（`/tmp/r114/g5-test.log:1174`）。
对上 `898 + 18（本轮该文件实跑用例）= 916`；`~26` 跳过数两边相同 ⇒ 本轮没动任何 skip。

基线承诺的可验读数（V5）：`ls test/goldens/todo_workspace/*.png | wc -l` ⇒ **9**
（`/tmp/r114/g4-golden-png-count.txt`），且 `git status --short test/goldens` ⇒ **0 行**
（`/tmp/r114/g4-golden-drift.txt` 为空文件）⇒ 9 张基线一张没重录、也没被改写。
⇒ 矩阵 #32 旧格那句「属会改可见布局的一档（动 9 张黄金基线要先申请）」被实测否掉：
默认态不动基线，因此本轮**不需要**请示重录。

用例数两个口径别混：`grep -c "  testWidgets(\\|  test(" test/features/home/workspace_companion_test.dart`
⇒ 声明 **13** 处（改前 12，见 `spec.md` §三.6 那条 G 项修复）；
`flutter test <本文件>` 的统计行 `+18: All tests passed!` 在 `/tmp/r114/green-file.log:84`（全文 84 行）
⇒ 实跑 **18**（循环展开出来的 5 条只在运行时成为用例）。对账用 **18**。


## 三、反向探针（证明方向断言不是恒绿）

把 `_contentWithCompanion` 里的副栏从右侧挪到左侧（`todo_workspace.dart`，一次互换）后跑本文件。
**第 113 轮在修复后的字节上重跑过一次**：统计行 `+13 -5: Some tests failed.` 在
`/tmp/r114/probe-left.log:209`（全文 216 行），红行数 `grep -c "^0[0-9]:.*\[E\]$"` ⇒ **5**
（`/tmp/r114/probe-red-count.txt:1`）——**条数和第 109 轮相同**：本文件多出来的那条
"切去习惯"用例只测写盘与恢复，不受几何互换影响 ⇒ 它绿是对的，不是探针漏了它。
这 5 条正是三条"副栏必须在主区右侧"的几何断言加两条还原用例。
还原：`cp /tmp/r114/todo_workspace.dart.bak` 回来并 `filecmp.cmp(..., shallow=False)` ⇒ `RESTORE_IDENTICAL`，
`git status --short` 回到"只有本轮 4 个文件"，复跑 ⇒ `+18: All tests passed!` 在
`/tmp/r114/after-restore.log:84`（全文 84 行）。⇒ 这把尺子开过火，且量的是最终字节。
第 109 轮那次（`/tmp/r109/probe-left.log:205`，当时全文 212 行）跑的是 `dedd329` 的字节，已被本轮取代。


## 四、交叉验证（cursor-agent，第二个意见真的改写了结论）

`cd /tmp/wt-fl-379 && cursor-agent --trust -p "$(/bin/cat /tmp/crosscheck-379-anchor.md)"`
⇒ 输出 **4972 字节**、`grep -c "CROSSCHECK:"` ⇒ 1（`/tmp/crosscheck-379-anchor.out`）。

- **它推翻了我的一条前提**：我写 Issue 正文时只查了 `sidebar.dart`，据此断言
  「源页的『模块图标』在现有 IA 里没有字面对应物」，并准备了 A/B/C 三条候选锚点。
  它指出 `todo_workspace.dart:395` 的 `for (final item in Section.values) _RailButton(...)`
  就是任务/日历/习惯/我的四个模块图标。我回源复验为**真**（同一命令形态可自行复算，见 `spec.md` §三 1）
  ⇒ 锚点问题不存在，不改 IA，A/B/C 三条连同它给的 C>A>B 名次一起作废。
- **采用的两条**是它独立成立的部分：① 方向要进偏好枚举（只存布尔还原不出主从）；
  ② 窄屏按"布局档位降级"处理，静默降级、不清空偏好——它引的先例我复算过：
  详情容器在 宽栏/endDrawer/全屏路由 间静默切换（`home_shell.dart` 的 `_syncLayoutProfile`、
  `_MobileTaskDetailRoute`），而"能力不可用"才给可见提示。
- 它有一处**没验**：说 `todo_workspace.dart:395-404` 的 `item.label` 含「任务」——这条我复算为真；
  但它同时说侧栏行区间是 `:90-350`，我上一版回「实测 13 行的 `label:` 在 `:94..:348`」——
  **驳它用的这把尺子本身是错的**：`git show origin/develop:lib/features/shell/sidebar.dart | sed -n '94,348p' | grep -c "label: "` ⇒
  **14**，多的那行是 `:276`「新建清单」那颗按钮的 `label: Text(`，不是行标签。
  侧栏行数 13 这件事没错，但按 `label:` 量不出来 ⇒ 判据已换成按构造函数收口，见 `spec.md` §二 4。
  第 1 轮复核把这条记为 E-1（记在 §七）。

## 五、本轮自己写错、并当场改掉的两条

1. **两条"窄屏不给并列菜单"的用例前提就是错的**：我按"窄屏也有模块图标、只是不给右键"来写，
   实测 `find.byKey(Key('todo-rail-item-tasks'))` 在 mobile/mobile-min 下 **0 个** ⇒
   报 `could not find any matching widgets`。真实现状是窄屏连左轨都不渲染（模块切换走底部导航），
   "不给菜单"不是一条守卫而是没有这个入口。用例已改成断言"轨道不存在 + 无副栏 + 不写偏好"，
   并在 `spec.md` §三 4 记实测。
2. **一次 format 判据被管道尾部的 rc 顶替**：我先跑
   `dart format ... | tail -6; echo rc=$?`，读到的 0 是 `tail` 的 rc；
   而 `dart format --set-exit-if-changed` 对未格式化文件该回 **1**。
   把 4 个文件真格式化后再量，`g2` 才是真的 rc=0。（同族坑：zsh 不切词，
   用 `$F` 传文件列表会得到 "No file or directory found"，两次读数都作废。）

## 六、台账结构自检

判据是 FL !364 带的 `tool/check_spec_selfscan.py`（**develop 上还没有这个文件**，
故用其分支副本跑：`/tmp/wt-fl-361/tool/check_spec_selfscan.py`，md5 `45ba425aeb561edb7d6403763b94e6fa`）。
复算命令：`python3 /tmp/wt-fl-361/tool/check_spec_selfscan.py specs/057-task-calendar-side-by-side/tasks.md`
⇒ 读数不凭记忆写：每次改完当场复跑，把日志路径与失项数记在下面的 bullet 里（跑一次算一次）。

- **第 109 轮：这条回填从来没有** ⇒ 第 1 轮复核记为 **E-2**（台账自己承诺的流程违约）。
  当时 §六 只留了一句"读数记在 §七 之后"，而 §七 里没有自扫读数 ⇒ "自扫 0 失项"当轮不成立。
- 第 113 轮（本轮修复后）复跑：`python3 /tmp/wt-fl-361/tool/check_spec_selfscan.py specs/057-task-calendar-side-by-side/tasks.md`
  ⇒ rc=0、`失项 0 条`，日志 `/tmp/r114/selfscan-2.log`；写下这条引用之后**又跑了一次**验它没把自己改红
  ⇒ `/tmp/r114/selfscan-3.log` 同样 `失项 0 条`。**这两处故意不带行号**：带了就成了自我指涉（见下条）。
- **它抓得到自引，别把它的绿当万能**：本节这条引用最初写成"指向本次运行那份日志的第 1 行"，
  它当场报 `锚点越界：该文件只有 0 行`（那一次 `失项 1 条`，全文 2 行，读数在
  `/tmp/r114/selfscan-final.log:2`）——本次运行的日志在本次运行时当然还没落盘。
  改成"引用上一次跑完的日志"后才放绿。⇒ 同一个文件同一节，一处红一处绿 ⇒ **它是会红的尺子**，
  只是照不到 E-1、E-2 那两类。

- **这条绿灯的边界必须先划清，否则 E-2 只是换了个说法**：把修复前那版 tasks.md 原样复制进同目录
  （`specs/057-task-calendar-side-by-side/tasks-headcopy.md`，跑完即删）再扫一次 ⇒ 同样 0 失项
  （`/tmp/r114/selfscan-control2.log:1`，复算 `python3 /tmp/wt-fl-361/tool/check_spec_selfscan.py specs/057-task-calendar-side-by-side/tasks-headcopy.md`）。
  ⇒ **判据器看不见 E-1 那类错**（"数字与它所绑命令的真实输出不一致"不在检查面里），也看不见 E-2
  （不校验"承诺回填"有没有兑现）。本轮 0 失项只证明结构面没退步；E-1/E-2 是只读复核员抓出来的，
  给判据器补这两条规则另立事项（见 §八）。


## 七、只读复核 VERDICT

### 第 1 轮（被审 ref = `dedd329`）⇒ `VERDICT: FAIL`

- 派单：`claude -p`；提示词 `/tmp/verdict-379-r1-prompt.md`；结论日志
  `/tmp/verdict-379-r2-dedd329.log`（首派 `verdict-379-r1-dedd329.log` 只留下 1 字节，
  同一 ref 重派才拿到正文 ⇒ 那份重派记为本轮结论）。
- 判读只认结论正文里的 `VERDICT` 行 ⇒ `/tmp/verdict-379-r2-dedd329.log:67`。功能面静态核查全过
  （默认态字节等价、6 文件边界、快进结构、方向布局、文案无同义词、先例存在），
  FAIL 全部出在**台账可复算性与记录诚实度**。
- 复核员自报的环境限制照抄在此，不替它遮：它的 `flutter test` / `flutter analyze` /
  `check_spec_selfscan.py` / `git merge-tree` 全被权限层拦下，`/tmp/r109/*` 与 docs 源页读不到 ⇒
  它把 §二/§三 的实跑读数与源页逐字对照一律标「无法验证」，并明确说这些**不计入 FAIL、也不构成 PASS 依据**。
  ⇒ 因此 §二 那张表只能由我在本机复跑背书，第 113 轮已整表重跑（见 §二）。

| 它的判定 | 我的复算 | 处置 |
| --- | --- | --- |
| **E-1** §二.4 与 §四 把「13 行」绑在 `grep -c "label: "` 上，复算为 22 / 区间 14 | **成立**：`git show origin/develop:lib/features/shell/sidebar.dart \| grep -c "label: "` ⇒ 22；同文件 `sed -n '94,348p'` 后同命令 ⇒ 14；`grep -cE '^\s+_(Smart\|Nav)Row\($'` ⇒ 13 | 已改：结论（13 行、模块只有日历）不动，判据换成按构造函数收口的那条，两处账都写清（`spec.md` §二.4、本文 §四）。它把这称作"两处 off-by-one"，**这半句我复算不成立**：22 与 13 差 9 处，是别处同名的 `label:` 参数（清单见 `spec.md` §二.4 那条 ⚠️），不是差一行 |
| **E-2** §六 承诺的自扫读数没回填 | **成立**：第 109 轮那份 §六 只有一句"读数记在 §七 之后"，而 §七 当时是空的 | 已改：§六 改成"跑一次算一次、读数记在 bullet 里"，本轮真跑真填 |
| **G** §三.6 偏离的理由（「并列会把习惯/我的遮住」）与实现里的 `pairEligible` 矛盾，且存在更贴源页的写法 | **成立**：`home_shell.dart` 的 `pairEligible` 已把副栏限在 `Section.tasks`/`Section.calendar`，切去习惯/我的不会被盖住 ⇒ 那句理由是假的，而代码照它写了一遍 | 已按它的建议改成**只闸不写**：删掉 `_selectSection` 里那段 `apply(WorkspaceCompanion.off)`，补一条用例钉「切去习惯再切回任务，并列按记忆恢复、切模块不改写偏好」。这段代码改前**零覆盖**：`git show HEAD:test/features/home/workspace_companion_test.dart \| grep -c habit` ⇒ 0。用例改前红在写盘次数（`/tmp/r114/red-habit-restore.log:83` 给 Expected 1、`/tmp/r114/red-habit-restore.log:84` 给 Actual 2，统计行 `/tmp/r114/red-habit-restore.log:114`），删掉那段后同一文件绿（`/tmp/r114/green-file.log:84` ⇒ `+18: All tests passed!`） |
| **A/B/C/D/F/H** 判「成立」但实跑读数无法复验 | 不采信为 PASS 依据，也不当作缺陷 | 第 113 轮在最终字节上整表重跑六道门禁（§二），把它的「无法验证」在我这边变成有日志的读数 |

### 第 2 轮（被审 ref = 本轮修复后的 head）

- 状态：**待派**。修复提交推上去之后再派，判据只看结论正文的 `VERDICT` 行；
  两轮无新结论就停下请示，不刷循环求绿。


## 八、下一轮入口

- **本轮（第 113 轮）出口**：§七 第 1 轮 FAIL 的三条已修（E-1 判据换掉、E-2 自扫补回填、G 改只闸不写），
  修复后的 head 要重新派第 2 轮只读复核；矩阵 #32 那句 PR head SHA 也随之漂移 ⇒ 在 docs `!102` 分支上追平。
- 源页 `:45-63`「拖动排期」四面（拖进日历 / 拖进清单详情 / 拖到清单或标签 / 拖到智能清单）
  另立 Issue；`calendar_view.dart`、`timeline_view.dart` 已有 Draggable，先判定现有拖拽覆盖面再动手。
- 矩阵 #32 在合进 develop 前保持「无」，说明列可写「已实现、未合并」（校验器拒「待合并」字样）。
- 本单没碰后端契约：并列是纯客户端布局，`todo_list`/`todo_task` 都不需要新列。
- **判据器缺口**（本轮实测出来，见 §六 划边界那条）：`tool/check_spec_selfscan.py` 不校验
  「台账里的数字与它所绑命令的真实输出是否一致」，也不校验「承诺回填的读数是否兑现」⇒ E-1、E-2 这两类它一路放绿。
  要补就得让它真去跑台账里的命令再比对读数（它现在只做静态形状检查）⇒ 先立 Issue 记着，
  **不在本轮顺手改这份共享脚本**：它在 !364 分支上的版本正被多条在途台账依赖，改了会把别人的台账扫红。
