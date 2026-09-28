# 050 · 文件夹「解散」入口 · 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/312-folder-disband-entry`。Issue **#312**（矩阵 **#18**）。
判据、范围与取舍见同目录 `spec.md`；落点与实现要点见 `plan.md`。

## 勾选（只勾真满足的）

- [x] FR-1 侧栏**长按文件夹行** ⇒ 「解散文件夹」二次确认；确认后其下清单回顶层、直接子文件夹提升为顶层
      ⇒ **但"回顶层"只改本地**：outbox 里没有对应的 `list/*` 记录（成对 ABSENT 断言钉着），
      服务端 `deleteFolder` 会按 `TODO_FOLDER_HAS_LISTS` 拒收 `folder/delete` ⇒ 解散非空文件夹不收敛。
      契约缺口 = **zh-cloud-service #285**，本面在矩阵 #18 因此不翻「有」
- [x] FR-2 取消 ⇒ 一个字都不写（读库 + 数 outbox 行数）
- [x] FR-3 单一口径：`FolderPage` 的那个按钮改调同一个函数，标题「解散文件夹」、按钮「解散」（探针 PF 证：让它退回自己那份就红）
- [x] FR-4 9 张黄金基线未重录（门禁 4 `+9`，`git status --short test/goldens` 为空；对话框是长按才出现的路由，不参与首帧）
- [x] FR-5 四件套（见下表；`_confirm()` 的两个失败出口各有用例，探针 PH/PI 证）
- [ ] #312 的另两子面：**`:18` 清单编辑器里的「添加文件夹」**（落点是 `list_editor_sheet.dart`，与本轮自己刚开的 !352 同文件同区域 ⇒ 排在它合并之后）、**`:12` 拖动清单建文件夹**（要改侧栏可见布局 ⇒ 先申请重录黄金基线）
- [ ] 「左滑解散」（`:30` 并列的另一种手势）**没做**，理由见 `spec.md`「本轮不做」第 3 条 ⇒ 这一面按"可达但少一种手势"记，不宣称一字不差
- [ ] 桌面端右键解散（`:30` 后半句）没做 —— 侧栏现在没有右键通道
- [ ] 只读复核 **待派**
- [ ] 矩阵 #18 回写 —— 本轮开工时 `state=open` 实测 9 条（!352 !351 !350 !347 !346 !322 !319 !314 !311），除 !352 外一条没合并 ⇒ 只能写「已实现待合并」，状态列不翻转

## 四件套（新增可见界面 = 那个确认对话框）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 字号打在 `tester.platformDispatcher.textScaleFactorTestValue`（弹层是 root Navigator 上的路由，包在 `home` 子树里的 `MediaQuery` 到不了它），视口 320×700，断 `takeException()` 为 null 且两个按钮 `hitTestable()`。**牙齿不在我自己的探针表里**（复核 F3）：PE 下这条红是因为文案没了 ⇒ 几何判据是我没证过的一半。复核员 X2 把字号改成 3.4 才量到：`Expected: null Actual: 'Multiple exceptions (4)'`，其中一条溢出的 creator 是 `Column ← IntrinsicWidth`（= `AlertDialog` 自己的 content 列，`constraints w=224, h≤117`），日志 `/tmp/rv69_X2_34.log` ⇒ 判据有力，但**这条证据来自复核员**，不算我本轮自证 | `320px + 1.3 倍字号：确认框排得下且按钮可命中` |
| 独立读屏语义 | `AlertDialog` 的 title 与 content 实测是**两个**语义节点 ⇒ 分别用 `^解散文件夹$` 与 `确认解散"项目"` 断言，并加正向对照 `确认解散"生活"` ⇒ `findsNothing`（不写跨节点正则，那在本仓第 68 轮刚踩过） | `读屏念得出「解散文件夹」，且念的是被解散的那一个` |
| 失败保留已加载数据 | **三个**出口：`delete` 抛错 ⇒ 框不关 + 文件夹还在 + 错误写在框里 + 重试能成；`folderRepositoryProvider` 为 null ⇒ 同样不关框、给提示、库里不写；仓库后来就绪 ⇒ 提示清掉、重试真的解散 | `解散失败…` + `仓库在点确认时已不可用…` + `仓库后来就绪…` |
| 过期/重复响应不覆盖 | 连点两下只发一次 `delete`：假仓库用 `Completer` 门控（立即返回的 stub 会让第二次 tap 落在正在关闭的表面上 ⇒ 恒真绿），先断 `pending.length == 1` 再逐条回包 | `解散请求挂起时再点一次「解散」：只发一次` |

