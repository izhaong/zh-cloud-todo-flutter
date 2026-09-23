# 任务清单：快速添加弹窗的「从模板添加」

分支 `feat/todo-quick-add-from-template`，基线 `develop@a1d7733`，Issue izhaong/zh-cloud-todo-flutter#287。
矩阵行：#7「添加任务」的模板面（同时消掉 #89 行「模板仍无笔记页/添加流程入口」那一格的前半）。

## 已做

- [x] **T001 取证到 SHA**：嘀嗒原文 `02-任务详情.md:346`（移动端 tab）「点击任务输入弹窗**下方**的「...」按钮，选择「**模板**」即可从模板添加任务」；
      本端 `task_quick_add_sheet.dart` 全文 173 行只有标题 + 优先级 + 取消/保存，零模板入口；
      模板的保存/应用只在详情页 `task_detail_pane.dart:2339/3559/3566-3586/3628-3651`。
- [x] **T002 红测先行**：`test/features/task/quick_add_from_template_test.dart` 8 例，基线一条都不过，
      失败信息精确指向缺失项 —— `Found 0 widgets with key [<'todo-quick-add-more'>] / means none were found but one was expected`
      （日志 `/tmp/r19-red.log`，原文 `00:01 +0 -8: Some tests failed.`）。
      写用例时自己制造过两处假阳性并已修：① 按标题查新建任务会连**模板的来源任务**一起数到（2 条），改为 `exceptId: source.id`；
      ② 「未登录」例原本 seed 了模板，而 `saveTask` 本身写一条 outbox ⇒ 「outbox 为空」是假断言，该例改为不 seed。
- [x] **T003 最小实现**：`task_quick_add_sheet.dart` 下方行首加 `PopupMenuButton`（key `todo-quick-add-more`，菜单项文案「模板」），
      选后 `showModalBottomSheet` 打开 `_QuickAddTemplatePicker`（root key `todo-quick-add-template-sheet`），
      行内 `添加` 走 `templates.taskSeed(t)` → `taskRepository.create(listId/parentTaskId/title/description/priority)`，
      提示沿用详情页既有「已应用模板“X”」；空态「暂无本地模板」；仓储 `null` ⇒「请先登录」。
      未新增创建路径、未改 `pubspec.yaml`（`file_picker: ^11.0.2` 已在 `:41`，本切片不需要它）。
- [x] **T004 反向探针 6 条**（脚本 `/tmp/r19_probes.py`，每轮摘完立即还原并 `cmp -s`）：

      | 探针 | 摘掉什么 | 实测红用例 | 归因 |
      | ---- | -------- | ---------- | ---- |
      | PA | 整个 `PopupMenuButton` | **8 条全红** | 入口不存在 ⇒ 全部判据失效，符合预期 |
      | PB | `parentTaskId: widget.parentTaskId,` | 2 条（第 3、第 6 例） | 第 6 例也红 = 失败路径本身就经由 parent 归属校验，不是巧合 |
      | PC | `description: seed.description,` | 1 条（第 2 例） | 丢模板说明被咬住 |
      | PD | `if (_applyingTemplate) return;` | 1 条（第 7 例） | 守卫确被同帧双 tap  exercised |
      | PE | 未登录分支的 `_toast('请先登录')` | 1 条（第 5 例） | 「点了没反应」会被抓到 |
      | PF | `on StateError catch` 那一支 | 1 条（第 6 例） | 只剩通用文案 ⇒ 断言原因的用例红 |

      六条 `restore cmp=identical` 全部成立。
- [x] **T005 `dart format` 门禁抓到自家新文件不合规**：`--output=none --set-exit-if-changed` 首轮
      `Changed test/features/task/quick_add_from_template_test.dart` / `exit=1`（lib 文件 `exit=0`）⇒ 本轮新写的文件真修过，
      不是存量欠债。只 format 这一个文件（未整仓原地格式化），复跑 8 例仍绿，并在新字节上重跑全部探针。
      注：这次红只存在于终端输出，**没有单独落日志文件**（最终态绿的那次才在 `/tmp/gate-036.log`）。
