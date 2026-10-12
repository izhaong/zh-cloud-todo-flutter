# 070 · 台账（第 152 轮，2026-09-30）

FL Issue #420。分支 `feat/420-filter-tag-condition`，基线 FL `origin/develop@4f203b8453fa`（工作树 `/private/tmp/wt-fl-420`）。

## 一、红测（先红后实现）

新文件 `test/features/filter/advanced_filter_tag_condition_test.dart` 在实现前跑，红在这条主张本身：
`Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'task-filter-tag-section'>]: []>`，
reason 写的是《05-过滤器》`:6`/`:61`「标签是筛选条件之一」。日志 `/tmp/r136/red420d.log`。
红的是"这一格不存在"，不是编译崩溃：那次运行里 chip 类判据也各红各的（`findsNothing` 而非 exception）。

## 二、实现后用例（7 条全绿，日志 `/tmp/r136/g420d.log`）

| # | 钉的是 | 读数 |
| --- | --- | --- |
| 1 | 小节存在且选项来自标签列表 | 4 个标签 chip 各 `findsOneWidget` |
| 2 | 缺省「且」：预览实时算命中 | 选「专注」= `命中 1 项`；再加「评审」= `命中 1 项`；撤掉「专注」= `命中 2 项` |
| 3 | 应用后条件真进了 `TaskFilter` | 筛选条入口文案变 `标签` |
| 4 | 四件套①320 宽 + 1.3 倍 | `MediaQuery.textScalerOf(小节 context).scale(10)` ≈ 13，`takeException()` 为 null |
| 5 | 四件套②独立读屏语义 | `bySemanticsLabel('标签 专注，未选中')` → 点选后变 `'标签 专注，已选中'` |
| 6 | 四件套③失败保留已加载数据 | 标签流改错误分支 ⇒ 小节显示「标签暂不可用」，已填关键词仍在 |
| 7 | 四件套④过期响应不覆盖新响应 | 流后到第二份 ⇒ 已选中的 chip 仍 `selected: true` |

用例 4/5 首版各自红过：① 320 宽下筛选条横向滚动，`tap` 中心点落到屏外（`Offset(413.5, 556.0)` 越界）⇒ 改成先
`ensureVisible` 再 tap；② `ensureSemantics()` 的句柄必须**在测试体内** dispose，挂 `addTearDown` 太晚
（`A SemanticsHandle was active at the end of the test`）。都是测试自己的问题，不是实现问题。

## 三、六道门禁（`/tmp/r136/gates420-g*.log`）

| # | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check` | rc=0 |
| 2 | `dart format --output=none --set-exit-if-changed` 本轮 2 个显式文件 | **当时是空心读数**：两个路径被当成一个参数，rc=0 而一个文件都没格式化（见 §五） |
| 3 | `flutter analyze` | `No issues found! (ran in 3.4s)` rc=0 |
| 4 | `flutter test --tags golden` | `+9: All tests passed!` rc=0，`png=9`、`dirty=0` ⇒ 基线未重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:15 +1254 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

差集规模与 `pubspec.lock` 都现跑复核：`git diff --cached --name-only | wc -l` = 5（1 份 `lib/features/filter/filter_bar.dart`、1 份新测试、3 份 `specs/070-filter-tag-condition/`），`git diff --cached --name-only | grep -c pubspec.lock` = 0 ⇒ 门禁期间 `pub get` 没把本机镜像扫进差集。

## 四、没做与下一步

- 「且 / 或」档位本身（`:71` 第二句的「或」）= FL Issue #334，本轮只把宿主 UI 补上；#334 现在**没有授权障碍**
  （上一轮我写的"要重录 golden 基线"是错的，9 张基线渲染的是 workspace 面，不覆盖这张对话框）。
- 矩阵 #22 的「面板按标签筛」这一格：PR !115 已按 FL #420 记为缺；本轮合并后由 docs 侧翻面（只引已合并 SHA）。

## 五、复核（第 1 轮 `VERDICT: FAIL` → 处置）

被审 head `1b39f26`（基准 `origin/develop` = `4f203b8453fa`）。复核日志 `/tmp/r136/review-420-r1.result.md`。
A（判据源逐字）、B（红测真红）、C（求值口径未偷改）、D（四件套真被测）、F（范围诚实）判 PASS；
唯一 FAIL 在 E 节第 2 道：`/tmp/r136/gates420-g2.log` 全文是
`No file or directory found at "lib/…filter_bar.dart test/…advanced_filter_tag_condition_test.dart"` 与
`Formatted no files in 0.00 seconds.`，**rc=0 却零个文件被格式化** ⇒ §三 表里那句「本轮 2 个显式文件 rc=0」当时不成立。

这条不只是「没测到」：换成正确的两参命令重跑，实测 `Changed test/features/filter/advanced_filter_tag_condition_test.dart`、
rc=1 ⇒ **空心门禁正好盖住了一份未格式化的文件**。处置 = 用 `dart format` 就地规范化那一份测试文件
（改动 1 个文件、`33 insertions / 13 deletions`、无 `pubspec.lock`），提交 `6a14d7a`；第 1 道补出独立日志
`/tmp/r136/gates420-g1.log`（rc=0、无输出）。

`6a14d7a` 上六条门禁重跑，rc 均为 0（日志 `/tmp/r136/g421b-g1..g6.log`）：

| # | 读数 |
| --- | --- |
| 1 | `git diff --check 4f203b8453fa..HEAD` rc=0、空输出 |
| 2 | `Formatted 2 files (0 changed) in 0.01 seconds.` |
| 3 | `No issues found! (ran in 2.4s)` |
| 4 | `00:04 +9: All tests passed!`（`test/goldens/todo_workspace/` 脏文件数 = 0 ⇒ 基线未重录） |
| 5 | `03:18 +1254 ~26: All tests passed!` |
| 6 | `✓ Built build/web` |

复核的 NIT 两条已处置：`spec.md:4` 的「74 行」按镜像原文改为 **73 行**（现算：
`git -c core.quotePath=false ls-tree -r --name-only origin/develop | grep '05-过滤器'` 取路径，再
`git show origin/develop:<该路径> | wc -l` = 73）；「第 1 道无独立日志」按上表补跑。

第 2 轮复核要重绑：`1b39f26` → `6a14d7a` 动了 `test/` 下的文件，覆盖面按 `lib`+`test` 两棵树现算，不沿用第 1 轮的 PASS。
