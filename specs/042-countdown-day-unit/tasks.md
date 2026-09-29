# 042 任务清单

## 已证实
- [x] FR-001..FR-006 的 5 条用例**先红后绿**：
      红 = `git checkout HEAD -- lib/features/countdown/countdown_page.dart`（摘掉整块实现）后
      `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "还有 3 年": []>`
      与 `"已 5 年"` 同形失败 ⇒ 缺的正是「点了没换单位」；
      ⚠️ 上面 `"已 5 年"` 是**改词前**的读数：`ed53c8c` 按《01-添加倒数纪念日.md:106》把前缀收成「已过」，
      该断言现为 `"已过 5 年"`。旧读数保留作修订前证据，不当作当前用例内容。
      绿 = `flutter test test/features/countdown/countdown_unit_toggle_test.dart` ⇒ `00:00 +5: All tests passed!`
- [x] 反向探针：上面那次「摘实现」即探针（4 条切换用例红），`cp` 还原后 `cmp -s` 判 **byte-identical OK**
- [x] 换算由用例钉死：1095 天 → 3 年 / 156 周；2000 天 → 5 年 / 285 周（年 = 天 ~/ 365、周 = 天 ~/ 7）
- [x] 行级 Key 的写法有仓内先例，不是本轮发明的。锚点基准 FL `origin/develop` = `5a831a19e`，复验：
      `git show origin/develop:lib/features/note/note_page.dart | grep -n todo-note-` ⇒ `note_page.dart:189` `ValueKey('todo-note-${note.id}')`；
      `git show origin/develop:lib/features/task/tasks_by_list_page.dart | grep -n todo-task-group-` ⇒ `:1839` 与 `:1879` 两处 `Key('todo-task-group-${entry.id}')`
- [x] 复核手段替换：`claude` CLI 本机不可用（`unrecognized_model`），改由本会话**只读子代理**审 FR-001..FR-006，
      要求逐条给 VERIFIED / FALSIFIED / UNPROVEN 并给命令与决定性输出行，末尾必须落 `VERDICT`

## 门禁（最终状态 `9d1de85` 一次跑完；当时的 `/tmp/r41_gates*.log` 已随 /tmp 清理丢失 ⇒ 下表数值是那一次运行的原样记录，**不能照路径复验**）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | `gate1 rc=0`（区间 `origin/develop...HEAD`） |
| 2 `dart format --output=none --set-exit-if-changed`（仅本轮 2 个显式文件） | `Formatted 2 files (0 changed)`、`gate2 rc=0` |
| 3 `flutter analyze` | run #3 `No issues found! (ran in 2.0s)`、`gate3 rc=0`。**run #1 曾红**：`1 issue found` + `gate3 rc=1` —— 我在测试里写了 `node.hasFlag(SemanticsFlag.isButton)`，本机 SDK 已废弃该 API（`deprecated_member_use`），改成 `node.flagsCollection.isButton` 并去掉随之无用的 `import 'package:flutter/semantics.dart'` 后才归零 |
| 4 `flutter test --tags golden` | run #3 `00:03 +9: All tests passed!`、`gate4 rc=0`（基线 9 张，**未重录**） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | run #3（最终状态）`02:12 +714 ~26: All tests passed!`、`gate5 rc=0`；run #2 为 `02:13 +714 ~26`。计数可核对：develop 基线 709 + 本轮 5 例 = 714（objective 里那句「713 passed」是 2026-09-23 当时的数） |
- 同一次构建输出里另有一句 wasm 提示（`Consider addressing these issues to enable wasm builds`）—— **那是未开启 wasm 目标时的提示，不是失败**：`✓ Built build/web` 且 `gate6 rc=0`。


run #1（`gate3 rc=1` 那遍）、run #2、run #3 三份日志都写在 `/tmp` 下，**现已全部丢失**；run #3 才是最终状态 `9d1de85` 的六项一次性记录 ⇒ 这些数值目前只剩「文档自述」这一种载体，属真实的可复验性欠债，已列入「仍缺」。