- [x] **T006 六项门禁跑在最终字节**：见下表，日志 `/tmp/gate-036.log`。
- [x] **T007 只读复核拿到 VERDICT 并逐条处置**：第 1 轮 `VERDICT: FAIL`，7 条 blocker 全部复验为真、全部照改；
      NIT 8 条采纳 5 条、写明理由拒/部分拒 3 条（见下节）。修复后六项门禁在最终字节上重跑，见「第 2 次门禁」表。
      第 2 轮 `VERDICT: PASS`（0 blocker / 9 NIT，见「第 2 轮复核处置」节）⇒ 两轮封顶用尽，不再要第 3 轮。
      第 2 轮复核**待派**（两轮封顶：PASS 就记结论，FAIL 只照它改一次、不再派第 3 轮）。

## 第 1 轮复核处置（`VERDICT: FAIL`，7 BLOCKERS / 8 NITS）

复核手段：本会话只读子代理（`claude` CLI 不可用，理由见「限制」）。它在 `sha256` 与本轮字节一致的副本
`/tmp/g036-probe` 上跑实验，仓内文件未被写入。**7 条 blocker 我逐条回原码复验，没有一条是误报**，故全部照改。

| # | 复核结论 | 我本地复验到的事实 | 处置 |
| - | -------- | ------------------ | ---- |
| B1 | `spec.md:54-55` 的「全仓 `test/` 内 `TaskQuickAddSheet` 零命中」是假 | `git grep -c TaskQuickAddSheet HEAD -- test` ⇒ `task_quick_add_sheet_test.dart:2` 与本轮新文件各 2 处 | **照改**：零命中范围收窄到 `test/visual/`，并承认既有用例已覆盖「保存」那条失败路径（用例 6 是「模板」入口，弹层是否打开不同，两条都留） |
| B2 | `taskSeed` 在 `try` 外、守卫不在 `finally` ⇒ 一条坏模板永久锁死入口且零反馈 | 直读 `:100-122`：`try` 从 `:104` 起，复位在 `:122` 裸写；`taskSeed` 是 `jsonDecode(...) as Map<String,dynamic>`（`template_repository.dart:105`），`contentJson` 由 pull 原样落库 | **照改**：`taskSeed` 挪进 `try`、复位进 `finally`；补用例 9 + 探针 PC（红测原文 `type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast`） |
| B3 | `sheetContext.mounted` 挡不住误关宿主弹窗 | `:123` 就是 `if (sheetContext.mounted) Navigator.of(sheetContext).pop()`；反向动画期间元素仍 mounted，pop 打到下一层路由 | **照改**：`ModalRoute.of(sheetContext)` 捕获 + `isCurrent` 才 pop；补用例 10（挂起假 `TaskRepository` 把窗口钉死）+ 探针 PD |
| B4 | 三条提示在生产里看不见（SnackBar 被本弹窗这层路由盖住） | 两个宿主（`task_detail_pane.dart:946`、`kanban_view.dart:251`）都是 `showModalBottomSheet` + `isScrollControlled`，弹窗自身无 `Scaffold` ⇒ messenger 解析到根 | **照改**：`_toast` 换成 `_report`（`setState` 一行 `Text`，key `todo-quick-add-feedback`），断言改为「必须落在弹窗子树内」；探针 PE 把 `_report` 换回 SnackBar ⇒ 4 条齐红。**存量同源缺陷 `_save()` 里那两条 SnackBar 不在本切片改**，另开治理 Issue |
| B5 | 「...」按钮语义节点空标签，套件从不检查 | `:195` 是 `child: const Icon(...)`；复核员 dump 到 `label:""`。**但它建议的修法（改用 `icon:`）实测不成立**：本会话 `child:` 与 `icon:` 两种写法在 `ensureSemantics()` 后都拿不到 `'更多'` | **照改，修法不同**：显式 `Semantics(label:'更多', button:true, container:true)` 包裹；用例补 `bySemanticsLabel('更多')`，且 `ensureSemantics()` 之后必须再 `pump()` 一帧（否则恒 0 命中＝空转）；探针 PF 把 label 换成同义词 ⇒ 用例 1 红 |
| B6 | 目标清单这一维从未被验（把 `listId` 写成字面量 `'inbox'` 全绿） | 8 例都 pump `inboxListId`，模板来源任务也在收集箱 | **照改**：补用例 11（弹窗开在 `workListId`）；探针 PG 硬编码 `'inbox'` ⇒ 用例 11 红 |
| B7 | 守卫「复位」无覆盖（删掉 `_applyingTemplate = false` 全绿） | 原用例 7 只测「挡住第二次」 | **照改**：补用例 12（同弹窗连挑两次 ⇒ 两条）；探针 PB 删复位 ⇒ 用例 12 红 |

