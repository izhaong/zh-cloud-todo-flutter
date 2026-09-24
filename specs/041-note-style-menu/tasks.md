# 041 任务清单

## 已证实
- [x] FR-006 取消样式：2 条新用例（成对包围→剥一层并退回 (0,4)；只选到一半→不误剥），`flutter test test/features/note/note_style_menu_test.dart` ⇒ `00:01 +7: All tests passed!`
- [x] 第 38 轮第 1 轮只读复核 **VERDICT: PASS**；其 NIT 全部收下：FR-005 措辞收紧、`note_page.dart` 里那条排版畸形的引用改写、以及「取消样式曾被错误排除」（复核员引《03-编辑与排版.md:56》），改成 FR-006 实现而不是记成欠账
- [x] FR-001..FR-005 的 5 条用例存在且**先红后绿**：红 = `00:01 +0 -5: Some tests failed.`
      （`Expected: exactly one matching candidate / Actual: ... Found 0 widgets with widget matching predicate`，
      即 tooltip「加粗」不存在）；实现后 `00:01 +5: All tests passed!`
- [x] 反向探针：摘掉两个 `IconButton` ⇒ `00:01 +0 -5`；`cp` 还原后 `cmp -s` 判「byte-identical OK」，
      再跑 `00:01 +5: All tests passed!`
- [x] `dart format --output=none --set-exit-if-changed`（仅本轮 2 个显式文件）⇒ `Formatted 2 files (0 changed)`、rc=0

## 门禁（最终状态一次跑完，日志 `/tmp/r38_gates.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | rc=0、无输出（扫的是本轮工作树改动） |
| 2 `dart format --output=none --set-exit-if-changed lib/features/note/note_page.dart test/features/note/note_style_menu_test.dart` | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found! (ran in 1.0s)`。**第一遍曾红**：`1 issue found` —— 我在测试里把假仓库成员写成 `notes()`（真成员是 `NoteRepository.list()`），修于 `2b23ae9` 后复跑为 0 问题 |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!`（基线 9 张，**未重录**） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:12 +714 ~26: All tests passed!`。计数可核对：同一 base `a1d7733` 上第 35 轮加 7 例时是 `+716` ⇒ develop 基线 709，本轮 +5 ⇒ 714（objective 里那句「713 passed」是 2026-09-23 当时的数） |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `Compiling lib/main.dart for the Web... 20.6s` + `✓ Built build/web` |

## 仍缺（不谎称完成）
- [ ] 折叠光标下「先点样式后打字」在真机（iOS/Android 软键盘）上的表现未验；本机只有 web 构建可用
      （`github.com` 超时 ⇒ iOS SPM 编译不可用）。
- [ ] 嘀嗒《11-笔记与摘要.md:43》原文是「键盘上方的样式菜单」，本端做成内容框上方一排按钮（桌面/移动同一位置），
      位置语义与「键盘上方」不严格一致，需产品确认是否要求跟随软键盘。
- [ ] 「等样式」（斜体、删除线、标题等）未做 —— 本轮只落原文点名的加粗与高亮两种。
- [ ] 向后选择（Shift + ←）的选区方向未回写，见 `spec.md` 取舍。
- [ ] 矩阵第 89 行 ② 的回写：合并后把「已实现待合并」换成合并 SHA 并复算行号。

日志：第一遍（analyze 红的那遍）留在 `/tmp/r38_gates_pre.log`，最终状态在 `/tmp/r38_gates2.log`。
**rc 口径要如实说**：`r38_gates2.log` 里 gate4/5/6 的 `rc=` 字段是**空的** —— 本机 zsh 没有 bash 的 `${PIPESTATUS[0]}`，所以这三项按输出末行（`All tests passed!` / `✓ Built build/web`）判定，不是按退出码；gate1-3 单独跑过、退出码 0。日志头部写的 `head=9896840` 是当时的 HEAD，测试文件的修复（`2b23ae9`）在门禁开跑前已落到工作树（gate3 报 `No issues found!` 可反证）。
