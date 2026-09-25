# 任务清单：清单拖拽排序要登记同步 outbox（specs/054 / FL Issue #341 / 矩阵 #19）

分支 `feat/341-list-reorder`，基线 `origin/develop@9032005`，PR !367。
提交 `2f98e2f`（实现 + 用例 + 规格）、`186527f`（门禁 3 报的 5 条 lint，只动新测试文件）。

## 完成情况

- [x] `spec.md` 来源表：《02-用清单管理任务》`:78`（左滑 → 置顶 / 编辑 / 删除）逐字引用（基准 docs `origin/develop`）
- [x] 现状取证：develop 的 `ListRepository.reorder`（`list_repository.dart:163` 起、13 行）**只写本地
      `sortOrder`、一次 `_queue.enqueue` 都没有** —— 同文件**其余五个**写方法各有且仅有一条
      （develop：`create:85` / `rename:103` / `moveToFolder:141` / `delete:181` / `saveSmart:212`），
      唯独这条写路径漏；所以「本地能拖、拖完换端顺序回滚」是**代码事实**，不是猜测
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
- [ ] 只读复核未派 ⇒ 本 PR 不谈合并
- [ ] 矩阵 #19 回写（**不翻状态**：未合并只能写「已实现、未进 develop」；且本面只补上"排序可同步"这半格）

## 红测 → 绿测

⚠️ 本面的"红"没有独立的首跑日志可引（实现与用例是同一笔写的），所以**不拿记忆当证据**：
红改由 Y1 探针现打 —— 它把 `reorder` 里的 `enqueue` 整块摘掉 ⇒ 等价于 develop 现状。

```
$ python3 /tmp/r80/probes80.py all      # Y1 = 摘掉 enqueue（= develop 行为）
对照组（未打补丁）rc=0  00:00 +5: All tests passed!
判据面            rc=1  00:00 +1 -4: Some tests failed.
```

`+5` 这一侧就是 `186527f` 上的终态；`+1 -4` 是真红，红的四条用例名逐字打在日志里。
**条数口径**：本文件是 repository 层、用的是 `test(` 而非 `testWidgets(`，
声明数 `grep -c '^  test(' test/state/list_repository_reorder_sync_test.dart` = **5**，
与执行数 5 一致（本面没有循环生成的用例，不存在"声明 15 跑 18"那种分叉）。

## 六道门禁（基准：已提交终态 `186527f`；日志 `/tmp/r80/gates-final.log`）

这张表随终态推进；门 1–6 全部跑在 `186527f` 的字节上。填表之后的笔只动**文档**（`specs/054/` 下的
`tasks.md` 与 `spec.md` 两处行号/条数纠错），代码与用例一字未动 ——
用 `git diff --name-only 186527f..HEAD` 复验：它只该列出这两个 md 文件。

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
| Y1 | `reorder` 整块不登记 outbox（退回 develop 的病灶） | `+1 -4` | 4/4 命中预期用例名：位次登记、payload 读回、半途失败回滚、不留空洞 |
| Y2 | 整批**不包事务** | `+4 -1` | 1/1 命中「第 2 条登记失败 ⇒ 整批位次回到失败前」 |
| Y3 | 位次用**传入下标**而不是实际写成的第几个 | `+4 -1` | 1/1 命中「跳过已不存在的 id、位次不留空洞」 |
| Y4 | payload 用**传入参数拼**、不读回那一行 | `+4 -1` | 1/1 命中「payload 取自读回的那一行」 |

Y2 的失败注入打在**依赖**上（`_ThrowingQueue extends SyncChangeQueue`，第 N 次 `enqueue` 抛错），
不是打在 `reorder` 自己身上 ⇒ 被测的那个事务真的在跑。
Y1 一次摘掉三条的行为面，所以它的四条红里有两条（payload、空洞）是"顺带覆盖"，
真正各自独立的是 Y3、Y4 —— 如实记，不把 Y1 的多命中当成三条独立判据。

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
| 「红测」缺首跑日志 | 实现与用例同笔写，没有留下"先红"的那一次输出 | 不引记忆数字：改由 Y1 探针现打等价于 develop 的红（`+1 -4`），并在此处写明它替代首跑 |
| `spec.md` 两处写 `moveToFolder:119` | **凭记忆写的行号**：`117` 是方法头、`118` 才是 `_db.transaction` 那行，`119` 在 develop 和终态上都对不上（两个基准都错 ⇒ 不是漂移，是从来就错） | 两处都改 `:118` 并在现状节补一句「行号按 `origin/develop@9032005`，指不到按符号名搜」。这正是 memory 里「别拿『脚手架限制』当挡箭牌 / 引先例要证它真的存在」那一族的行号版 |
| 本文件上一版把"其余写方法都登记"写成 **三处** | 只数了我当时想得到的三个（`create`/`moveToFolder`/`saveSmart`），漏了 `rename`、`delete`；`spec.md` 写的是「五个」⇒ 两文件自相矛盾 | 按 develop 实测补全五条并逐个带行号；措辞统一到「其余**五个**」 |

## 遗留与下一轮

- **门禁已跑在 `186527f`**（上表）；**只读复核未派** ⇒ 本 PR 不谈合并。
  要复核员咬定的：① Y1 一条摘掉三个行为面，算不算把三条判据压缩成一条（若是，该怎么拆）；
  ② `_ThrowingQueue` 注入点选在第 N 次 `enqueue` 是否唯一合理，注在 `update` 上会不会让 FR-2 的断言更强；
  ③ payload 取 `moved.toJson()`（读回整行）在上游 `_queue` 只消费 `sortOrder` 的前提下是否过度；
  ④ 矩阵 #19 的"排序"这半格在**未合并**时的措辞够不够保守。
- 矩阵 #19 本轮**不翻状态**：只本地 ⇒ 本地 + 可同步这一改动未进 develop；
  且嘀嗒 `:78` 的「置顶」半边仍卡在 service#289（无字段），不是本面能收的。
- 下一轮候选（不撞本单）：FL #279 之外的存量按欠账序走 —— ③ 的 `habit_editor`(#308) 已做完，
  剩 ④ 看板列绑 `TodoTaskSection`（矩阵 #15）与 ⑥ service #281 / !276。
