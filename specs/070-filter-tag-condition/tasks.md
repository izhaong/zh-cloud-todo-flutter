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
| 2 | `dart format --output=none --set-exit-if-changed` 本轮 2 个显式文件 | rc=0 |
| 3 | `flutter analyze` | `No issues found! (ran in 3.4s)` rc=0 |
| 4 | `flutter test --tags golden` | `+9: All tests passed!` rc=0，`png=9`、`dirty=0` ⇒ 基线未重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:15 +1254 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

差集规模与 `pubspec.lock` 都现跑复核：`git diff --cached --name-only | wc -l` = 5（1 份 `lib/features/filter/filter_bar.dart`、1 份新测试、3 份 `specs/070-filter-tag-condition/`），`git diff --cached --name-only | grep -c pubspec.lock` = 0 ⇒ 门禁期间 `pub get` 没把本机镜像扫进差集。

## 四、没做与下一步

- 「且 / 或」档位本身（`:71` 第二句的「或」）= FL Issue #334，本轮只把宿主 UI 补上；#334 现在**没有授权障碍**
  （上一轮我写的"要重录 golden 基线"是错的，9 张基线渲染的是 workspace 面，不覆盖这张对话框）。
- 矩阵 #22 的「面板按标签筛」这一格：PR !115 已按 FL #420 记为缺；本轮合并后由 docs 侧翻面（只引已合并 SHA）。
