# 046 任务清单 — 嵌入态操作头窄面板折叠（Issue #279）

分支 `fix/279-embedded-header-overflow`（基线 `origin/develop@9032005`，即 !303 已合并之后）。
PR **!322** 已开，**待合并授权**（合并我只问不做）⇒ 本轮不翻任何矩阵状态。

## 第 1 轮只读复核：`VERDICT: PASS`（6 条 NIT）逐条处置

复核没有抓到会让本轮翻车的假证据（它独立复现了 `898 + 5 = 903` 与 md5 稳定的探针还原），
但 6 条 NIT 里**有两条是真错**，我已回源复验后修掉；一条我驳回并留下实测理由。
（编号只到我这边的转述，压缩后原文没留下 ⇒ 按内容记，不编编号。）

| # | 复核的话 | 我的回源复验 | 处置 |
| - | -------- | ------------ | ---- |
| 1 | 8 种宽度×字号组合合成**一条** `testWidgets`，`takeException()` 只吐第一条待报异常 ⇒ 后 7 格永远红不了；且第二条断言 `getSize(headerRow()).width ≤ 视口` **恒真** | 成立。溢出的那一帧 `RenderFlex.size` 仍是被约束夹住的 304，孩子已画到 340 —— 我那条断言量的根本不是"有没有越界" | 拆成**每格一条** `testWidgets`（8 条）；断言换成遍历 `flex.visitChildren` 取 `parentData.offset.dx + size.width` 的最大值 vs `flex.size.width`。反向探针 PM（阈值改 0 永不折叠）读到 `≤ <304.0> Actual: <340.0>` 与 `≤ <339.0> Actual: <340.0>` ⇒ 新断言真的会红，还能报出 1px 那一档 |
| 2 | 阈值 `356` 是**绑平台**的：`adaptivePlatformDensity` 下桌面/紧凑密度一枚图标只有 40dp，写死会让窄面板白折 | **不成立，驳回**（照它改过一次，实测被否）。本仓主题 `useMaterial3: true`（`lib/app.dart:109`、`:150`），M3 的 `IconButton` 把样式里的 `visualDensity` 硬编成 standard（SDK `material/icon_button.dart:1152`/`:1294`/`:1436`/`:1573`），只有 legacy 分支 `:779` 才读主题密度。实测：主题设成 compact、面板 300dp ⇒ `A RenderFlex overflowed by 56 pixels`（= 7×48+4 − 284），图标压根没缩 | 阈值不跟密度；改成一条 compact 用例**钉住 48dp 这个读数**（复核提的"cheap pin"我用上了，只是钉的是 48 不是 40）。理由写进 `spec.md` 取舍 7 |
| 3 | 顺着 2 核对公式时发现的我自己的错：`LayoutBuilder` 的 `maxWidth` 已扣掉 `Padding` 的 16dp，我再加 16 等于**数两遍** | 成立。真实比较对象是内容宽 ⇒ 阈值应是 340；写 356 把折叠线推到面板 372，356~371 那一带白折 | 常量改名 `_embeddedActionRowContentMinWidth = 340`；`355 折 / 356 不折` 两档各一条用例钉住。反向探针 PL（改回 356）→ **恰好 356.0 的两格红**，其余 11 条绿 |
| 4 | `task_detail_pane.dart:34` 的注释把"355 溢 1px"的来源指向随 PR 提交的那条用例，而**那条用例检测不到 1px**（旧断言恒真） | 成立。旧版只能报出 36px 那一格 | 注释改为引用现用例的读数（逐格几何断言 + PM 的 1px 报数）；口径同时写进 `spec.md` 的「量法说明」 |
| 5 | `spec.md` 四处文档缺陷：判据源"全页 406 行"（镜像实为 **405**）、把未合并的 `specs/045 :175` 当已有依据、`取舍` 里两条都编号"5."、把「破坏性」写成嘀嗒的原话 | 全部成立。镜像行数按 develop 重量 = 405（并补上真实路径 `todo/99_参考资料/…`，我原来引成 `todo/01_需求阶段/对照矩阵/99_参考资料/…` 也是错的）；`git ls-tree origin/develop specs/` 只到 **044** ⇒ specs/045 确在 PR !319 分支上未合并；「破坏性」原文没有这个词 | 四处都改了；「破坏性」标成"我的归类，不是原文用词"；specs/045 那条显式标**未合并** |
| 6 | PR 正文写的门禁 SHA 与实际不符（门禁跑在 `5b8f514`，HEAD 已是 `8fb446d`） | 成立 | 本轮门禁在 `8d9cc53` 的最终字节上**全部重跑**（下表），PR 正文按新 SHA 重写并贴日志计数 |