另有一条不属于四件套但同样关键的：**手势不串味**（`ExpansionTile` 外面包 `GestureDetector` 后，其下清单行的长按仍是清单动作）
⇒ `文件夹展开后，其下清单行长按还是清单动作（手势不串味）`。

## 反向探针（每条先证探针本身打上了：替换后字节必须与 HEAD 不同）

**口径：跑单文件** `test/features/folder/folder_disband_entry_test.dart`，12 条用例。
脚本 `/tmp/r69/probes.py`（崩溃也走 `finally` 还原），汇总 `/tmp/r69/PROBES_12.log`，跑完 `RESTORE cmp: SAME`。

| 探针 | 抽掉什么 | 结果 | 红在哪条 |
| ---- | -------- | ---- | -------- |
| PA | develop 字节（侧栏无长按 + FolderPage 仍是「删除文件夹」） | `+0 -12` | 12 条全红 ⇒ 这批用例整体就是红测 |
| PB | 侧栏不接长按（摘掉 `onLongPress`） | `+1 -11` | 11 条红；绿的仍是「FolderPage 走同一个框」那条（它不经侧栏） |
| PC | 去掉 `_busy` 同步闸门 | `+11 -1` | 「连点只发一次」那条 |
| PD | 失败也把框关掉 | `+11 -1` | 「解散失败：框不关…」那条 |
| PE | 用词退回「删除文件夹」/「删除」 | `+2 -10` | 10 条红（用词是判据，不是审美）；绿的 2 条是「取消 ⇒ 一个字都不写」与「手势不串味」，它们本来就不看文案 |
| PF | `FolderPage` 不委托、留自己那份（两份口径） | `+11 -1` | 「FolderPage 的那个按钮走同一个确认框」那条 |
| **PH** | **仓库为 null 时静默 return**（摘掉整段 `setState`） | `+10 -2` | 「仓库在点确认时已不可用」+「仓库后来就绪」两条 ⇒ 补测前这两支是 0 覆盖 |
| **PI** | null 分支给了提示但**不复位 `_busy`**（框会卡死） | `+11 -1` | 只红「仓库后来就绪：重试真的解散」⇒ 这条用例钉的不只是提示 |
| PG | `deferToChild` 换成 `opaque` | `+12`（**不红**） | 结论如实记：**这条用例不覆盖 `deferToChild` 这个选择**。长按点的仲裁是"最深先赢"，父行 `opaque` 也抢不走子行的长按 ⇒ 换掉它没有可观测差异。留着 `deferToChild` 是按语义（父行只在自身像素上接管手势），不声称有用例钉 |
| **PL** | 子文件夹提升只改本地、不排 `folder/upsert`（**新 PRESENT 判据的牙齿**，复核 F2 之后补） | `+11 -1` | 只红「确认解散 ⇒ …且留下同步记录」，红在 `Expected: {folder/upsert#r69-child-folder, folder/delete#visual-folder-projects}` / `Actual` 少一条 ⇒ 旧的"数条数"判据在这种半漏下是给绿的 |
| **PM** | `folder/delete` 整条不排队 | `+11 -1` | 同上那条，`Actual` 只剩 upsert ⇒ PRESENT 的另一半也会咬 |
| PN | `folder/delete` 挂错实体（`folder` ⇒ `list`） | `+11 -1` | 同上那条，`Actual: {folder/upsert#…, list/delete#…}`。⚠️ **红的是 PRESENT 那句**（它先判）⇒ 这条**不能**拿来声称旁边那句 ABSENT `list/` 有独立牙齿。ABSENT 只在"用例开始前 outbox 里已有 `list/` 记录"这种场景才可能单独火，那种场景我没做出变异 ⇒ 不声称 |

