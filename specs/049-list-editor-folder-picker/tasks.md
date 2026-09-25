# 049 · 清单编辑器「所属文件夹」· 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/339-list-editor-folder-picker`。Issue **#339**（矩阵 **#19**）。
判据、范围与取舍见同目录 `spec.md`；落点与实现要点见 `plan.md`。

## 勾选（只勾真满足的）

- [x] FR-1 编辑器出现「所属文件夹」：「无」+ 每个已有文件夹，嵌套文件夹显示成 `父 / 子`
- [x] FR-2 新建：所选文件夹即新清单归属；没选 ⇒ 顶层（`folderLocalId` 为 null，服务端 `folderId` 也为 null）
- [x] FR-3 编辑：打开预选当前归属；改选后保存真的移入/移出，并留 `list/upsert` outbox（用例读库 + 数 outbox 行数）
- [x] FR-4 只改名不动文件夹 ⇒ 不多打一条移动记录（探针 PD 证：去掉闸门就红）
- [x] FR-5 从文件夹里点新建 ⇒ 预选那个文件夹（隐式行为，探针 PG 证）
- [x] FR-6 四件套（见下表；第 1 版的③是假绿，复核后补了「移入失败」才真锁住；第 2 轮又抓到"仓库为 null"与"新建失败文案"两格 0 覆盖，已补）
- [ ] #339 的另两子面：**颜色** 与 **Emoji 图标** 未做（要新增本地列 + 后端 `TodoListDO` 字段 ⇒ 属"先修契约再动前端"），Issue 保持 open
- [x] 只读复核第 1 版 `VERDICT: FAIL` → 补测后第 2 版仍 `VERDICT: FAIL`（3 条覆盖缺口 + 文档措辞）→ 第 3 版仍 `FAIL`，但**只抓到 2 条 P2 + 3 条 nit，全是文档/口径级**（无新增覆盖缺口）⇒ 5 条全部采纳并落到 `plan.md`/`spec.md`/本文件与 `5475e63`
- [ ] 第 4 版复核（范围只圈在本轮 3 处文档改动 + `5475e63` 的拓扑改动与其 `PV`/PM′ 复测）尚未派
- [ ] 矩阵 #19 回写 —— 第 3 版复核时 `state=open` 实测 **10 条**（本 PR !352 + !311 !314 !319 !322 !346 !347 !350 !351 !354），**除 !352 外一条都没合并** ⇒ 只能写「已实现待合并」，状态列不翻转

## 四件套（新增可见界面 = 编辑器里那一格下拉）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 在弹层自己的 context 上 `textScaler: TextScaler.linear(1.3)` + 320×700。收起态用 `takeException`（有力：复核员的 `ROW_overflow` 变异红在 `overflowed by 185 pixels`）；**展开态不写溢出判据**（PS/PR/PU 三条变异实测它是恒真的，见下节） | `320px + 1.3 倍字号：名称、所属文件夹与按钮都排得下` |
| 独立读屏语义 | `MergeSemantics` 包住 `InputDecorator` ⇒ 一个节点念「所属文件夹 无」，且 `isButton`/`tap`/`focus` 一个没丢（实测对照见下节） | `读屏：一个节点同时念出「所属文件夹」与当前值，且仍是按钮` |
| 失败保留已加载数据 | **四条**覆盖四个失败出口：移出失败（原归属→「无」）、移入失败（无归属→「项目」）、新建失败（`create` 抛错）、仓库为 null。断言按各条实际填的内容分两种：移出/新建/仓库 null 三条断"框不关 + 已填名称 + 已选归属 + 库里没写"，**移入失败那条不填名称**（它只改归属），只断框不关 + 已选归属还在 + 库里没写。只测移出的版本放过过真 bug，见 PL；新建与 null 两格此前 0 覆盖，见 PQ / P0 | `移动失败…` + `移入失败…` + `新建失败（不是移动失败）…` + `本地库还没就绪…` |
| 过期响应不覆盖新响应 | 归属是 State 里的**点中字面值**，文件夹 stream 只是补候选；stream 再发一次也不回退已选 | `文件夹列表晚到：占位换成真名，之后再来一次也不覆盖已选` |

