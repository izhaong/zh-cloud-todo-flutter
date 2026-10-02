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
- 反向对照（现跑）：把 `lib/features/task/task_detail_pane.dart` 的文案退回旧句后重跑该文件
  ⇒ `00:00 +1 -1`，红的正是断言新文案的那条；字节用 `cp` 备份、`cmp -s` 还原，输出 `restored byte-identical`。

## 二、六道门禁（跑在最终字节上）

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check`（工作树与 `origin/develop HEAD` 差集各一次） | rc=0 |
| 2 `dart format --output=none --set-exit-if-changed` 加两个字面量路径 | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found!`、rc=0 |
| 4 `flutter test --tags golden` | `00:05 +9: All tests passed!`、rc=0，基线未重录 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:34 +1316 ~26: All tests passed!`、rc=0 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、rc=0 |

- 门 5 的 `+1316` 比 !427 分支的 `+1318` 少两条：本分支不含 `test/features/task/detail_hash_tag_test.dart`
  里的两条用例，不是有用例掉了。判据 `git diff --name-only origin/develop HEAD -- test` 只列本单那一份文件。
- 门 1 的差集那次跑在 `66e26d7` 上；specs 目录另加一笔（只动 `specs/`），
  所以门 2 至门 6 的读数由该笔承接，门 1 在新头另跑一次。
- 卫生：`git status --short` 在门禁后为空；`pubspec.lock` 未进暂存（门 5、门 6 跑在提交之后）。

## 三、四件套归属

本单没有新增界面或控件，只改一行已渲染文本的内容：
「320px + 1.3 倍字号」「独立读屏语义」「过期响应不覆盖新响应」三面不新增断言，
由既有用例 `test/features/task/embedded_detail_header_narrow_test.dart` 与
`test/features/task/task_detail_pane_test.dart` 量的同一块表面承接；
「失败保留已加载数据」在本单不适用——这里没有写路径，读失败时列表仍按上一份标签渲染。

## 四、只读复核与矩阵

第 1 轮派单审最终头，要求逐条复算 `spec.md` 第二节三条判据与本台账里每个数字。
VERDICT 未回 ⇒ 本 PR 不合并；矩阵 #21 那一格不翻状态，只写「已实现待合并 + PR 号」。