探针口径：上表 12 条全部在 tip `ea9d024`（outbox 判据换掉之后）**整批重跑**，
脚本 `/tmp/r69/probes2.py`、汇总 `/tmp/r69/PROBES_v2.log`（每条的 rc/汇总行/红因/Expected-Actual 都在这一个文件里，
本轮没有再拆单条日志文件），跑完 `RESTORE cmp: SAME`。PA–PI 的九个数字与判据改造前**逐个相同**（改的是同一条用例里的两句断言，
没有增减用例）；PL/PM/PN 是为新判据补的三条。复核员自己那批（PA–PJ + X2/X4/X5，日志
`/tmp/rv69_*.log`）与我的 PA–PI 数字一致。

## 只读复核（第 1 版 `VERDICT: PASS`：0 条 P1、2 条 P2、5 条 nit）

复核在副本 `/tmp/rev69-copy`（全量跑 `/tmp/rev69-full`）上做，原树未被写（`WORKTREE_CLEAN: yes`）。
12 条用例逐条能红、9 个探针数字与 6 项门禁全部复现、9 张黄金基线逐字节未变。处置：

| 发现 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **F1 (P2)** `plan.md` 要点 3 说 `_busy` 的代价是"第二次会多出一条 outbox 记录"；复核用 X5（`Future.wait` 同帧并发两次 `delete`）量到 outbox 仍是 2 条 ⇒ 说法不成立 | 读 `folder_repository.dart:87-149`：第二次进 `delete` 时 `row == null` ⇒ `serverId = null` ⇒ 走"从未到过服务端"的早退分支（清空待重试 create、不 enqueue）⇒ 复核对 | **采纳**（`ea9d024`）。`plan.md` 与 `folder_actions.dart` 的注释都改成"闸门钉的是『只发一次』这条判据，不是防数据损坏" |
| **F2 (P2)** `spec.md` FR-1 与 `tasks.md` 勾选都写"两条都留 outbox"，而用例只断 `syncRows > before` ⇒ 判据弱于文档，1 条也能过 | 对。且顺着这句回源读出**更大的问题**：`delete` 里被移出的清单**根本没有** outbox 记录（只改 `todoLists` 表），而服务端 `TodoFolderServiceImpl.deleteFolder:89-92` 见 `countByFolderId > 0` 就抛 `TODO_FOLDER_HAS_LISTS`（`1_020_001_020`）⇒ 解散非空文件夹时那条 `folder/delete` 永远被拒，`sync_coordinator.dart:105/:140` 会把 `failed` 重新拾取 ⇒ **不收敛**。这不是本轮引入的（develop 的 `FolderPage` 早就在调同一个 `delete`），但它是"解散"这面的真缺口 | **两条都采纳**。① 用例改成逐条对上（PRESENT）+ 成对 ABSENT，新探针 PL/PM/PN 证明它会咬；② 契约缺口立 **zh-cloud-service Issue #285**（推荐服务端把 DELETE 做成嘀嗒语义的"解散"：清空清单归属 + 提升子文件夹 + 删夹，一个事务），`spec.md` FR-1 写明边界，**矩阵 #18 不翻「有」** |
| **F3 (nit)** `tasks.md` 四件套 (a) 行没有任何探针证明"几何"会咬（PE 下那条红是因为文案没了） | 对，我的探针表证不到这一半 | **采纳**。表格改成显式写"这条牙齿来自复核员的 X2（1.3⇒3.4，红在 `Multiple exceptions (4)`，creator 链 `Column ← IntrinsicWidth`）"，不冒充自证 |
| **F4 (nit)** `folder_actions.dart:85`「移至"未分组"」不是嘀嗒的词（帮助中心全文 0 命中） | 对，但它是从 develop 的 `folder_page.dart` 原样搬来的，本轮没新造 | **记债不改**（改它要连带改 develop 的文案口径，超出本轮范围）。写进下一轮入口 |
| **F5 (nit)** 侧栏长按 fire-and-forget、无重入保护 ⇒ 连按两次长按会叠两个确认框，第二框对已消失的文件夹解散 ⇒ 显示「解散失败，请重试」 | 静态读 `sidebar.dart:532-536` 成立：`onLongPress` 不 await、也没有"已有对话框"的判据。**未跑成用例**（要造二级手势时序，本轮没做）⇒ 按"静态读出的缺陷先查可达"的规矩，只登记不立单 | **记债**，写进下一轮入口 |
| **F6 (nit)** 新入口只有手势、没有语义动作 ⇒ 读屏用户到不了「解散」 | 对。四件套②只覆盖对话框自身，不覆盖"能不能被读到入口" | **记债**，与 specs/026 的侧栏读屏债并一条 |
| **F7 (nit)** `deferToChild` 与 `opaque` 无可观测差异（= 我的 PG 自己披露的） | 复核确认，措辞诚实 | 无需改 |