### 读屏是实测出来的，不是推的

探针输出全文留在 `/tmp/r68/SEMANTICS_PROBE.txt`（探针脚本 `/tmp/r68/r68_semantics_probe.dart.txt`，
复制回 `test/` 可重跑）。同一棵树两版对照：

| | 字段节点的 label | `所属文件夹[\s\S]*无` 命中 | flags |
| -- | -------------- | ---------------------- | ----- |
| 不合并（InputDecorator 直接包 DropdownButton） | `"无"` | **0** | `isButton, isFocusable, hasExpandedState` |
| 包 `MergeSemantics`（本轮最终字节） | `"所属文件夹\n无"` | 1 | 同上，一个没丢 |

⇒ 不合并时读屏只会念"无 按钮"，用户不知道这个"无"是什么的无。这与我上一轮记的坑同形：
**标签与值分属两个节点时，`bySemanticsLabel` 的正则永远配不出"标签+值"**，
断言写宽一点就会假绿。

### 一个实现期真的踩到的断言

首帧 `foldersStreamProvider` 还没吐数据，而清单已有归属 ⇒ `DropdownButton` 断言
"There should be exactly one item with [DropdownButton]'s value"（本机 3.44.8 原文）。
⇒ 候选里补一格占位（数据没到 = `加载中…`；到了但查不到 = `（已删除）`）。
这条不是"防御性代码"：探针 PI 把它抽掉后 **7 条用例同时红**（`+8 -7`）。

## 反向探针（每条先证探针本身打上了：目标串在 HEAD 字节里恰好命中 1 次）

探针代号的读法：`PA`–`PN` 是字母序；`P0` 里是**数字零**（取自复核员的变异名 `NULL_branch_silent`，
它不在字母序列里，别读成 `PO`）；`PQ`/`PR`/`PS`/`PV` 是第 3 轮复核之后续的。区间记法一律写全，不写"PB…PK 之类"。

**口径：全部跑单文件**（`flutter test test/features/list/list_editor_folder_picker_test.dart`），
15 条用例的最终版本。这套数字**每次增删用例都整批重测**：第一版是 10 条、复核补测后 13 条、
本轮补 FR-6 与新建失败两格后 15 条 ⇒ 旧数字一律作废（脚本 `/tmp/r68/probes_final14.py`，
汇总 `/tmp/r68/PROBES_final15d.log`（15d = 生产拓扑那条改完、tip `5475e63` 的最终字节；上一版 15c 跑在 `015a31a`，
两者**共有探针的数字逐条相同**，15d 只多出 `PV` 一条），每条完整日志 `/tmp/r68/probe14/<码>.log`，跑完 `RESTORE cmp: SAME`）。

