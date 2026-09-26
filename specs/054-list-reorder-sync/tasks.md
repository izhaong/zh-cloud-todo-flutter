# 任务清单：清单排序（上移/下移）要登记同步 outbox（specs/054 / FL Issue #341 / 矩阵 #19）

分支 `feat/341-list-reorder`，基线 `origin/develop@9032005`，PR !367。
提交 `2f98e2f`（实现 + 用例 + 规格）、`186527f`（门禁 3 报的 5 条 lint，只动新测试文件）。

## 完成情况

- [x] `spec.md` 来源表：《02-用清单管理任务》`:78`（左滑 → 置顶 / 编辑 / 删除）逐字引用（基准 docs `origin/develop`）
- [x] 现状取证：develop 的 `ListRepository.reorder`（`list_repository.dart:163` 起、13 行）**只写本地
      `sortOrder`、一次 `_queue.enqueue` 都没有** —— 同文件**其余五个**写方法各有且仅有一条
      （develop：`create:85` / `rename:103` / `moveToFolder:141` / `delete:181` / `saveSmart:212`），
      唯独这条写路径漏；所以「本地改得动、换端后顺序回滚」是**代码事实**，不是猜测。
      ⚠️ 但**不是用户今天遇到的缺陷**：入口页 `ListPage` 在 `lib/` 内零引用、无路由 ⇒ 潜伏缺陷
      （第 1 轮复核 C-2，指回 `specs/026-todo-sidebar-list-management/spec.md:9-10`）
- [x] FR-1 每条被改位次登记一条 `list`/`upsert`；FR-2 整批包 `_db.transaction`（先例 `moveToFolder` 的事务，develop `:118`）；
      FR-3 不吞不存在的 id 且**位次不留空洞**；FR-4 零 UI 变更
- [x] FR-5 置顶本面不做，并已开后端契约单 **service#289**（清单表根本没有 `isPinned` 字段，
      只 `TodoTasks` 有；BE `AppTodoListBaseVO` 只 `name`+`sortOrder`）⇒ 按「先修契约再动前端」，
      这一项**不在本面假装实现**
- [x] payload 取自**读回的那一行**（`moved.toJson()`）而不是传入参数拼的 —— 理由与取舍见 `spec.md` 六-2
- [x] 四件套：①320×568 + 1.3 **不适用**（FR-4 零 UI，不编造测量）；②独立读屏语义 **不适用**（同上）；
      ③失败保留已加载数据 = 本面主断言（Y2/Y3 两条用例）；④过期响应不覆盖新响应 **不适用**
      （写路径、无新增流，理由见 `spec.md` 五-4）
- [x] 反向探针四条 Y1–Y4 + **作用域化**成对 grep 判据，`/tmp/r80/probes-all.log`、`/tmp/r80/grep-scoped.log`
- [x] 六道门禁跑在**已提交终态 `186527f`** 的字节上，六项 rc 全 0，日志 `/tmp/r80/gates-final.log`（下表读数由脚本从该日志现算）
- [x] 只读复核三轮：**第 1、2 轮 `VERDICT: FAIL`**（失项逐条回源复验后已修）、**第 3 轮 `VERDICT: PASS`**（报告 `/tmp/r81rev341/report.md`，副本自证 + 四个反向探针 + 在 `ec9526a` 上独立复现六门）⇒ 复核这一格不再欠；**合并本身仍待授权**，这一格不替它背书
- [ ] 矩阵 #19 回写（**不翻状态**：未合并只能写「已实现、未进 develop」；且本面只补上"排序可同步"这半格）

## 红测 → 绿测

⚠️ 本面的"红"没有独立的首跑日志可引（实现与用例是同一笔写的），所以**不拿记忆当证据**：
红**改引真实的 develop 字节首跑**：把副本里的 `lib/state/repositories/list_repository.dart`
换成 `git show origin/develop:lib/state/repositories/list_repository.dart` 的字节（本 PR 在 `lib`
下只动这一个文件 ⇒ 换完就是 develop 的真实状态），再跑本用例 ⇒
`/tmp/r80r2/logs/REAL_red_on_develop.log`：`00:00 +1 -4: Some tests failed.`、`rc=1`，第 4 条红在那份副本的"不留空洞"断言上（副本当时是 `f5604a4` 的字节 ⇒ 行号 `:133`；**这份是复核员在他的副本上跑的，不是我跑的**，两侧 `git hash-object` 记在该日志头部）。⚠️ **不拿行号当引用**：本笔之后该断言在当前字节上是 `:137`（复核第 2 轮在 `f616190` 副本上量的），定位一律用 `grep -n 空洞 test/state/list_repository_reorder_sync_test.dart`。
上一版这里写"Y1 等价于 develop 现状"不实：Y1 留着事务与计位，第 4 条红的是**登记条数**那条断言（Y1 在 `f616190` 副本上四条红在 `:61/:89/:112/:138`），而 develop 字节的第 4 条红在**空洞**断言⇒ 同数不同态。