## 第 2 轮只读复核：`VERDICT: PASS`（无 BLOCKING，3 条 NIT 全部采纳）

复核员独立复现了 PF（`+6 -7`，与我记的逐字一致）、PL（`+11 -2`，红的恰是 356.0 两档）、
compact 用例 `headerIconExtent == 48.0`、`898 + 13 = 911` 与 `903 − 5 + 13 = 911` 两侧算术、
镜像 405 行、`origin/develop` 的 `specs/` 末项是 044、还原后 `sha256` 与 `git status --porcelain` 干净。

| # | NIT | 复验 | 处置 |
| - | --- | ---- | ---- |
| R2-1 | lib 注释自相矛盾：写「面板 320dp … 56 pixels（= 340 − 284）」，而 320 那档不折叠报的是 **36px**，56px 对应面板 **300** | 成立。我自己回算：内容 304 与 284 两档，需要量都是 340 ⇒ 溢出 36 与 56。我把两档的数拼在一句里了 | 注释改成两条分开写（320→36px、300→56px），并写明**用例只钉 320 那一档**，56px 是"按复核建议改过"的读数、不在提交用例里 |
| R2-2 | `spec.md` 第四个 getter 是 `:1573` 不是 `:1576` | 成立，`grep -n "VisualDensity? get visualDensity"` 实得 1152/1294/1436/**1573** | spec 与 tasks 两处都改成 `:1573`（并同步修了我记忆里的那条错位） |
| R2-3 | "与 `link_parent_task_test.dart` 的既有断言相互印证"是归因夸大：那个文件在 320dp 只有 `takeException()` isNull（`:271`），没有任何 355/356 边界断言 | 成立 | 边界的证据只算本文件的逐格 `expectHeaderFits` + PF/PL 探针；那句话不再出现在 lib/spec/PR 里 |

## 已完成

- [x] 实测溢出条件（探针表在 `spec.md` 开头）：**面板 < 356dp 就溢，与字号无关** ⇒ Issue #279 标题里
      「+ 1.3 倍字体」这条归因是错的，已在 Issue 留言更正。
- [x] 红测先行：`test/features/task/embedded_detail_header_narrow_test.dart` 首跑 `+0 -3`
      （溢出 / 菜单两项 / 读屏语义三条红，宽屏不重复那条绿）⇒ 见 `/tmp/g61/`（红测在实现前跑的读数记录于本轮对话，
      文件级日志未单独留档，只有实现后的绿跑日志；不假装存了一份红日志）。
- [x] 最小实现：`lib/features/task/task_detail_pane.dart`
      —— `_embeddedActionRowContentMinWidth = 340` 常量 + `_buildEmbedded` 的 `LayoutBuilder` 折叠
      + `_embeddedMoreActions(task, {required foldedActions})` + `_onCompactMoreAction` 两条 case。
      （复核后重写：见上表 1~3。）
- [x] 撤掉测试里吞异常的 pin：`test/features/task/link_parent_task_test.dart:267-278`
      原来是 `expect(preExisting, contains('RenderFlex overflowed by 36 pixels'))`（"先吃掉这条既有异常"），
      现在换成 `expect(tester.takeException(), isNull, reason: '操作头溢出（Issue #279）应已修掉')`。
      ⇒ 这条文件 `+14` 全绿。
- [x] 六项门禁跑在**最终字节**（`8d9cc53`）上，日志 `/tmp/g61/gate{3,4,5,6}b.log`。
- [x] 只读复核第 1 轮：`VERDICT: PASS`，6 条 NIT 已按上表处置（5 采纳 1 驳回并附实测）。
- [ ] **第 2 轮复核待派**（处置后需再拿一次 VERDICT 才算收口）。
- [x] PR 已开：见 Issue #279 与本 PR 互链；**合并前不关单、不翻矩阵状态**。
- [ ] 矩阵：本轮是治理修复，不动 89 行状态；`#8 任务详情与编辑` 那一行的"操作头折叠形状"要不要写进去，
      等 PR 合并后再判（**不在没读原文前乱改**）。

## 六项门禁（最终字节 = `8d9cc53`，日志 `/tmp/g61/gate*b.log`）

| # | 门禁 | 读数 |
| - | ---- | ---- |
| 1 | `git diff --check` | rc=0；跑完 `flutter test`/`build web` 之后**再跑一次仍 rc=0**，`git status --short` 为空 ⇒ 没有 `pubspec.lock` 漂移 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 2 个显式 dart 文件>` | 第一跑 `Formatted 2 files (1 changed)` rc=1 ⇒ 对**本轮文件**原地格式化后重跑：`Formatted 2 files (0 changed)` rc=0。**没有**跑过全仓格式化。改动面自查（lib 单文件，`origin/develop...HEAD`）：`--stat` = **101 增 / 51 删**，`-w --stat` = **52 增 / 2 删** ⇒ 差的 ~49 行是把 `Row` 包进 `LayoutBuilder` 造成的**纯缩进位移**（与第 1 轮那组 89/51 vs 40/2 同一条解释，多出的 12 行是常量注释重写）；`-w` 逐行读过只剩常量、菜单函数、两条 case 与两个 `if (!folded)` |
| 3 | `flutter analyze` | `No issues found! (ran in 2.1s)` rc=0 |
| 4 | `flutter test --tags golden` | `00:04 +9: All tests passed!` ⇒ **9 张基线一张都没重录** |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:25 +911 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

**用例数可加减核**：`+911` = develop 基线 `+898`（第 55 轮 `/tmp/g58/baseline.txt`，同一 develop 时代）
+ 本文件 **13** 条 = 911。第 1 轮那版是 `898 + 5 = 903`；复核 NIT-1 把 8 格组合拆成独立用例后
`5 → 13`（8 格 + 1 compact + 原 4 条），`903 − 5 + 13 = 911` 与实际读数一致 ⇒ 没有用例被顺带删掉或跳过。
`git status --short` 干净；`test/visual/failures/` 是中途那次 golden 失败留下的临时 diff 图，已删（未跟踪）。

## 反向探针（全部跑在最终字节上，每条跑完 `cmp -s` 校验实现文件与跑前逐字节相同）

本文件共 **13** 条用例，下面 `+绿 -红` 都是单跑这个文件的读数（日志 `/tmp/g61/probe_*.txt`）。

| # | 改法 | 期望 | 实际读数 |
| - | ---- | ---- | -------- |
| PF | `_embeddedActionRowContentMinWidth = 0`（永不折叠 ⇒ 7 枚图标回到窄面板） | 溢出的格 + 依赖菜单用例必须红 | `+6 -7`（4 格宽度溢出红 + compact + 两条菜单用例） |
| PG | `= 99999`（永远折叠） | "宽面板不折叠"必须红 | `+8 -5`（356/390 四格 + `嵌入态宽面板不折叠…`） |
| **PL**（NIT-3 的新探针） | `= 356`（把 Padding 的 16dp 数两遍） | **恰好 356.0 那两格红**，其余绿 | `+11 -2`（正是 `标准密度 356.0 dp + 字号 1.0 / 1.3`；320/355 本来就折，所以这条只惩罚 356~371 那一带） |
| **PM**（NIT-1 的新断言） | 同 PF，但只看新加的几何断言 | 报得出「孩子画到面板外」的数，而不是只有一句像素数 | `Expected: a value less than or equal to <304.0>  Actual: <340.0>`；`… ≤ <339.0>  Actual: <340.0>` ⇒ **1px 那一档现在量得到** |
| PH | 删掉菜单里的 `if (foldedActions) … delete` 一项 | 依赖它的两条红 | `+11 -2` |
| PI | `case delete:` 改成空 `return` | 点删除要给确认框那条红 | `+12 -1` |
| PJ | `case moveToInbox:` 改成空 `return` | `listId` 要变 inbox 那条红 | `+12 -1` |
| PK | 菜单文案换成自创的「移到收集箱」（原锚点匹配到 2 处，改成带上下文的整块后命中 1 处） | 术语断言红 | `+11 -2`（正是钉术语的两条） |

⇒ 折叠阈值（含"多算一遍 padding"这一档）、两个动作分支、菜单文案三处都是**有断言在守**的，不是"看起来对"。

## 本轮踩到的四件事（记下来免得重演）

1. **harness 自己会造红。** 第一版"移动后面板要关掉"的断言红，根因不是实现，
   是我把面板挂在 `MaterialApp.home:` 上 —— 没有可 pop 的路由，`_close()` 自然什么也不做。
   改成"真路由 push"后又红一次：嵌入态正文里有标题 `TextField`（`task_detail_pane.dart` 里
   `Semantics(identifier: 'todo_task_detail_title')` 那一条；**故意不写行号** —— 记行号的话，
   这段说明本身就会把那一行推下去），
   路由里不给 `Scaffold` 就没有 Material 祖先，报 `No Material widget found`。
   ⇒ 测"关闭/返回"这类语义，宿主拓扑必须和生产一致，否则会去改本来正确的实现。
2. **无条件折叠会撞 2 张黄金基线。** 先跑过一次无条件版本，`wide-selected` / `compact-selected` 直接红。
   ⇒ 在"必须停下来问重录基线"之前，先找有没有**按实际宽度分形状**这条更小的路 —— 这次有。
3. **复核的建议也要回源，不能照抄。** NIT-1「阈值该随 `visualDensity` 算」听上去很内行（`ThemeData`
   确实默认 `adaptivePlatformDensity`），但它漏了 M3：`IconButton` 的四个样式 getter 把密度钉成 standard。
   我照它改完，**它自己的用例就把我驳回了**（compact + 300dp 面板溢 56px）——
   这条恰好说明"按建议改完必须跑一遍"，而不是"建议来自复核就采纳"。
4. **一条 `testWidgets` 里跑 8 种组合 = 只有第 1 格有断言力。** `takeException()` 取走并清空当前异常，
   后面 7 格就算真溢了也报不出来；而 `getSize(row).width ≤ 视口` 在溢出帧里恒真（RenderFlex 的 size 被约束夹住）。
   ⇒ 参数化测试要么拆成一条一格，要么每格读一个**不依赖异常队列**的量（我用的是孩子的累加右边缘）。

## 下一轮入口

1. **第 2 轮复核待派**（本轮处置后需再拿一次 `VERDICT` 才算收口）；通过后把 !322 的合并请求提给用户
   —— 合并我只问不做。
2. Issue #279 的收尾：本 PR 合并后，把矩阵里与"详情操作头"相关的行按新形状复核一遍（尤其 `#8`），
   然后再关单（合并前不关，避免"单子关了但 develop 上没有"）。
3. `spec.md` 仍缺第 1 条：整页态 `_buildPage` 的图标栏没有等价的"宽度不够就折"，需要它自己的溢出证据再动。
4. 嘀嗒《任务详情》`:399` 的「自定义任务详情操作菜单」（编辑 / +/- 置顶 / 拖拽排序）整面无 ⇒ 属未实现的一面，
   排轮次时按矩阵对应行判，别拿本轮的写死折叠冒充。
5. 治理面（不混进本轮，登记在此）：`_kMinButtonSize` 这类"看起来跟主题有关其实写死"的形状，
   仓里还有 `sidebar.dart:539`、`list_member_page.dart:330/334`、`timeline_view.dart` 等处显式传
   `VisualDensity.compact` —— 若哪天要统一窄屏密度，先从这些点起，别再往布局常量里塞魔数。
