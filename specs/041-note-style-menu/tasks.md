# 041 任务清单

## 已证实
- [x] FR-006 取消样式：2 条新用例（成对包围→剥一层并退回 (0,4)；只选到一半→不误剥），`flutter test test/features/note/note_style_menu_test.dart` ⇒ `00:01 +7: All tests passed!`
- [x] 第 38 轮第 1 轮只读复核 **VERDICT: PASS**；其 NIT 全部收下：FR-005 措辞收紧、`note_page.dart` 里那条排版畸形的引用改写、以及「取消样式曾被错误排除」（复核员引《03-编辑与排版.md:56》），改成 FR-006 实现而不是记成欠账
- [x] FR-001..FR-005 的 5 条用例存在且**先红后绿**：红 = `00:01 +0 -5: Some tests failed.`
      （`Expected: exactly one matching candidate / Actual: ... Found 0 widgets with widget matching predicate`，
      即 tooltip「加粗」不存在）；实现后 `00:01 +5: All tests passed!`
- [x] 反向探针（**在最终状态 `f941ee5` 上重跑**，早期只覆盖 5 例）：整块摘掉 `Wrap(spacing: 8, …)` 两个 `IconButton`（含 `Wrap` 本身，`note_page.dart` 330-346 行）
      ⇒ `00:01 +0 -7: Some tests failed.`，7 例**全部**红（含两条「取消样式」用例，说明它们确实走 UI 而不是只测纯函数）；
      失败明细点名 `320px + 1.3 倍字号下样式菜单不溢出`、`光标折叠时点「高亮」插入成对标记并把光标落在中间`、
      `再点同一个样式是取消`、`只选到一半标记时不误剥` … and 3 more。
      `cp` 还原后 `cmp -s` 判「byte-identical OK」，`git status --short` 只剩 ` M pubspec.lock`（不随 PR 提交）。
- [x] `dart format --output=none --set-exit-if-changed`（仅本轮 2 个显式文件）⇒ `Formatted 2 files (0 changed)`、rc=0

## 门禁（最终状态 `f941ee5` 一次跑完，日志 `/tmp/r38_gates3.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | rc=0、无输出（扫的是本轮工作树改动） |
| 2 `dart format --output=none --set-exit-if-changed lib/features/note/note_page.dart test/features/note/note_style_menu_test.dart` | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found! (ran in 1.0s)`。**第一遍曾红**：`1 issue found` —— 我在测试里把假仓库成员写成 `notes()`（真成员是 `NoteRepository.list()`），修于 `2b23ae9` 后复跑为 0 问题 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`（基线 9 张，**未重录**） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:18 +716 ~26: All tests passed!`。计数可核对：同一 base `a1d7733` 上第 35 轮加 7 例时也是 `+716` ⇒ develop 基线 709，本轮 709+7=716（objective 里那句「713 passed」是 2026-09-23 当时的数）。**此前一行写的是 `+714`**：那遍跑在 `2b23ae9`（只有 5 例）上，FR-006 补的 2 例落进 `f941ee5` 后重量为 716 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `Compiling lib/main.dart for the Web... 20.6s` + `✓ Built build/web` |

## 仍缺（不谎称完成）
- [ ] 折叠光标下「先点样式后打字」在真机（iOS/Android 软键盘）上的表现未验；本机只有 web 构建可用
      （`github.com` 超时 ⇒ iOS SPM 编译不可用）。
- [ ] 嘀嗒《11-笔记与摘要.md:43》原文是「键盘上方的样式菜单」，本端做成内容框上方一排按钮（桌面/移动同一位置），
      位置语义与「键盘上方」不严格一致，需产品确认是否要求跟随软键盘。
- [ ] 「等样式」（斜体、删除线、标题等）未做 —— 本轮只落原文点名的加粗与高亮两种。
- [ ] 向后选择（Shift + ←）的选区方向未回写，见 `spec.md` 取舍。
- [ ] 矩阵第 89 行 ② 的回写：合并后把「已实现待合并」换成合并 SHA 并复算行号。

日志：第一遍（analyze 红的那遍）留在 `/tmp/r38_gates_pre.log`；`/tmp/r38_gates2.log` 是**旧状态**（`2b23ae9`，5 例）的那遍，其 `+714` 已被上一行标注作废；最终状态 `f941ee5`（7 例）在 `/tmp/r38_gates3.log`，头部即 `== FINAL-STATE gates run #3 08:37:40 head=f941ee5 ==`。
**rc 口径要如实说**：`r38_gates3.log` 里只有前三项打了 `rc=0`（`git diff --check` / `dart format` / `flutter analyze`）；
golden、全量测试、web 构建三项**没有退出码**——本机 zsh 没有 bash 的 `${PIPESTATUS[0]}`，管道后取到的是空值，
所以这三项按输出末行判定（`00:04 +9: All tests passed!` / `02:18 +716 ~26: All tests passed!` / `✓ Built build/web`）。
空 `rc=` 意味着测量方式断了，不代表通过，也不代表失败。