NIT（逐条采纳/拒绝，拒的要留理由）：

- ✅ **死分支**：`taskRepositoryProvider` 与 `templateRepositoryProvider` 的 null 条件完全相同（`providers.dart:151-156` / `:297-302`）⇒ `templates != null` 时 `repo` 必不为 null。已删该分支。
- ✅ **「不再实现第二份列表逻辑」措辞不实**：弹层确实又写了一份渲染。已在 `plan.md` 落点表里更正为「数据链路与措辞同源、渲染是第二份」，并把 `已同步/等待同步` 在 `test/` 内 0 命中记进「仍缺」。
- ✅ **用例 5 的 outbox 断言近乎恒真**：已在 reason 里降级为「只能挡未来往这条路径加写库」，并补「弹层未被打开」的断言。
- ✅ **模板路径忽略 `taskCaptureDefaultsRepositoryProvider.defaultPriority`**：不采纳为「本切片修」——模板的语义就是「按当时存下的那套值建任务」，覆盖用户的新任务默认值是嘀「从模板添加」的应有行为；已在「仍缺」留一条待人工在嘀嗒上核。
- ✅ **「选择后即建 vs 预填」不是已证实的 parity**：`02-任务详情.md:346` 只说「即可从模板添加任务」，没说弹窗是否留手输内容。已在「仍缺」保留为待人工核验项。
- ❌ **动作词「添加」与详情页「应用」不一致要统一**：**暂不采纳**。嘀嗒原文用的是「从模板添加任务」⇒ 「添加」更贴源；已在 `plan.md` 写明理由与推翻条件。
- ❌ **`tooltip: '更多'` 不是嘀嗒措辞**：**保留**并标注为本端措辞（嘀嗒那页 `:372` 的另一处「...」菜单也这么写），不是抄来的词。
- ❌ **用例 8 的两条 `textScalerOf(...).scale(10)` 只是在量 harness**：**部分采纳**——`takeException` 才是实体断言这一点写进 `plan.md`；但档位自检保留，且已改成「反馈行出现之后」再量，避免只测初始态。

**本轮自己引入又被门禁抓到的两处**（不是复核员提的，记下来防重犯）：`use_build_context_synchronously`
（`Navigator.of(sheetContext)` 只留了 `isCurrent` 判定，丢了 mounted 判定）与 `use_super_parameters`
（测试里的假仓储该用 `super.` 形参）。⇒ 门禁 3 首轮 `2 issues found`，改完重跑。

## 反向探针（第 2 次，最终字节，脚本 `/tmp/r20_probes.py`）

| 代号 | 摘掉什么 | 结果 |
| ---- | -------- | ---- |
| PA | `if (_applyingTemplate) return;` | `+11 -1`，红在「连点两次「添加」只建一条任务」 |
| PB | `finally` 里的 `_applyingTemplate = false;` | `+10 -2`，红含「同一个弹窗里连挑两次模板」 |
| PC | 把 `taskSeed` 挪回 `try` 外 | `+11 -1`，红在「模板内容坏了…」，异常原文 `type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast` |
| PD | `isCurrent` 判定换回 `sheetContext.mounted` | `+11 -1`，红在「用户先把模板弹层滑掉…」 |
| PE | `_report` 换回根 SnackBar | `+7 -5`，四条提示用例齐红 |
| PF | `Semantics` 的 label 换同义词 | `+11 -1`，红在「弹窗下方有「...」…」 |
| PG | `listId: widget.listId` → 字面量 `'inbox'` | `+11 -1`，红在「弹窗开在别的清单时…」 |
| PH | 菜单项「模板」→「从模板添加」 | `+0 -12`（全文件都靠 `find.text('模板')` 开弹层，措辞一改全体红） |
| PI | 删掉空态 `Text('暂无本地模板')` | `+11 -1`，红在「一个模板都没有时…」 |

9 条探针逐条红、`cmp -s` 证明摘完还原后与基准**逐字节一致**（输出 `IDENTICAL`）。
第 1 轮那 6 条（PA–PF 旧编号）未重跑：本轮把 `_addFromTemplate` 整段改写了，旧探针的锚文本已不存在，
故上表是**在最终字节上重新推导的等价集**（覆盖守卫挡住/复位、try 边界、pop 判据、反馈可见性、两处措辞、空态）。