## 复核（第 1 轮：VERDICT: FAIL → 逐条复验后修复）
只读子代理审 FR-001..FR-006，结论 **FAIL**。5 条发现逐条对照源码复验：

| 发现 | 我的复验 | 处置 |
| --- | --- | --- |
| 测试头部引《`03-特色功能/02-打造专属纪念页.md`》—— 该路径不存在 | `grep -n 特色功能 test/.../countdown_unit_toggle_test.dart` 命中 1 处，真页在 `02-功能指南/06-倒数纪念日/` | **采纳**，改路径 |
| FR-001 与代码注释把「循环顺序」当成源页要求 | `:97` 原文只说「在**天、年、周**三种单位间快速切换」，确实没规定顺序、也没说第四次回到原档 | **采纳**，改成「单位集合是要求，循环顺序是实现选择」 |
| ④ 区间写成 `:92`-`:106`，漏 `:111` 的 tabContainer 闭合 | 文档 `:111` 是 `:::::` | **采纳**，扩到 `:92`-`:111` 并标明 |
| FR-005 声称断言了 `SemanticsAction.tap`，实际没有 | 提交里的测试只断言 `isButton`；旧 tasks.md 还写着「用 `SemanticsAction.tap` 断言」——那是我在换成 `flagsCollection.isButton` 之前的草稿 | **采纳**，FR-005 改成与真断言一致 |
| 「isButton 到底挂在哪个节点」未证实 | 做了决定性探针：**只摘掉外层 `Semantics(button: true)`、保留 `InkWell`** ⇒ `--name "天数块自身是读屏按钮"` 立刻 `+0 -1`。即 `InkWell` 自己不设 `isButton`，这层包装是必要的、断言是咬得住的 | **已证**，写进 FR-005 |
| 320px 用例的 `takeException()==null` 近乎空断言（`Text` 会换行，`RenderFlex` 溢出到不了） | 认同：该用例真正咬住的是三档文案在 320px/1.3x 下仍能渲染并切换，不是溢出本身 | **采纳为措辞**：不声称证明了「不溢出」 |
| `pubspec.lock` 与测试修复未提交，被审 HEAD ≠ 被测状态 | 属实：`M pubspec.lock` 是本机新 SDK 重解析，按约定不随 PR 提交；`flagsCollection` 修复与 `tasks.md` 当时还在工作树 | **采纳**，本轮一并提交（run #3 在最终状态重跑） |

## 仍缺（不谎称完成）
- [ ] 320px 用例**没有真正证明「不溢出」**：`Text` 会自行换行，`RenderFlex` 溢出在那档布局里到不了，`takeException()==null` 是弱断言；该用例的可信部分是「三档文案在 320px + 1.3 倍字号下仍渲染得出来且能切换」。
- [ ] 嘀嗒移动端那一档《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md:97》要求「点进一个倒数纪念日，在倒数纪念日详情页中，点击中间的天数」——
      本端没有倒数纪念日详情页，本轮按 desktop 那一档（`:106`「点击倒数纪念日卡片上的天数」）落在列表行上。
- [ ] 年/周的小数与余数未做（源页 `:93` 只问「多少年/多少周」，取整即最直读；`spec.md` 已记取舍）。
- [ ] 真机（iOS/Android 触屏）上的点击目标尺寸未实测：本机只有 web 构建可用（`github.com` 超时 ⇒ SPM 编不了）。
- [ ] 单位选择是会话内状态，重进页面回到「天」。源页与契约都没有「记住」的要求 ⇒ 按 `spec.md` 取舍**有意不做**，
      但如果产品要求持久化，需要新增契约列（另开 `zh-cloud-service` Issue）。
- [ ] 同页其余四面（①样式入口与样式列表、②自定义颜色、③自定义图片、⑤备注）未动：
      ① ③ 的契约列已有（`style`、`backgroundImage`）只是 UI 没接；② ⑤ 缺列 ⇒ 已开 `zh-cloud-service` Issue **#280**。