`VERDICT: PASS` ⇒ 按"两轮无新结论就停下请示"的规矩不再刷第 2 版复核；F2 挖出的契约缺口
按"后端缺契约先修契约"的规矩转成 service Issue，不藏在客户端里。

## 门禁原文记录（跑在 tip `3b7fa6e` 的 dart 字节上，日志 `/tmp/r69/gates_13.log`）

这是**第 2 遍**：第 1 遍跑在 `8273c56`（日志 `/tmp/r69/gates_12.log`，`02:42 +910 ~26`）；
复核后的判据改造只动了一个测试文件与两处注释 ⇒ 用例数没增减，但六条**全部重跑**，本表是这一遍。

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 4 个显式文件>` | `Formatted 4 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 2.3s)`，`rc=0` |
| `flutter test --tags golden` | `00:05 +9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:28 +910 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

计数对账：`+910 = 898 + 12`。898 是第 68 轮在 develop 副本 `/tmp/r68-baseline` 实测的基线
（日志 `/tmp/r68/baseline_develop.log`，`02:53 +898 ~26`）；12 = `git diff --name-status origin/develop...HEAD -- test`
里唯一的 `A`（本轮新增的那个测试文件）的用例数。`~26` 未新增 skip。
`pubspec.lock` 未进提交（前提：门禁与 `source ~/development/env-flutter.sh` 同 shell）。

## 相撞面（实测）

`lib/features/shell/sidebar.dart` 与未合并的 **!351**（侧栏「显示标签」）**同文件**：
两边都在 import 区新增一行（各自的新第 9 行）⇒ `git merge-tree --write-tree` 报
`CONFLICT (content): Merge … sidebar.dart`。这是**真冲突但极小**（两行 import 并列，合并时都保留即可），
已在 PR 正文写明；其余 `folder_actions.dart`、`folder_page.dart`、`test/features/folder/`、`specs/050-*` 与各 open PR 命中 0。
`list_editor_sheet.dart` **故意没碰** —— 那是 !352 的地盘，`:18` 的「添加文件夹」排在它合并之后。

## 下一轮入口

1. #312 剩余：`:18` 清单编辑器「添加文件夹」（等 !352 合并后在同一个 sheet 里做）。
2. `:12` 拖动清单到另一清单上方建文件夹 ⇒ 要改侧栏可见布局，按约定先申请重录 9 张黄金基线。
3. `FolderPage` 与它的宿主 `ListPage` 在 develop 上仍**不可达**（`ListPage` 全仓无人 push）：
   新建/重命名这两件事还没有入口。`spec.md` 取舍 1 已记，本轮不顺手删；单独立项。