| 探针 | 抽掉什么 | 结果 | 红在哪条 |
| ---- | -------- | ---- | -------- |
| PA | develop 字节（整格都没有） | `+1 -14` | 14 条红；唯一绿的是 `只改名不动文件夹`（它钉"不许顺手多同步一次"，develop 本来就没这能力 ⇒ 这条绿是对的） |
| PB | 新建时不把归属传给 `create` | `+13 -2` | 新建 + `serverId 为空`（都读库看 folderLocalId） |
| PC | 编辑时根本不发起移动 | `+12 -3` | 编辑移出 + 移出失败 + 移入失败 |
| PD | 去掉「值没变就不动」闸门 | `+14 -1` | `只改名不动文件夹 ⇒ 不额外打一条移动记录`（FR-4 正面判据） |
| PE | 失败只 `return`，不给可见提示 | `+12 -3` | 移出失败 + 移入失败 + **新建失败** |
| PF | 失败也把弹层关掉 | `+12 -3` | 同上 3 条 |
| PG | 打开时不预选 | `+10 -5` | 预选、编辑移出、只改名、晚到、已删除 |
| PH | 去掉 `MergeSemantics` | `+14 -1` | 读屏那条（四件套②唯一锚点） |
| PI | 去掉占位候选 | `+8 -7` | 「踩到的断言」那节列的 7 条（新增的两条失败用例不受影响 ⇒ 它们走的是 catch，不是占位） |
| PJ | 显示值改回入参派生（非受控） | `+8 -7` | 晚到（四件套④）+ 新建 + 移出失败 + 移入失败 + 新建失败 + 本地库未就绪 + 读屏（共 7 条） |
| PK | 先改名再移动 | `+14 -1` | 移出失败那条（断言 `after.name == '工作'`） |
| **PL** | **失败时顺手清空已选归属**（复核 P1 的那个 bug） | `+13 -2` | 移入失败 + 新建失败 ⇒ 两条"失败后已选还在"的断言都咬得住 |
| PM | 候选菜单永不展开（`onChanged: null`） | `+2 -13` | 13 条红，含 320 那条（靠 `openMenu` 自带的自检，见 PM′） |
| PN | 嵌套文件夹只显示自己的名字（丢父链） | `+14 -1` | 只有「嵌套父 / 子」那条红 ⇒ FR-1 的这半句以前是 0 覆盖（复核 P2） |
| **P0** | **仓库为 null 时静默 return**（复核第 2 轮 P1） | `+14 -1` | 只有「本地库还没就绪」那条红 ⇒ 补测前 13 条全绿 |
| **PQ** | **新建失败的文案换成任意串**（复核第 2 轮 P2） | `+14 -1` | 只有「新建失败（不是移动失败）」那条红 ⇒ 补测前 13 条全绿 |
| PR | 候选项塞成 500dp 宽（横向溢出） | `+8 -7` | **320 那条不红** ⇒ 横向没有可失败的判据（`_DropdownMenu` 的父约束把框宽夹住） |
| PS | 候选项灌 60 行文本（复核 `MENU_tall_text` 原样） | `+4 -11` | 320 那条红，但失败原因是 `find.text('项目')` 查不到（文案被换掉了），**不是** `takeException` |
| **PU** | 候选项塞成 2000px 高、**文案保留**（复核 `MENU_tall_item`） | `+8 -7` | **320 那条不红** ⇒ 展开态连纵向也没有判据（这条是决定性的一条） |
| **PV** | **收起态**操作行的「取消」文案撑成 12 个字（复核第 3 轮 nit：换生产拓扑后要重新证明这条有力） | `+14 -1` | 只有 320 那条红，红在 `A RenderFlex overflowed by 250 pixels on the right.` ⇒ 生产拓扑（`showModalBottomSheet`）下收起态那句 `takeException` 依然量得到溢出 |

### PM′：证明「320 那条红是因为有自检」，不是靠自己发现菜单没开

两个文件一起改：lib 里 `onChanged: null` + 测试里删掉 `expect(menuItems(tester), isNotEmpty)`。
脚本 `/tmp/r68/probe_PM_prime.py`，日志 `/tmp/r68/PROBE_PM_prime_c.log`（跑在 `015a31a`）；
320 那条换成生产拓扑后（`5475e63`）整探针重跑一遍 = `/tmp/r68/PROBE_PM_prime_d.log`，**结论一字未变**。
两遍都是 `+3 -12`，且 **320 那条不红**（12 条失败清单里没有它）⇒ 它红在 PM 完全靠 `openMenu` 那句自检。
这条是复核第 1 轮 P2 的闭环：省掉自检，展开态的那两句就永远在测收起态。

### 「展开态不溢出」这句主张已撤销（复核第 2 轮 P2，两条变异实测它是恒真的）

复核员注入两种"候选菜单超大"的变异，我这轮自己复跑了一遍：

| 变异 | 保留候选文案？ | 320 那条 | 真失败原因 |
| ---- | -------------- | -------- | ---------- |
| `PU` 候选项 `SizedBox(height: 2000)` | 是 | **不红** | —— |
| `PR` 候选项 `SizedBox(width: 500)` | 是 | **不红** | —— |
| `PS` 候选项灌 60 行文本 | **否**（变成 60 行重复串） | 红 | `find.text('项目')` 查不到，**不是** `takeException` |