- [x] 矩阵第 49 行：合并后把 ④ 的「已实现待合并 !303」换成合并 SHA —— 已完成，docs `origin/develop` 该行现引 `90320057c`（`!303`）；
      「复校本 PR 改过的 `countdown_page.dart` 行号」也已完成：`spec.md` 逐面判定表已按 FL `origin/develop` = `5a831a19e` 重新量过（见「设置样式入口 + 超多样式」行）。
- [ ] 门禁读数的**唯一载体是本文档**：`ls -l /tmp/r41_gates.log /tmp/r41_gates2.log /tmp/r41_gates3.log` 现跑 ⇒ 三个路径都报 `No such file or directory` ⇒ run #1/#2/#3 的日志已随 /tmp 清理丢失；`+714 ~26`、`+898 ~26`、`Formatted 2 files (0 changed)` 等数值因此都无法照日志复验，只能在当前 develop 上重跑一遍才能重新取证。下一轮若再动这一页，应连带把六项重跑到最终字节并留日志。

## 合并轮写回（!303 → develop `90320057c`，2026-09-24）
冲突形态：`countdown_page.dart` 同一组件被两侧重写（本分支按 117 行的旧行体写，develop 已把整行搬进
`_CountdownTile` 并接了 `showAge`）。处置不是「选一侧」，而是**以 develop 的行体为宿主**重挂单位切换
（`d1f7252`），因此用例从 5 条变 **6 条**：新增「正数日关掉『显示已过天数』：只显示目标日期，不给单位入口」，
且该用例的日期由 fixture 同一份输入算出（上一版我手写日期，直接红）。

六项门禁跑在**合并后的 develop**上，并用树等价把读数搬给分支：