```
$ python3 /tmp/r80/probes80.py all      # Y1 = 摘掉 enqueue（= develop 行为）
对照组（未打补丁）rc=0  00:00 +5: All tests passed!
判据面            rc=1  00:00 +1 -4: Some tests failed.
```

`+5` 这一侧就是 `186527f` 上的终态；`+1 -4` 是真红，红的四条用例名逐字打在日志里。
**条数口径**：本文件是 repository 层、用的是 `test(` 而非 `testWidgets(`，
声明数 `grep -c '^  test(' test/state/list_repository_reorder_sync_test.dart` = **5**，
与执行数 5 一致（本面没有循环生成的用例，不存在"声明 15 跑 18"那种分叉）。

## 第 79 轮只读复核（第 3 轮）：`VERDICT: PASS`（四条非阻断，本笔全部收口）

复核员自建副本 `/tmp/r81rev341/repo`（`git clone` + `checkout ec9526a`、698 项 `git ls-tree` 全核、
`cmp -s` 三处一致、被审 worktree 全程零写入），报告 `/tmp/r81rev341/report.md`。
它自己造的四个反向探针（只切 `reorder` 方法体）四个都变红且各红在预期判据上：
摘 enqueue ⇒ `+1 -4`；去事务 ⇒ `+4 -1` 命中"位次回到失败前"；位次用传入下标 ⇒ `+4 -1` 命中"不留空洞"；
payload 改手拼 ⇒ `+4 -1` 命中"取自读回行"。另抽了约 30 个锚点复算，**零死锚点**。

| # | 复核指什么（非阻断） | 我复验的读数 | 处置 |
| --- | --- | --- | --- |
| N-1 | `spec.md:17` 那条自扫判据用的是单字「拖」，自家输出破 2 处 | `grep -rn "拖" specs/054-list-reorder-sync` = 7 命中，破例者是 `plan.md:22`「不是拖延」与 `spec.md:44` 的禁令句 | 判据收窄成 `grep -rnE "拖拽\|拖动"`（实测 4 命中，全在豁免集内），并把这次破例写进同一句 |
| N-2 | 门禁节标题仍写基准 `186527f`/`gates-final.log`，同节 `:59` 已声明 `8de8c7c` ⇒ 两个基准标签并存 | `grep -n "^## 六道门禁" specs/054/tasks.md` 读到旧值 | 标题并进 `8de8c7c` + `r80r3/gates-r2.log`，并留一行注释说明为何改（复核员另在 `ec9526a` 上独立复现，不靠这份日志） |
| N-3 | `:26`/`:150` 还写「只读复核未派」，被同文件 `:127`（第 1 轮 FAIL）与 `:59`（第 2 轮）否证 ⇒ 过期账（方向是保守少报） | 两处字面命中 | 改成「第 1、2 轮 FAIL 已修、第 3 轮 PASS；合并待授权」 |
| N-4 | `spec.md:60` 的 `rename:100-107` 区间停在 `serverId:` 行，`payload: row.toJson()` 实在 `:108` | 在 `9032005` 上逐行读回 | 区间改 `100-108` 并显式标基准 |

一处**无法证实**（不计失项）：`:133`「PR 标题与正文全改成…」——复核会话没有 Gitea 读权限。
我这边同样不拿它当已核：合并前若要看，用 `GET /repos/izhaong/zh-cloud-todo-flutter/pulls/367` 读 `title`/`body` 现读，别信台账。

## 六道门禁（基准：已提交终态 `8de8c7c`；日志 `/tmp/r80r3/gates-r2.log`）
<!-- 第 3 轮复核 N-2：这一行标题原先还写着 `186527f` / `gates-final.log`，而同节 :59 已声明基准是 `8de8c7c` ⇒ 同一节两个基准标签并存。终态 `ec9526a` 只动 md，复核员另在 `ec9526a` 上独立复现了七 rc 全 0（不只靠这份日志）。 -->