⇒ `_DropdownMenu` 把候选列表夹在可用尺寸里自己滚动，横向被父约束夹住（复核员量框版
`MENU500_plus_rect` 也测不到），纵向不报错 ⇒ **"展开的候选菜单不溢出"是一句恒真断言**，
已从用例里删掉，改成只保留「菜单真打开 + 候选文案在场」。
收起态那句 `takeException` **有力**：复核员的 `ROW_overflow`（操作行塞长文案）实测红在
`A RenderFlex overflowed by 185 pixels`；换生产拓扑后我用 `PV` 在同一处重测，红在
`A RenderFlex overflowed by 250 pixels on the right.` ⇒ 那句判据不是靠 `Scaffold.body` 的宽松约束侥幸过关的。


**PA 第一次跑出来的不是"红"，是 8 分钟不退出 —— 根因在我自己的用例里**：
`晚到` 那条用了单订阅 `StreamController`，`addTearDown(controller.close)` 的 `done` future 要等"有订阅者收完"才完成；
develop 字节的弹层根本不 watch `foldersStreamProvider` ⇒ 没人订阅 ⇒ tearDown 永久挂起，
探针把"红"伪装成"没结论"。改成 `broadcast()` 后同一份字节一秒收口（当时 13 条口径是 `+1 -12`，15 条口径是 `+1 -14`）。
教训：**探针跑不完先怀疑夹具**，别把"runner 不退出"读成"实现没问题"。

## 门禁原文记录（跑在 tip `5475e63` 的 dart 字节上，日志 `/tmp/r68/gates/final_r4.log`）

表里记的是**代码字节**：`5475e63` 之后本文件与 `plan.md` 还各有文档改动（未提交），
它们不动任何 dart ⇒ 这六条对它照样成立。门禁跑之前工作区里已有的 `specs/*.md` 改动
会在"收尾 `git status --short`"那一栏露出来，已核对不含 `pubspec.lock`。

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 2 个 dart 文件>` | `Formatted 2 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 2.2s)`，`rc=0` |
| `flutter test --tags golden` | `00:04 +9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录（第 1 轮复核另用 `diff -rq` 逐字节比对副本，同样未变） |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:45 +913 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

计数对账：`+913 = 898 + 15`（898 = 在 develop 副本 `/tmp/r68-baseline` 实测，日志
`/tmp/r68/baseline_develop.log`；15 = 本文件新增用例数，用 `git diff --name-status origin/develop...HEAD -- test`
核对：唯一的 `A` 就是本轮那个测试文件）。`~26` 未新增 skip。
`pubspec.lock` 未进提交（**前提：门禁与 `source ~/development/env-flutter.sh` 同 shell**，否则 analyze 会把
lock 里 150 行 url 翻成 pub.dev）。

**这是第 5 遍**：第 1 遍（`e231bf4`）5/6，门禁 3 报 `unused_import` ⇒ 单提 `840af71` 后第 2 遍 6/6；
第 1 轮复核补 3 条用例后（`aad865c`）第 3 遍 6/6（`+911`）；
第 2 轮复核再补 2 条用例并撤掉 1 条恒真断言后（`015a31a`）第 4 遍 6/6（`+913`）；
第 3 轮复核 nit-3（320 那条要按生产拓扑量）改完测试后（`5475e63`）**六条再一次全部重跑** = 本表。
前四遍日志：`/tmp/r68/gates/attempt1.log`、`/tmp/r68/gates/final.log`、`/tmp/r68/gates/final_r2.log`、
`/tmp/r68/gates/final_r3.log`。

## 复核（第 1 版 `VERDICT: FAIL`：1 条 P1 + 5 条 P2 + 1 条 nit，全部采纳）

复核员在 `/tmp/rev68-copy` 副本上做变异，`/tmp/wt-flutter-339` 未被改动（跑完 `status --porcelain` 为空）。
逐条回源复验后的处置：