| 门禁 | 读数 |
| --- | --- |
| 树等价（**历史快照**，只对 `90320057c` 那次合并成立） | `git rev-parse 9032005^{tree} ed53c8c^{tree}` 现跑同为 `d6c5504d50d5be3b9f4d941400d25f148ded9184`（commit 不可变 ⇒ 恒成立）；合并那一刻 `origin/develop^{tree}` 亦为此值，但 develop 此后又前移，现 `5a831a19e` 的 tree 是 `1722c200842f7b625d3ca0fd43b4b9d8af77a54c`（不等） |
| 1 `git diff --check` | rc=0 |
| 2 `dart format --output=none --set-exit-if-changed`（本轮 2 个显式 dart 文件） | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found!`、rc=0 |
| 4 `flutter test --tags golden` | `00:08 +9: All tests passed!`（基线 9 张，**未重录**） |
| 5 全量非 golden | `02:52 +898 ~26: All tests passed!`、rc=0 |
| 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、rc=0 |
| `pubspec.lock` | 合并后已还原到分叉基线，脏文件数 0（本机镜像不得进 PR） |

## 本轮（spec 写回）未达成项
- [ ] **!303 的合并轮没有只读复核**：objective 要求的 `VERDICT` 环节没跑（预算耗尽）。
      树等价只证明「分支上的门禁读数适用于合并后的 develop」，**不等于**有人审过这次冲突解决后
      `_CountdownTile` 的语义归属与 develop 行体的复用。该缺口不得当成已通过，下一轮若再动这一页应连带补审。
- [ ] `spec.md` 与代码的三处不一致（前缀「已」→「已过」、`showAge` 门控、读屏 label 措辞）本轮按「代码为准」修订了文档；
      反过来说：**修订前那三处文档误导过任何人**，改动记录只写在文档里，没有回查其它引用点。
      回查命令与现跑读数（2026-09-30 在 FL 工作树跑）：
      `rg -n '已 [0-9]+ 天|已 [0-9]+ 年|点卡片即切换' specs/` ⇒ **4 行**：本文件「已证实」首条刻意保留的旧读数 2 行 + 下面两条命令自身各 1 行（模式串写进了正文 ⇒ 自匹配）。扣掉这 4 行后 **0 命中** ⇒ 旧措辞没有残留到其它 spec。
      正对照 `git grep -c 已过 -- specs/ | wc -l` = **7 个文件**（证明搜索路径有效）。刻意不记「`已过` 命中 N 处」这种出现数：
      本段自己的命令里就含该词，抄进去的数会被本次写入顶掉（上一版记的「9 处」在任何口径下都复现不出，已作废）。
      docs 侧 `git grep -n -E '已 [0-9]+ 天|已 [0-9]+ 年|点卡片即切换' origin/develop -- todo` = **0 命中**；
      正对照 `git -c core.quotePath=false show 'origin/develop:todo/01_需求阶段/对照矩阵/dida-parity-matrix.md' | grep -o 已过 | wc -l` = **3**。

## 复核（第 3 轮：VERDICT: FAIL → 逐条回源复验，修复落在 `5386268`）
被审字节 `fa54e64`，取数基准 FL `origin/develop` = `5a831a19e`（复核员用的是它开跑时的 `b25fdd74`，下表读数全部按当前 develop 重量一遍）。

| 复核发现 | 我的复验（现跑） | 处置 |
| --- | --- | --- |
| FAIL A：`spec.md` 逐面判定仍写「`样式` 0 命中 / UI 未接」 | `git grep -o 样式 origin/develop -- lib/features/countdown/countdown_page.dart \| wc -l` = 3；`:401` 渲染「样式」标签、`:406` 是 `ChoiceChip`、`:455` 按 `countdown.style` 切徽章形态；`git merge-base --is-ancestor 24005fc origin/develop` rc=0 ⇒ 三档样式早已在 develop | **采纳**：该行改判「部分」，并把仍缺之处写成「入口位置」与「档位数量」 |
| FAIL B：锚点 `note_page.dart:188` | `git show origin/develop:lib/features/note/note_page.dart \| sed -n '188p'` = `child: ListTile(`，`ValueKey('todo-note-…')` 实际在 `:189` | **采纳**：改锚为 `:189` |
| FAIL B：锚点 `tasks_by_list_page.dart:1710` | `sed -n '1710p'` = `final String? selectedTaskId;`；`grep -n todo-task-group-` ⇒ `:1839` 与 `:1879` | **采纳**：改锚并给出现跑命令 |
| NIT：门禁日志 `/tmp/r41_gates*.log` 读不到 | `ls -l` 那三个路径全报 `No such file or directory` | **采纳**：正文改成「只剩文档自述」，并把重跑登记进「仍缺」 |
| NIT：树等价属历史快照 | `git rev-parse 9032005^{tree} ed53c8c^{tree}` 仍 = `d6c5504d50d5…`；但 `origin/develop^{tree}` 现为 `1722c200842f…` | **采纳**：等价只引不可变 commit，并写出今天的 develop tree 以示区别 |
| NIT：「`已过` 在 specs 命中 9 处」复现不出 | 按出现数、按行数都远大于 9；且本轮写入自身就含该词 ⇒ 出现数必然被自己顶掉 | **采纳并换口径**：只记 `git grep -c 已过 -- specs/ \| wc -l` = 7 个文件。顺带查出原文那句「除旧读数外 0 命中」按字面也不成立（实测 4 行，含 2 行命令被自身模式串命中），一并改成实测读数 |
| NIT：服务端 `type`/`unit` 契约缺口没另立专单 | 镜像《02-打造专属纪念页.md》`:97` 与 `:106` 只要求「点击天数即在三种单位间切换」，没有「记住档位」的主张 | **驳回**：给不存在的即时需求开契约单等于自创要求；`spec.md` 取舍段已写明「持久化需新增契约列 ⇒ 另开 `zh-cloud-service` Issue」，等有产品主张再立 |