这张表随终态推进。⚠️ 上一版这里写"填表之后只动文档、代码与用例一字未动"是**反话**：
`f5604a4` 与 `f616190` 两笔都动了 `test/`（文档注释、承重注释），`git diff --name-only 186527f..f616190`
实测 4 行含测试文件 ⇒ 那句话被自家 diff 反驳。
现状：下表的读数是 `186527f` 那一次（旧字节）；`f616190` 的全六门在
`/tmp/r80r2/gates-r2.sh.log`（七行 rc 全 0、门 4 `+9` 脏项 0、门 5 `+903 ~26`、门 6 `✓ Built build/web`）；
本笔（能力名与注释收口 `8de8c7c`）动了 `lib/`+`test/` 的注释字节 ⇒ 六门已在它之上重跑：
`/tmp/r80r3/gates-r2.log` 首行 `HEAD=8de8c7c 工作树脏项数=0`，七行 rc 全 0；门 2 `Formatted 2 files (0 changed)`、
门 3 `No issues found!`、门 4 `+9`（基线目录脏项 0 ⇒ 9 张未重录）、门 5 `02:39 +903 ~26 All tests passed!`、
门 6 `✓ Built build/web`。**基准 = `8de8c7c`**；之后的填值笔只动 md，用 `git diff --name-only 8de8c7c..HEAD` 复验。