| 发现 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **P1** ③「失败保留已加载数据」假绿：原用例从「项目」点「无」，与"失败时顺手清空归属"这个 bug 完全同形；catch 里加 `_folderLocalId = null` 后 10 条全绿 | 我独立跑同一变异（PL）⇒ 同样 `+10` 全绿。判断成立 | **采纳**。新增「移入失败（原来没有归属）」一条：从无归属清单进入、选「项目」、失败后断言界面仍是「项目」且库里没写。补完后同一变异 `+12 -1` 只红在新那条 |
| **P2** 320px 那条没证"候选菜单真的展开了"（`find.text('项目')` 对开/关都成立；删掉那次 tap 仍全绿） | 复现：PM（`onChanged: null` ⇒ 菜单永不展开）改前也是 12 条里只红 11 条不含此断言 | **采纳**。改用带自检的 `openMenu`（内部 `expect(menuItems, isNotEmpty)`）⇒ PM 现在红在它 |
| **P2** 计数出处指向不存在的目录（`specs/045-sort-direction/` 本分支与 develop 都没有） | `git ls-tree --name-only origin/develop specs/` 最大 `044-kanban-groups` ⇒ 复核对 | **采纳**。基线改成**本轮实测**：`/tmp/r68-baseline`（develop 副本）跑出 `+898 ~26` |
| **P2** FR-1 的「嵌套文件夹显示成 `父 / 子`」0 覆盖（夹具只有一个顶层文件夹），但 `[x]` 已勾 | 夹具确实只 seed 一个无 parentId 的文件夹 ⇒ 主张超出证据 | **采纳**。新增「嵌套父 / 子」用例（PN 抽掉父链只红它）；这也是本轮第二次犯"勾了但没测"（同形于第 66 轮 PJ） |
| **P2** `created.folderId` 的 reason「否则同步会丢归属」被实现证伪：`sync_coordinator` 回放时按 `folderLocalId` 重算 `folderId` | 读 `sync_coordinator.dart:577-590` 与 `list_repository.dart:76/:134` ⇒ 复核对 | **采纳**。reason 改成"钉反范式缓存列"；并新增 `serverId=null` 的降级用例（这条路径原先全仓 0 覆盖） |
| **P2** 门禁 3 在无镜像环境不可复现（analyze 会把 lock 的 150 行 url 翻成 pub.dev） | 与第 67 轮同源，已在门禁段写明前置 | **采纳** |
| **nit** 注释里引的框架断言原文不准 | 本机 3.44.8 实际抛 `There should be exactly one item with [DropdownButton]'s value: …` | **采纳**，注释改成原文 |

复核也独立复现了 PA–PK 全部 11 条（数字与表一致）并确认：9 张黄金基线逐字节未变（`diff -rq` 副本 vs 原 worktree）、
本分支没碰 docs、矩阵 #19 在 develop 上仍是旧判未翻转。

### 第 2 版复核（补测之后）：`VERDICT: FAIL`，3 条覆盖缺口 + 2 条文档措辞 + 1 nit

复核全在副本 `/tmp/rev68b-copy` 上做（驱动 `/tmp/rev68b/run_mut.py`、`run_mut2.py`，日志 `/tmp/rev68b/*.log`），
跑完 `WORKTREE_CLEAN: yes` ⇒ 原 worktree 未被碰。逐条回源复验后的处置：