4. **矩阵 #18 主表行是过期的**：docs 分支 `docs/104-repeat-rule-parity`（PR !105）上
   `dida-parity-matrix.md` 的 **#18 行**（按矩阵行号引，不引文件行号；跨仓文件行号本仓自扫器判死锚，见 FL Issue #394）仍写「有 / BE/WEB/FL」+「FL 文件夹 UI 待 B2」，
   而同一文件 `:295`（第 0 轮表）早就判「有 → 部分 / 管理 UI 不可达」。行号基准是 !105 的 head，
   不是 develop（那边同一文件行号不同）。下一轮 docs 按代码现况把**主表行**
   重判为「部分 / BE/FL」，注记：解散入口 = 本 PR !354、所属文件夹 = !352（两条都还没合并 ⇒ 只写「已实现待合并」），
   并把 **zh-cloud-service #285**（服务端 DELETE 不是"解散"语义 ⇒ 非空文件夹解散不收敛）写成缺口。
   走 !105 追加，不再新开第 12 条同文件 PR。
5. **service #285 的修法要先定**：推荐服务端把 `DELETE /app-api/todo/folder` 改成嘀嗒的「解散」
   （清空清单归属 + 提升子文件夹 + 删夹，一个事务，去掉 `TODO_FOLDER_HAS_LISTS`）。
   若那边改完，本仓 `folder_repository.dart:87` 的 ABSENT 断言要连带复核（清单移出是否需要补 `list/upsert`）。
6. 复核 F5：侧栏长按无重入 ⇒ 连按两次叠两个确认框（静态读成立、未跑成用例）⇒ 与 #312 的
   「对话框叠层」一并处理，别单独立小单。
7. 复核 F6：「解散」入口只有手势、没有语义动作 ⇒ 读屏用户到不了。与 specs/026 的侧栏读屏债并一条。
8. 复核 F4：`folder_actions.dart:85`「移至"未分组"」不是嘀嗒的词（帮助中心全文 0 命中），
   是从 develop `folder_page.dart` 原样搬来的 ⇒ 要改就连 develop 的口径一起改，单独一轮。

## 与 develop 收口（本轮终头 `7c14392ab`）

**为什么有这一节**：前几轮 PASS 绑 `544934c8`，其 `544934c8:lib = 5e577f44c`，
本轮 head 的 `:lib = 617d3df7a` ⇒ 代码字节变了，覆盖面必须重绑。

**冲突与解法**：冲突只在 import 段：本单要 `../folder/folder_actions.dart`（文件夹行长按走 `confirmAndDisbandFolder`），develop 同期要 `state/repositories/sidebar_visibility_repository.dart`（侧栏显隐偏好）。两条在 head 上都各有真用（`git grep -c confirmAndDisbandFolder <head> -- lib` 与 `git grep -c sidebarShowTagsProvider <head> -- lib`），⇒ 取并集并按 directives_ordering 排（`../../` 在 `../` 之前），没删任何一侧。
本轮触达 `7` 个文件，其中 `.dart` `4` 个：`lib/features/folder/folder_actions.dart`、`lib/features/folder/folder_page.dart`、`lib/features/shell/sidebar.dart`、`test/features/folder/folder_disband_entry_test.dart`。
合并提交 = `544934c80`（HEAD 的第一父）。

**六道门禁跑在终头 `7c14392ab` 上**（门禁日志在仓外 `/tmp/gates-354.log`；下面每个读数旁给了复算命令）：

| 门禁 | 读数 |
| ---- | ---- |
| 1 `git diff --check origin/develop...HEAD` | rc=0、输出 0 行 |
| 2 `dart format --output=none --set-exit-if-changed`（全部 4 个 `.dart` 触达文件） | rc=0 |
| 3 `flutter analyze` | No issues found! |
| 4 `flutter test --tags golden` | +9: All tests passed!（基线 9 张未重录） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 03:08 +1054 ~26: All tests passed! |
| 6 `flutter build web --release --dart-define=…` | ✓ Built build/web |

门禁脚本在两个仓之间串跑时记录的 `pubspec.lock` 脏行数 = 0（本机镜像不随 PR 走）。

**矩阵行**：本 PR 未合并 ⇒ docs 矩阵对应行仍写「已实现待合并 + PR 号」，不翻状态；
合进 develop 后由 docs 侧换成合并 SHA。