| # | 命令 | 读数 | rc |
| --- | --- | --- | --- |
| 1 | `git diff --check origin/develop HEAD` / `git diff --check HEAD` | 两条均无输出（`HEAD=186527f 工作树脏项数=0`） | 0 / 0 |
| 2 | `dart format --output=none --set-exit-if-changed` 本轮 2 个显式文件 | `Formatted 2 files (0 changed) in 0.01 seconds.` | 0 |
| 3 | `flutter analyze` | `No issues found! (ran in 1.6s)` | 0 |
| 4 | `flutter test --tags golden` | `00:04 +9: All tests passed!`；`基线目录脏项数=0` ⇒ **9 张基线一张都没重录** | 0 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:37 +903 ~26: All tests passed!` | 0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0 |

计数对账：门 5 末行 `+903` 减掉本轮新增 5 条 = **898** = develop 全量基线。
**898 不靠减法取证**，它有自己的实跑日志两处（都是现读文件末行，不是推算）：

- `/tmp/r77c/rerun-898.log` 末两行 = `02:38 +898 ~26: All tests passed!` / `rc=0`（第 77 轮 F1 教训后补的独立实跑）
- `/tmp/r68/baseline_develop.log:1152` = `02:53 +898 ~26: All tests passed!`

新增 5 条这一侧的前提也可验：`git diff --name-status origin/develop..HEAD -- test` 只有一个 `A`，
`grep -c "^  test(" …` = 5。`~26` 与既有各轮一致（未新增 skip）。
收尾 `工作树脏项数=0`、`pubspec.lock` 未进提交。

## 反向探针（四条 Y1–Y4，`/tmp/r80/probes-all.log`）

每条都：起跑前 `lib` + `pubspec.lock` 干净 → 对照组先绿 → 锚点干跑（`check` 模式命中恰好 1）
→ 打补丁跑 → `cmp -s` 逐字节还原。判据面 = 本面新套件。

| 编号 | 摘掉的是什么 | 读数 | 红在哪 |
| --- | --- | --- | --- |
| Y1 | **只摘登记这一条行为**（事务、跳缺失 id、`position` 计位全留着 ⇒ 不等于 develop 的字节） | `+1 -4` | 4 条红的**用例名**都在预期清单里，但**名字的命中 ≠ 判据的命中**：按"每条红的首个失败断言行号"重打，:88（payload）与 :133（空洞）在 Y1 下根本没执行/仍是绿的，红的是四条**登记条数与有没有抛错**的断言（`f616190` 副本实测 `:61/:89/:112/:138`；引用一律配 `grep -n`，行号随编辑漂） |
| Y2 | 整批**不包事务** | `+4 -1` | 1/1 命中「第 2 条登记失败 ⇒ 整批位次回到失败前」 |
| Y3 | 位次用**传入下标**而不是实际写成的第几个 | `+4 -1` | 1/1 命中「跳过已不存在的 id、位次不留空洞」 |
| Y4 | payload 用**传入参数拼**、不读回那一行 | `+4 -1` | 1/1 命中「payload 取自读回的那一行」 |

Y2 的失败注入打在**依赖**上（`_ThrowingQueue extends SyncChangeQueue`，第 N 次 `enqueue` 抛错），
不是打在 `reorder` 自己身上 ⇒ 被测的那个事务真的在跑。
Y1 **只摘一条行为**（登记），它把四条全顶红是 `1 个行为 × 4 条断言`，不是"摘掉三个行为面"；
上一版写"摘掉三条、两条顺带"两头都不准（第 1 轮复核 §2）。三条行为面**各自有牙**这件事是真的，
但证据在 Y2/Y3/Y4 各自主断言上：摘事务只红**位次回到失败前**那条（副本 `:117`）、位次改用传入下标只红**不留空洞**那条（`:137`）、payload 改拼装只红**payload 取自读回行**那条（`:90`）——三条红在**互不相同**的断言上，这才叫各自有牙；行号一律配 `grep -n` 定位。
复核员还在副本上新增了一条 F（`enqueue` 挪到事务提交之后）⇒ 只红 :113，证明"位次的事务"与
"登记的事务"确实是两件事。

## 成对 grep 判据（`/tmp/r80/grep-scoped.log`）

⚠️ 这条判据第一版是**错的**：原判据数「整文件 `localId: id` 命中数」，被 `create`、`saveSmart`
两个不相关方法牵动（整文件实为 3 处），我把期望从 1 放宽到 3 去消异常 —— 那是把判据改成恒真。
改成**只数 `reorder` 方法体内**（切到下一个 2 空格缩进成员声明为止），并按"新校验器首跑必须拿
已知有问题的基线证它会红"对 `origin/develop` 版本再跑一遍，两面都出数才算判据：

```
[工作树 186527f] reorder 体自第 169 行起、共 29 行
  _queue.enqueue( = 1  期望 1   OK        旧写法 Value(i) = 0  期望 0  OK
[origin/develop] reorder 体自第 163 行起、共 13 行
  _queue.enqueue( = 0  期望 0   OK        旧写法 Value(i) = 1  期望 1  OK
```

⇒ 同一条判据在 develop 上**是红的**（0 条 enqueue、正是旧写法），在终态上是绿的。

## 本轮我自己造成的缺陷（逐条登记，不藏）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| 门禁 3 在 `2f98e2f` 上 rc=1（5 条 lint） | 新测试文件带了 1 个未使用 import + 4 个 `main()` 内以 `_` 开头的局部函数（该 lint 不给局部函数下划线前缀） | 单独一笔 `186527f` 修掉，只动测试文件；门禁重跑 |
| 成对 grep 报「异常计数 = 1」，我第一反应是把期望改成 3 | **判据作用域错了**（整文件计数与被测行为无关），放宽期望只是把"判据无信息"伪装成"通过" | 见上一节：作用域化 + 拿 develop 做会红对照；脚本 `/tmp/r80/grep_scoped.py` |
| 差点把本面写成「0 条用例」 | 条数用 `grep -c "  testWidgets("` 数 ⇒ 本文件根本没有 `testWidgets`（repository 层无 widget），0 命中被读成"没有用例" | 判据换 `grep -c "^  test("` = 5；这正是 memory 里「'0 命中' 判据本身会造假」那一族的新实例 |
| 「红测」缺首跑日志 | 实现与用例同笔写，没有留下"先红"的那一次输出 | 不引记忆数字；但"用 Y1 顶替"选错了状态（同数不同态）。现在改引真实 develop 字节的首跑日志，Y1 退回成第 5 条探针 |
| `spec.md` 两处写 `moveToFolder:119` | **凭记忆写的行号**：`117` 是方法头、`118` 才是 `_db.transaction` 那行，`119` 在 develop 和终态上都对不上（两个基准都错 ⇒ 不是漂移，是从来就错） | 两处都改 `:118` 并在现状节补一句「行号按 `origin/develop@9032005`，指不到按符号名搜」。这正是 memory 里「别拿『脚手架限制』当挡箭牌 / 引先例要证它真的存在」那一族的行号版 |
| 本文件上一版把"其余写方法都登记"写成 **三处** | 只数了我当时想得到的三个（`create`/`moveToFolder`/`saveSmart`），漏了 `rename`、`delete`；`spec.md` 写的是「五个」⇒ 两文件自相矛盾 | 按 develop 实测补全五条并逐个带行号；措辞统一到「其余**五个**」 |

## 第 79 轮只读复核（第 1 轮）：`VERDICT: FAIL`（四条阻断，全在措辞与引证，实现未动）

报告在盘：`/tmp/r80r2/review_r79_round1_report.md`（复核员自己落盘的，我不代抄）。

| # | 复核指什么 | 我复验的命令与读数 | 处置 |
| --- | --- | --- | --- |
| C-1 | 「拖拽排序」根本不存在：`_move(delta)` + 两个 `IconButton(上移/下移)`，全文件零拖拽形状 | `grep -cE "Draggable\|LongPressDraggable\|ReorderableList\|onPan" lib/features/list/list_page.dart` = **0**；`grep -n "tooltip: '上移'\|tooltip: '下移'"` → `:308`、`:313` | 三个 md 的标题、spec §一/§三/FR-4/取舍 1、**测试文件第 11 行的文档注释**、PR 标题与正文全改成「清单排序（上移/下移）」；矩阵 #19 的 ③ 格按同一口径改字 |
| C-2 | 唯一调用点所在页不可达，且否证它的字节就在同仓 `specs/026` 里 | `git grep -nE "(^\|[^A-Za-z])ListPage\(" HEAD -- lib test` 只命中自身声明与一个 widget 测试；`app.dart:33` 路由表只 `/login`、`/` | spec「二」加一条 ⚠️（写明"潜伏缺陷"、引 `specs/026/…/spec.md:9-10`），用户故事 1 加"今天走不到用户面前"的限定，「完成情况」取证条同步 |
| §2 | Y1 的多命中被写成"摘掉三条行为面" | 复核按首个失败断言重打（A/B/C/D/E/F 六组），Y1 形态下 :88、:133 未执行/仍绿 | 上表 Y1 行与下面那段判据归属都按实测重写 |
| §5 | 「Y1 等价于 develop 现状」不实（同数不同态），而"缺首跑日志"是真欠账 | 复核在副本上换成 develop 字节跑出 `+1 -4`、第 4 条红 :133（`REAL_red_on_develop.log`） | 「红测 → 绿测」与缺陷表那格都改引这份，并标明是复核员跑的 |
| A/B | plan.md 两条验证列引错对象（`gates.log` 门 3 `rc=1`；`probes-all.log` 末段 `异常计数 = 1`） | 复核逐行回读该两份日志 | plan 第 5、6 步分别改引 `grep-scoped.log` 与 `gates-final.log`，并把"另一份日志实际是什么读数"写在旁边 |
| NIT | `:78` 标"逐字引用"却自加三对 `**`；`app_database.dart:29-50` 类体实为 29–48 | 源页 `awk 'NR==78'` 逐字比过；`git grep -n "class TodoLists"` 两侧 | 都已改 |

**采纳与驳回**：六条**全部采纳**，无驳回项。**驳回自己的**是上一轮的取证法：我只读了仓储层
"少一次 enqueue"就把它写成用户症状（可空依赖 + `?.` 静默早退那一族的老毛病，第 79 轮里我
又犯了一次）⇒ 教训：**"用户会遇到 X"这句话必须先跑一遍"入口 → 路由 → provider"链**，链不通
就只能写"契约层缺陷 + 当前潜伏"。

**实现代码未动**：复核 §9/§10 判定 `reorder` 与 `rename`/`moveToFolder` 同形、无多余抽象，
不需要重写或回退。本轮只动 md 与测试文件的两处注释 ⇒ 门禁要在**新字节**上重跑（见门禁节）。

## 遗留与下一轮

- **门禁已跑在 `8de8c7c`**（上表；终态 `ec9526a` 只动 md，复核员又在 `ec9526a` 上独立复现七 rc 全 0）；**只读复核第 1、2 轮 FAIL 已修、第 3 轮 PASS** ⇒ 本 PR 具备可合并条件，合并等授权。
  要复核员咬定的：① Y1 一条摘掉三个行为面，算不算把三条判据压缩成一条（若是，该怎么拆）；
  ② `_ThrowingQueue` 注入点选在第 N 次 `enqueue` 是否唯一合理，注在 `update` 上会不会让 FR-2 的断言更强；
  ③ payload 取 `moved.toJson()`（读回整行）在上游 `_queue` 只消费 `sortOrder` 的前提下是否过度；
  ④ 矩阵 #19 的"排序"这半格在**未合并**时的措辞够不够保守。
- 矩阵 #19 本轮**不翻状态**：只本地 ⇒ 本地 + 可同步这一改动未进 develop；
  且嘀嗒 `:78` 的「置顶」半边仍卡在 service#289（无字段），不是本面能收的。
- 下一轮候选（不撞本单）：FL #279 之外的存量按欠账序走 —— ③ 的 `habit_editor`(#308) 已做完，
  剩 ④ 看板列绑 `TodoTaskSection`（矩阵 #15）与 ⑥ service #281 / !276。