## 第 2 次门禁（复核修复后的最终字节，日志 `/tmp/gate-036-r2.log`）

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `rc=0` |
| 2 `dart format --output=none --set-exit-if-changed` 两个显式文件 | `Formatted 2 files (0 changed) in 0.03 seconds.` / `rc=0` |
| 3 `flutter analyze` | `No issues found! (ran in 1.4s)` / `rc=0`。**首轮这里是 `rc=1`：`2 issues found`** —— `use_build_context_synchronously`（`Navigator.of(sheetContext)` 只留了 `isCurrent`）与 `use_super_parameters`（测试里的假仓储），两处都是本轮改出来的，已真修（不是跳过） |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` / `rc=0` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:54 +721 ~26: All tests passed!` / `rc=0`（= 基线 709 + 本切片 12 例） |
| 6 `flutter build web --release …` | `✓ Built build/web` / `rc=0` |
| 7 `test/goldens` 改动数 | `0`（`git status --porcelain test/goldens \| wc -l`） |
| 8 sha256 前 16 位 | `4f082f98f16242b4` `task_quick_add_sheet.dart` / `33be868e647aa9fa` `quick_add_from_template_test.dart` |
| 9 工作区脏文件 | ` M pubspec.lock`（本机 SDK 重解析，不入库）+ lib/test 两件 + specs/036 三件套 |

⚠️ 第一次跑门禁时后台脚本没 `source ~/development/env-flutter.sh` ⇒ gate2–6 全 `rc=127`（命令根本不存在）。
那一份日志**不算任何门槛通过**，本表是重跑后的；记下来防「拿 127 当红、或当绿」。

- [x] **T008 回写矩阵行**：`zh-cloud-docs@36a48db`（分支 `docs/dida-parity-matrix-round0`，PR !69）
      #7 行的「仍缺」原本写 `—`（等于宣称已齐），实际嘀嗒《添加任务》`:54` 的下拉里有三样 ⇒
      补回「优先级（有）/ 添加附件（快速添加弹窗内没有）/ 从模板添加（!288 待合并）」，
      并记本切片锚点（行号标基准 `feat/todo-quick-add-from-template@ddfcb5a`）；
      #89 行补一句防误读：模板**并非**完全无入口，缺的是笔记页那一格。
      状态仍留「已实现待合并」，合并后才翻 SHA。**全表扫描 458 行单元格数与表头一致、`git diff --check` 0。**

