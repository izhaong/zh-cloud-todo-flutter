# 台账：详情标签空态文案（FL Issue #332，第 168 轮）

分支 `fix/332-tag-empty-entry`，基线 `origin/develop`。规格见同目录 `spec.md`。
分支是从 `origin/develop` 另起工作树 `git apply` 出来的，不与 !427 堆叠（`git apply --check` 先过）。

## 一、红测 → 实现

- 改前 `flutter test test/features/task/tag_empty_state_entry_test.dart` ⇒ `00:00 +0 -2`，
  点名找不到的新文案：`Expected: exactly one matching candidate` /
  `Actual: _TextWidgetFinder:<Found 0 widgets with text "暂无标签，可先在侧栏「标签」里创建">`
  ⇒ 红在缺文案，不是编译红。同一次跑里「清单页没有入口」那条也红，
  原因是我第一版判据按子串扫，把 `TasksByListPage(` 也算成了引用——那是我自造的假判据。
- 判据纠错：改成按「前一个字符不是字母」再扫 ⇒ 该条转绿。
- 改后同一条命令 ⇒ `00:00 +2: All tests passed!`。
- 反向对照（现跑，带失败断言行号自证）：把 `lib/features/task/task_detail_pane.dart` 的文案退回旧句后重跑该文件
  ⇒ `00:02 +1 -2`，栈里两行分别指到 `test/features/task/tag_empty_state_entry_test.dart:63`（空态文案那条）
  与 `test/features/task/tag_empty_state_entry_test.dart:104`（新加的 320px + 1.3 倍字号那条读 `find.text(新文案)`）
  ⇒ 两条判据都咬在这行文本上，不互相顶替；字节用 `cp` 备份、`cmp -s` 还原，输出 `restored byte-identical`。
  上一版记的是 `00:00 +1 -1`，那是加窄屏用例之前的读数；加了一条之后必须重跑，现读就是 `+1 -2`。

## 二、六道门禁（跑在最终字节上）

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check`（工作树与 `origin/develop HEAD` 差集各一次） | rc=0 |
| 2 `dart format --output=none --set-exit-if-changed` 加两个字面量路径 | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found!`、rc=0 |
| 4 `flutter test --tags golden` | `00:09 +9: All tests passed!`、rc=0，基线未重录（跑在含新窄屏用例的字节上） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `04:44 +1317 ~26: All tests passed!`、rc=0（+1317 = 前一笔的 +1316 再加新窄屏那条） |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、rc=0 |

- 门 5 的 `+1316` 与 !427 分支的 `+1318` 差 2，是「那分支加 4 条、本分支加 2 条」的净差
  （`git show 772029f:test/features/task/detail_hash_tag_test.dart` 数 `testWidgets(` 得 4，本分支新增的两条 = 一份文件里的 1 个 testWidgets + 1 个 test）。
  上一版把它写成「不含两条用例」是把 4 说成 2，已由 !428 第 1 轮复核抓出。
- 门 1 到门 6 现读都在头 `0a98890` 之后重跑：`git diff --check` rc=0、`dart format --output=none` rc=0、
  `flutter analyze` `No issues found!`、门 4/5/6 如上；本台账这一笔只动 `specs/`，门 2 至门 6 由上文承接、门 1 在新头另跑。
- 卫生：`git status --short` 在门禁后为空；`pubspec.lock` 未进暂存（门 5、门 6 跑在提交之后）。

## 三、四件套归属

只改一行已渲染文本，但这块文本只在「任务零标签」时出现，**没有任何既有用例量到它**：
`embedded_detail_header_narrow_test.dart` 走的是 `TodoVisualFixture.metadataTaskId`，
而 `test/support/todo_visual_fixture.dart:197-207` 给该任务种了 3 条标签 ⇒ 空态那一行在那套树里根本不渲染；
`task_detail_pane_test.dart` 的语义断言只覆盖 title/description/save 三个标识（`git grep -n 暂无标签 origin/develop -- test` 零命中）。
⇒ 「由既有用例承接」这句是空头归属（!428 第 1 轮复核判 FAIL 成立）。
改法是把两面量进本单自己的用例：新增 `320px + 1.3 倍字号` 一条（零标签任务 + 长标题，断言无溢出异常、
该 Text 的 `getSemantics(...).label` 含「侧栏「标签」」、`RenderBox` 宽 ≤ 320），
连原文案那条一起 ⇒ 该文件 `00:00 +3: All tests passed!`。
「失败保留已加载数据」与「过期响应不覆盖新响应」在本单不适用：这块文本没有写路径，也没有新的异步回写。

## 四、只读复核与矩阵

第 1 轮派单审最终头，要求逐条复算 `spec.md` 第二节三条判据与本台账里每个数字。
VERDICT 未回 ⇒ 本 PR 不合并；矩阵 #21 那一格不翻状态，只写「已实现待合并 + PR 号」。
