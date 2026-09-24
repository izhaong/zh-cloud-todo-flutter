# 042 任务清单

## 已证实
- [x] FR-001..FR-006 的 5 条用例**先红后绿**：
      红 = `git checkout HEAD -- lib/features/countdown/countdown_page.dart`（摘掉整块实现）后
      `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "还有 3 年": []>`
      与 `"已 5 年"` 同形失败 ⇒ 缺的正是「点了没换单位」；
      绿 = `flutter test test/features/countdown/countdown_unit_toggle_test.dart` ⇒ `00:00 +5: All tests passed!`
- [x] 反向探针：上面那次「摘实现」即探针（4 条切换用例红），`cp` 还原后 `cmp -s` 判 **byte-identical OK**
- [x] 换算由用例钉死：1095 天 → 3 年 / 156 周；2000 天 → 5 年 / 285 周（年 = 天 ~/ 365、周 = 天 ~/ 7）
- [x] 行级 Key 的写法有仓内先例，不是本轮发明的：`origin/develop` 上已有
      `note_page.dart:188` `ValueKey('todo-note-${note.id}')`、`tasks_by_list_page.dart:1710` `Key('todo-task-group-${entry.id}')` 等
- [x] 复核手段替换：`claude` CLI 本机不可用（`unrecognized_model`），改由本会话**只读子代理**审 FR-001..FR-006，
      要求逐条给 VERIFIED / FALSIFIED / UNPROVEN 并给命令与决定性输出行，末尾必须落 `VERDICT`

## 门禁（最终状态 `9d1de85` 一次跑完，日志 `/tmp/r41_gates3.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | `gate1 rc=0`（区间 `origin/develop...HEAD`） |
| 2 `dart format --output=none --set-exit-if-changed`（仅本轮 2 个显式文件） | `Formatted 2 files (0 changed)`、`gate2 rc=0` |
| 3 `flutter analyze` | run #3 `No issues found! (ran in 2.0s)`、`gate3 rc=0`。**run #1 曾红**：`1 issue found` + `gate3 rc=1` —— 我在测试里写了 `node.hasFlag(SemanticsFlag.isButton)`，本机 SDK 已废弃该 API（`deprecated_member_use`），改成 `node.flagsCollection.isButton` 并去掉随之无用的 `import 'package:flutter/semantics.dart'` 后才归零 |
| 4 `flutter test --tags golden` | run #3 `00:03 +9: All tests passed!`、`gate4 rc=0`（基线 9 张，**未重录**） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | run #3（最终状态）`02:12 +714 ~26: All tests passed!`、`gate5 rc=0`；run #2 为 `02:13 +714 ~26`。计数可核对：develop 基线 709 + 本轮 5 例 = 714（objective 里那句「713 passed」是 2026-09-23 当时的数） |
- 同一次构建输出里另有一句 wasm 提示（`Consider addressing these issues to enable wasm builds`）—— **那是未开启 wasm 目标时的提示，不是失败**：`✓ Built build/web` 且 `gate6 rc=0`。


run #1 日志 `/tmp/r41_gates.log`（`gate3 rc=1` 那遍）、run #2 `/tmp/r41_gates2.log`、**run #3 `/tmp/r41_gates3.log` 才是最终状态 `9d1de85` 的六项一次性记录**。

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
- [ ] 嘀嗒移动端那一档《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md:97》要求「**点进详情页**、点击中间的天数」——
      本端没有倒数纪念日详情页，本轮按 desktop 那一档（`:106`「点击倒数纪念日卡片上的天数」）落在列表行上。
- [ ] 年/周的小数与余数未做（源页 `:93` 只问「多少年/多少周」，取整即最直读；`spec.md` 已记取舍）。
- [ ] 真机（iOS/Android 触屏）上的点击目标尺寸未实测：本机只有 web 构建可用（`github.com` 超时 ⇒ SPM 编不了）。
- [ ] 单位选择是会话内状态，重进页面回到「天」。源页与契约都没有「记住」的要求 ⇒ 按 `spec.md` 取舍**有意不做**，
      但如果产品要求持久化，需要新增契约列（另开 `zh-cloud-service` Issue）。
- [ ] 同页其余四面（①样式入口与样式列表、②自定义颜色、③自定义图片、⑤备注）未动：
      ① ③ 的契约列已有（`style`、`backgroundImage`）只是 UI 没接；② ⑤ 缺列 ⇒ 已开 `zh-cloud-service` Issue **#280**。
- [ ] 矩阵第 49 行：合并后把 ④ 的「已实现待合并 !303」换成合并 SHA，并复校本 PR 改过的 `countdown_page.dart` 行号。