## 门禁（最终字节，日志 `/tmp/gate-036.log`）

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 两个显式文件 | `Formatted 2 files (0 changed)` / `exit=0`（首轮 `exit=1`，T005 已真修） |
| 2b 同检查跑在 `git show HEAD:` 版 | `Formatted 1 file (0 changed)` ⇒ HEAD 里的 lib 文件本就合规，本轮没新增排版欠债（test 文件是新增，无 HEAD 版） |
| 3 `flutter analyze` | `No issues found! (ran in 1.7s)` |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:53 +717 ~26: All tests passed!` |
| 6 `flutter build web --release …` | `✓ Built build/web`（`Compiling lib/main.dart for the Web... 19.6s`） |
| 7 `test/goldens` 改动数 | `0` |
| 8 sha256 | `7f12bc08` `task_quick_add_sheet.dart` / `8e46ebba` `quick_add_from_template_test.dart` |
| 9 工作区脏文件 | ` M pubspec.lock`（本机新 SDK 重解析，按口径不入库）+ 本轮 lib/test 与 specs/036 三件套 |

**同基线复算**：`develop@a1d7733` 非 golden = **709**（`/tmp/base-034.log`）；本轮 8 例 ⇒ 期望 `709 + 8 = 717`，与第 5 项原文一致；
跳过 26 未变；golden 9 张 0 改动、`test/goldens` 无 diff ⇒ 没有顺手改基线，也没有重录。

## 限制（不算通过证据的部分）

- **复核手段替换**：`claude` CLI 本机不可用（`unrecognized_model`），改用本会话只读子代理审本轮 FR（要求它反向攻击 FR 符合度、
  用例假阳性、静默丢数据、失败路径、不可追溯的数字）。
- **依赖集**：门禁跑在本机 `pubspec.lock`（本机重解析，不入库）之上，CI 解析的是仓库 lock ⇒ 本地绿不覆盖远端解析差异。
- **平台面**：本地 Dart 门禁不替代 iOS/Android 编译、真机行为、双设备同步；`build web` 只证明 Dart 侧可编译到 web。
- **黄金覆盖面**：9 张黄金不泵 `TaskQuickAddSheet` ⇒ 只证明既有画面无回归，**不证明本入口在真实视觉基线里长什么样**。

## 仍缺（诚实清单）

- 桌面端两条 IA 未做：「输入框下拉按钮 → 从模板添加」（`02-任务详情.md:354`）与「输入 `/` 打开斜杠菜单 → 从模板添加」（`:358`）。
  斜杠菜单全仓 0 命中，是 #7 的独立一面，不属本切片。
- **回写 #7 行时新发现的缺口（不属本切片）**：嘀嗒《添加任务》`:54` 那句下拉里有三样 —— 优先级、**添加附件**、从模板添加；
  本端快速添加弹窗只有优先级 + 本轮的模板 ⇒ **「添加附件」在添加流程里仍无入口**（附件只在任务详情
  `task_detail_pane.dart:3326` 的 `_AttachmentSection`）。这就是队列 1 剩下的真缺口，下一轮的候选。
- 模板只带 `title/description/priority`（`template_repository.dart:44-48` 的 `contentJson` 就这三个键）⇒
  嘀嗒模板里可能承载的截止时间/提醒/检查事项/标签**在保存侧就没入档**，本切片不去扩内容格式（会改同步 payload 与既有已验收的保存路径）。
- 模板弹层只提供「添加」，没有嘀嗒模板管理面（列表页改名/删除/模板库）⇒ 属矩阵 #89 的另一格缺口。
- 已选模板后无法二次确认或撤销（即刻建任务），与详情页「应用」一致；若人工在嘀嗒上核到「选择后是预填」，本行结论要改。
- 矩阵行状态翻转要等合并；未合并前只写「已实现待合并」。
- **存量同源缺陷（本切片没顺手改，另开治理 Issue）**：`_save()` 的两条反馈（未登录之外的 `StateError` 原因、
  「保存任务失败，请稍后重试」，`task_quick_add_sheet.dart:66-76`（两处 `ScaffoldMessenger.of` 在 `:68` 与 `:73`））仍走根 `ScaffoldMessenger` ⇒ 与复核 B4 同因，
  在生产里同样被这层 modal 路由盖住。本切片只把自己引入的三条消息搬进弹窗内，不扩大改动面。
  **已开治理 Issue：izhaong/zh-cloud-todo-flutter#289**。
- **模板行那对状态措辞无人钉**：`已同步` / `等待同步` 在 `test/` 里钉的是**别的整串**——
  `test/features/task/task_workable_views_test.dart:176`「已恢复上次看板设置，等待同步」、`test/reminder_inbox_test.dart:282,393`「操作等待同步」，
  `git grep -c 已同步 HEAD -- test` = **0 个文件** ⇒ 弹层与详情页共用的那对模板状态文案（`task_detail_pane.dart:3640`、
  `task_quick_add_sheet.dart:309-310`，`task_detail_pane.dart:3640`）没有任何用例守着，「与详情页同源措辞」目前只是叙述。要补得连详情页一起补，属另一切片。
- 模板路径不吃 `taskCaptureDefaultsRepositoryProvider.defaultPriority`（`_save()` 在 `:61` 吃）⇒
  模板存的是优先级 0 时会覆盖用户「新任务默认值」。**待人工在嘀嗒上核**：嘀嗒究竟是「模板值优先」还是「用户默认值优先」，
  在此之前不改（改了就是自创规则）。
- 反馈是一行文本、不是 toast：新消息覆盖旧消息、不自动消失（关掉弹窗即消失）。没做消息队列与超时——
  本弹窗只有这一行反馈，加队列属没被要求的可配置性。

## 第 2 轮复核处置（`VERDICT: PASS`，0 BLOCKERS / 9 NITS）

复核手段同第 1 轮（本机 `claude` CLI 不可用 ⇒ 会话内只读子代理，必须出 `VERDICT`）。
复核员在 `/tmp/g036-r2-probe` 的 rsync 副本上跑了 15 条反向探针，仓库字节未被写；
sha256 与本地两份文件一致（`4f082f98f16…` / `33be868e647…`），并独立量测了 B4 的生产前提
（390×844 下 `SnackBar` 矩形完全落在 modal 路由矩形内且位于更底层 ⇒ 不可见）。

采纳并已在本轮改掉（文档类，见 commit）：

| NIT | 内容 | 处置 |
| --- | ---- | ---- |
| 3 | `Key('todo-quick-add-feedback')` 没有任何用例引用，而 `plan.md` 把它当契约点名 | 待办：要么让某条断言直接按 key 找，要么把 plan.md 的措辞改成「按弹窗子树断言」。**本 commit 未动**，留给下一轮与 #289 一起收（同一片代码，避免拆两次）。 |
| 4 | 探针编号三套含义漂移（plan.md 第 1 轮表 / tasks.md 第 2 轮表 / 测试注释） | 已修：plan.md 表标明「第 1 轮」并加指向；测试注释的 `PJ`/`PI` 改为与 tasks.md 第 2 次表一致的 `PG`/`PB`。 |
| 5 | tasks.md 两处行号随修复失效（`:67-74`、`:286`） | 已修：`:66-76`（两处 `ScaffoldMessenger.of` 在 `:68`/`:73`）、`:309-310`。 |

不采纳 / 记为仍缺（都带理由）：

1. **NIT1 `button: true` / `container: true` 没被钉**（删掉两者只留 label 仍全绿）。
   不为此加断言：语义标志位的组合是 Material 层行为，用 `getSemantics(...).flags` 钉它等于把框架实现写进我们的用例；
   有牙的是 label 那条（改措辞必红）。
2. **NIT2 「...」节点上 label 与 action 落在两个语义节点**（复核员实测 `label="更多" tap=false` + 子节点 `tap=true`）。
   承认是可读屏体验缺陷，但**修它需要换控件形态**（`Semantics(mergesDescendantsState: true)` 或自建按钮），
   属于 #289 那一片（同源的还有 `_save()` 的两条 SnackBar），且必须真机 VoiceOver 复验 ——
   本机无第二台设备，widget 测试证明不了读屏顺序，不在此自证通过。
3. **NIT6 没有一条用例把宿主弹窗经 `showModalBottomSheet` 泵进树**（12 条都泵 `Scaffold.body`），
   所以 B4 的几何只是结构性约束。复核员自己另写了一次生产形态量测并给出 `feedbackInsideSheet=true`；
   把那段临时量测转成常驻用例要引入新的 golden/尺寸断言面，留待 #289 一并处理。
4. **NIT7 菜单项用 `findsWidgets` 而非 `findsOneWidget`**（弹层标题也叫「模板」，理论上失 label 仍绿）。
   同条用例里 `bySemanticsLabel('更多')` 已是 `findsOneWidget`，且改菜单文案必红（PH 实测 `+0 -12`）⇒ 收益低于改动风险，不动。
5. **NIT8 `if (_applyingTemplate) return;` 静默**：复核员自己判定「无可达的静默无反馈路径」，同意；
   加一条 `_report` 会给一个够不着的分支编文案。
6. **NIT9 反馈行 +34 px、320×568 + 假键盘下溢出 14 px**：复核员做了同脚本 A/B，
   基线 `a1d7733` **同样溢出** ⇒ 属存量非滚动布局，归 #289，不在本切片顺手改。

**改后门禁（最终字节一次跑完，日志 `/tmp/gate036r3.log`）**：
`git diff --check` rc=0 · `dart format` `Formatted 1 file (0 changed)` rc=0 · `flutter analyze` `No issues found!` · `flutter test --tags golden` `00:03 +9: All tests passed!` · `flutter test --exclude-tags 'golden || performance' --concurrency=1` `01:51 +721 ~26: All tests passed!` · `flutter build web --release` `✓ Built build/web`。

**结论**：本切片代码侧收口（两轮复核用尽，第 2 轮 PASS 且 0 blocker）。
剩余全部是文档契约措辞（NIT3）、#289 存量族与需要真机/人工核对的行为项。

## 下轮入口

1. 本切片只剩第 2 轮复核结论待回填（两轮封顶）；矩阵 #7 / #89 行停在「已实现待合并」，合并（人的动作）后才翻 SHA。
2. **零基线影响的下一刀候选（本轮取证时新排出来的，按性价比排序）**：
   - **习惯接线的纯客户端那一半**（矩阵 #44/#45/#46 本轮实测）：`AppTodoHabitController` 端点齐全
     （`page`/`create`/`update`/`delete`/`get`/`check-in`/`stats`），而
     `features/habit/habit_repository.dart` 只调了 `page`/`create`/`check-in`/`stats` 四个、新建表单只有名字一个字段
     ⇒ 补「编辑 / 删除 / 频率 / 目标 / 图标 / 颜色 / 提醒时间 / 打卡备注」不需要动契约
     （`AppTodoHabitBaseVO` 已有 name/icon/color/period/targetCount/reminderAt/sortOrder，
     `AppTodoHabitCheckInReqVO` 已有可选 `note`）。`grep -c 习惯 test/visual/todo_workspace_golden_test.dart` = **0**
     ⇒ 大概率零基线，但 `home_shell.dart:649` 直接内嵌 `HabitPage`，动手前先在 320px/默认档各拍一次确认 9 张不变。
   - **自我更正（本条上一版写错了）**：上面这块**不包括「归档」**。原文写的是「编辑 / 归档 / 删除…不需要动契约」，
     错在只看了 DO 层——`TodoHabitDO:50` 确实有 `archived`，但 `AppTodoHabitBaseVO`（create+update 的入参）**没有**
     `archived`，可读的只有 `AppTodoHabitRespVO:21` 与 `AppTodoHabitPageReqVO:17`（筛选），
     可写的 `archived` 只在**管理端** VO（`HabitUpdateReqVO:22`）⇒ app-api 今天既归档不了也取消归档不了。
     按规则 5，这一项要先在 `zh-cloud-service` 加契约，客户端不得自己造（例如借用 `sortOrder` 或本地标记硬编）。
   - 快速添加弹窗补「添加附件」（队列 1 的真缺口，复用 `task_detail_pane.dart` 的 `_AttachmentSection` 链路）。
3. **要先动契约、别从客户端下手**：倒数纪念日的 类型 / 提醒 / 重复 / 图标 / 农历 / 计时方式 / 分组 / 置顶
   —— 归档这一项已按规则 5 先动契约：`zh-cloud-service` Issue #274 → PR !276
   （`PUT /app-api/todo/{habit,countdown}/{id}/archived?value=` + 读侧 `/list` 与两个分页的
   `archived` 默认只看未归档；零增量 SQL）。**合并前客户端不要接**（矩阵行不翻转），
   合并后再做习惯接线里的「归档 / 已归档 / 恢复」。
   （`TodoCountdownDO` 只有 name/targetDate/style/showAge/backgroundImage/sortOrder/archived，
   `AppTodoCountdownPageReqVO.java:13,15` 只有 name 与 archived）⇒ 在 `zh-cloud-service` 先开 Issue + 增量 SQL，再回客户端。
   归档字段的修法仓内已有先例，不必自创形状：`AppTodoPomodoroTimerController.java:65`（`@PutMapping("/{id}/archived")`
   → `timerService.setArchived(id, archived)`）与 `AppTodoNoteController.java:45`（`@PutMapping("/archive")`）——
   habit 与 countdown 各照此加一个 app-api 端点即可。
4. **轨道 A 到此收口**：A/B/C 三段都已清算（A 段最后一批 6 行落在 `zh-cloud-docs@09c7e8b`，PR !69）。
   轨道 A 只剩「矩阵之外的两处人工判定」：B33/C9 早已判完，剩 `specs/001-todo-dida-core-parity/spec.md:66`
   与成就入口路线的措辞冲突（队列 5 里那条），以及 #52 的共享三种方式要先在 Service 加端点。
5. 待合并积压（合并是人的动作）：todo-flutter !259/!261/!263/!267/!268/!269/!271/!273/!275/!277/!280/!282/!284/!286/!288
   + docs !69/!70 + service !272 + 父仓 !93/!74。合并后需 bump 父仓 submodule 指针（另开 Issue + PR）。
6. **剩余工时粗估**（不含等人给条件的项）：习惯接线族 ≈ 1.5 轮；快速添加附件 ≈ 1 轮；
   倒数纪念日契约 ≈ 1 轮（service）+ 1 轮（客户端）；清单页子任务树 / 文件夹入口 / 左滑 ≈ 各 1 轮且**都要先批准重录黄金图**；
   纯客户端可推进的窗口大约还能撑 6–8 轮，之后就要靠合并与 test 环境才能再进。