| 发现 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **P1** `spec.md:41`/`tasks.md:13` 的 FR-6 写「仓库为 null / 移动抛错」两种失败都有提示，但 null 那半句 0 覆盖：`NULL_branch_silent`（摘掉 `list_editor_sheet.dart:48` 的 setState）⇒ `+13` 全绿 | 我自己跑同一变异（P0）⇒ 补测前同样全绿 | **采纳**。新增「本地库还没就绪」用例（`listRepositoryProvider.overrideWith((ref) => null)`，断弹层不关＋提示可见＋已填不丢＋库里没写）；P0 现在 `+14 -1` 只红它 |
| **P2** catch 里的三元文案只钉过"移动失败"那侧：`CREATE_fail_msg`（把「新建清单失败，请重试」换成任意串）⇒ 13 全绿 | 复现同一变异（PQ）⇒ 补测前确实全绿 | **采纳**。新增「新建失败（不是移动失败）」用例 + `_CreateFailingRepository`；PQ 现在 `+14 -1` 只红它 |
| **P2** `tasks.md:22` 的「收起与**展开**两种状态各测一次溢出」超出证据：`MENU500_only`/`MENU_fixed_width` 不红，`MENU_tall_text` 只红在 `find.text('项目')`；量框版 `MENU500_plus_rect` 也被父约束夹住 ⇒ **测不到，别写做不到的判据** | 我按 PS/PR/PU 三条变异复跑：`PU`（2000px 高、文案保留）与 `PR`（500dp 宽）下 320 那条**都不红**；`PS` 红的原因是文案没了 ⇒ 复核对 | **采纳**。删掉那句恒真的 `takeException`，用例注释与本文件都改成"展开态不写溢出判据"。我第一版曾按建议加过一圈量框断言，实测它唯一的作用是 `reason:` 里急切求值的 `itemLabel` 抛类型错 ⇒ **红的是崩溃不是判据**，已回滚（`ba96660`） |
| **P2** `plan.md:10/:28/:29` 旧数字未同步（写 10 条实为 13；PA 写"10 里 9 红"表里是 `+1 -12`；探针写到 PK） | 对 | **采纳**。`plan.md` 现按 15 条口径写，探针清单到 PU |
| **P2** `tasks.md:44` 文档仍写 `There must be…`（第 1 轮 nit 只改了代码注释）；`:45` PI 写 `+3 -7` 与表里矛盾 | 对（`dropdown.dart:1035` 是 `There should be…`） | **采纳**，两处都改并随本轮重测更新 |
| **nit** 门禁表头写"跑在最终字节 `aad865c`"，而 tip 是别的 SHA | 对：`git diff --name-only aad865c <tip>` 只含 specs/*.md，dart 字节相同 ⇒ 数字仍成立，但措辞不准 | **采纳**。表头改成"跑在 tip 的 dart 字节 = `<SHA>`" |

第 2 轮复核的两条"不确定项"我这边的答复：
① `+898` 基线不是靠 `911 − 13` 推的，是在 develop 副本 `/tmp/r68-baseline` 直接跑出来的
（日志 `/tmp/r68/baseline_develop.log`，`02:53 +898 ~26`）；
② PM 的实现是 `onChanged: null`（整个字段禁用）——本文件与 `/tmp/r68/probes_final14.py` 里有原文；
③ FR-1「与侧栏同一套父子关系」我这轮只证到分隔符同源（`folder_page.dart` 与 `list_editor_sheet.dart`
都是 `join(' / ')`），**侧栏渲染路径未测**，不声称一致。

### 第 3 版复核（补测 + 撤销恒真断言之后）：`VERDICT: FAIL`，2 条 P2 + 3 条 nit，**全是文档/口径级**，无新增覆盖缺口

复核在副本 `/tmp/rev68c-copy`（全量跑 `/tmp/rev68c-full`）上做，跑完 `WORKTREE_CLEAN: yes`。
本轮值得记的是：**没有一条 P1**，也没有一条"某分支 0 覆盖" ⇒ 前两轮的补测把实质缺口堵住了；
剩下 5 条都是"文档写的和代码/实测对不上"。逐条回源复验后的处置：

| 发现 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **P2-1** `plan.md:10` 的用例分解写成 14 条（归属读写 4 + 四件套 4 + 负路径 5 + 嵌套 1），与 `tasks.md` 的 15 条口径不一致 | `grep -c "testWidgets" test/features/list/list_editor_folder_picker_test.dart` = **15** ⇒ 复核对，是我的 `plan.md` 落后一轮 | **采纳**。`plan.md` 改成 15 = 归属读写 4 + 四件套 4 + 负路径/降级 6 + 嵌套命名 1 |
| **P2-2** 四件套③「失败保留已加载数据」在 `spec.md`/`tasks.md` 只写了两条出口（移动失败、仓库为 null），代码实际是**三条**（新建失败那句文案不同） | 读 `list_editor_sheet.dart` 的 catch：`existing == null ? '新建清单失败，请重试' : '移动到文件夹失败，请重试'` ⇒ 三出口成立 | **采纳**。两处措辞补齐三出口，且每出口各有用例（PQ/P0/PL 分别只红一条） |
| **nit-1** 「相撞面」一段仍写 9 条 open PR，且 PJ 那条的描述与表里数字对不上 | 重新过一遍 `list_pull_requests(state=open)`：**10 条**（!354 是第 69 轮新开的，我数 PR 时它还没落地） | **采纳**。相撞面改成 10 条并列出编号；PJ 行改成"共 7 条"并逐条点名 |
| **nit-2** 探针代号 `P0` 极易读成字母 O；`PQ`–`PU` 的来历没交代 | 对，`P0` 取自复核员的变异名 `NULL_branch_silent`，不在字母序里 | **采纳**。表前加"探针代号的读法"一段，并规定区间记法一律写全 |
| **nit-3** 320px 那条把 `ListEditorSheet` 直接放在 `Scaffold.body` 里量，与生产入口（`showModalBottomSheet(isScrollControlled: true)`）不同拓扑 ⇒ 宽松约束可能掩盖溢出 | 查同仓先例：`test/features/task/task_quick_add_sheet_test.dart:171` 就是从 `showModalBottomSheet` 入口量。复核对，我这层的"body 也能量"是推理不是证据 | **采纳**（`5460283`→`5475e63`）。改按生产拓扑：主页放一个按钮 → `showModalBottomSheet` → `ListEditorSheet`。**改完必须重证这条有力** ⇒ 新增探针 `PV`（操作行「取消」撑长）实测 `+14 -1`、只红 320 那条、红在 `RenderFlex overflowed by 250 pixels`；PM′ 也重跑一遍仍是 `+3 -12` 且 320 不红 |

第 3 轮复核还独立复核了"撤销展开态溢出断言"这一决定，结论是**作者结论成立**（它自己量到
`_DropdownMenu` 的候选列表被 `getConstraintsForChild` + `ListView` 夹在可用尺寸内），
所以那条撤销不是我在给自己找台阶 ⇒ 记在这里，免得下一轮又有人去补那句恒真断言。

## 相撞面

`lib/features/list/list_editor_sheet.dart`、`test/features/list/`、`specs/049-*` 与
**10 条 open PR 的改动文件表逐条比对（`/pulls/N/files`）命中 0** ⇒ 不同文件，无需 merge-tree 复测。
（清单第 3 版复核时是 10 条：!311 !314 !319 !322 !346 !347 !350 !351 !352 !354；
新开的 !354 动的是 `folder_actions.dart`/`folder_page.dart`/`sidebar.dart`/`specs/050-*`/`test/features/folder/`，
与本 PR 的两个 dart 文件无交集。）
（第 69 轮那条 `feat/312-folder-disband-entry` 也过 `list_editor_sheet.dart` 吗？不过 —— 它动的是
`folder_actions.dart`/`sidebar.dart`/`folder_page.dart`；但它与 !351 在 `sidebar.dart` 撞了一处，
记在 `specs/050-*/tasks.md`。）

## 下一轮入口

1. #339 剩下两格：清单 **颜色** 与 **Emoji 图标**（`spec.md` 已记为何不在本轮）。
   顺序建议：先在 `zh-cloud-service` 给 `TodoListDO` + `AppTodoListSaveReqVO` 加 `color`/`emoji`，
   bump 增量 SQL，再回来动 Flutter（本地 `schemaVersion` 也要 22→23）。
2. 弹层里 `Row + Spacer` 的操作行：`#320px + 1.3` 本轮没溢出（按钮文案短），
   但同形状的 `quick_add_bar` 在第 66 轮实测溢出过 ⇒ 真加字段（颜色/图标按钮）时要按 `Wrap` 重测。
3. 矩阵 #19 的「已实现待合并」注记走 docs !105 留言，不再新开第 12 条同文件 PR（第 67 轮的判断照用）。
