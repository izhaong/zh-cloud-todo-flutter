# 045 执行台账

## 状态：本轮完工，门禁全绿，待只读复核 `VERDICT`（分支 `feat/335-filter-preview-mode`，基线 `origin/develop@9032005`）

矩阵 #22 **不动**：本分支未合并 ⇒ 只能写「已实现待合并」，不翻状态（下轮入口第 1 条）。

## 一、判据与现状

判据源逐字见 `spec.md`（`zh-cloud-docs origin/develop` 的《05-过滤器》`:47/:57/:61/:65`）。
现状三条成对判据在 `spec.md`「现状」一节，本笔开工时全部现跑现读过：
`预览模式|previewMode` 在 `origin/develop -- lib` = **0 命中**；
对照 `预览` 在 lib 有 **6 个文件**命中（说明 0 命中是"没用过这个词"，不是检索面坏）；
`高级筛选` 在 `filter_bar.dart` 命中 `:313`（对话框标题）与 `:412`（应用按钮）⇒
本面是往既有对话框里加东西，不是新建界面。

## 二、红测（实现之前）

`flutter test test/features/filter/filter_advanced_preview_test.dart` ⇒ `00:01 +0 -3`（三条全红，
红在「预览模式」这一格不存在：第 2、3 条先撞 `_setToggle` 里那句 `expect(toggle, findsOneWidget)`，
不是撞在 `ensureVisible` 的 `Iterable.single` 崩溃上 —— 第一版确实崩在崩溃上，已把断言提到前面，
这样红的东西就是判据本身）。用例数复算：`grep -c '  testWidgets(' <该文件>` ⇒ `3`。

## 三、反向探针（每条都要变红，还原后 `cmp` 干净）

摘的是实现，不是测试。日志在 `/tmp/gates-335/`，脚本 `/tmp/probes335.sh`（每次探针后 `cp` 还原并 `cmp -s`）。

| 探针 | 摘掉什么 | 预期红 | 实测 |
| --- | --- | --- | --- |
| PA | 预览永远不算（`previewEnabled && …` 前置 `false`） | 「只列命中项」「草稿仍在」 | `+1 -2`，红的正是这两条 |
| PB | 预览忽略用户刚输入的关键词（`keyword: draftKeyword` → `keyword: ''`） | 同上两条 | `+1 -2`，同上 |
| PC | 默认就开着预览（`var previewEnabled = false` → `true`） | 「默认关 / 关时不显示预览区」 | `+2 -1`，红的是第 1 条 |

三个探针的"命中改动处数"都各是 1（脚本里 `grep -c` 现打），不存在改了个不存在的串而静默变绿；
`ALL-RESTORED` 与 `git status --porcelain lib/...` 只剩我本轮真实改动 ⇒ 还原干净。
还原后同一条命令 ⇒ `00:01 +3: All tests passed!`。

## 四、六道门禁（跑在最终字节上，日志 `/tmp/gates-335/`）

| 门禁 | 读数 |
| --- | --- |
| 1 `git diff --check` | 无输出，`diffcheck_rc=0`（`g1-diffcheck.log`） |
| 2 `dart format --output=none --set-exit-if-changed`（本轮 3 个 .dart，未做全仓原地格式化） | `format_rc=0`（`g1-format.log`）。**这一格可信的前提**：先取 `HEAD` 两份同名文件到 `/tmp/fmt-head/` 跑同一条判据 ⇒ `Formatted 2 files (0 changed)`，`rc=0` ⇒ 基线本来就是格式化过的，原地格式化不会顺手改无关代码 |
| 3 `flutter analyze` | `No issues found!`，`analyze_rc=0` |
| 4 `flutter test --tags golden` | `golden_rc=0`（`g1-golden.log`）；跑完 `git status --porcelain` 里 png/gold 计数 `0`（`g1-golden-dirty-png-count.txt`）⇒ 9 张基线一张未重录。这条判据不是恒绿：9 张基线是受版本管理文件（`git ls-files 'test/*' \| grep -cE '\.(png\|gold)$'` ⇒ `9`），被重录就会以 ` M test/goldens/…png` 出现在同一条 porcelain 里 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:24 +901 ~26: All tests passed!`，`test_rc=0`（`g1-test.log`）。对账用实跑不作减法反推：develop 基线 898 的两处日志指针是 `/tmp/r68/baseline_develop.log:1152` 与 `/tmp/r77c/rerun-898.log:1154`，本轮新增 3 条 ⇒ 898 + 3 = 901 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`，`build_rc=0` |

`git status --porcelain pubspec.lock` ⇒ 空（`g1-publock.log`）⇒ 门禁的 `pub get` 没把本机镜像扫进这笔。

## 五、本轮改了什么

| 文件 | 改动 |
| --- | --- |
| `lib/features/filter/filter_bar.dart` | `FilterBar` 多一个可选入参 `previewResolver`；新增私有 `_draftFilter`；「高级筛选」对话框加「预览模式」开关（`Key('task-filter-advanced-preview')`，默认关）与预览区（`Key('task-filter-advanced-preview-panel')`，念「命中 N 项」+ 最多三条标题）；三个输入框补 `onChanged` 触发重算；`应用高级筛选` 的 `onChanged` 改走 `_draftFilter` |
| `lib/features/task/tasks_by_list_page.dart` | `FilterBar(...)` 注入 `previewResolver`，闭包用 `_openFilterPanel(raw)` 那份未过滤列表 + `_selectedListId` + `currentDateTimeProvider` ⇒ 与列表渲染同一口径 |
| `test/features/filter/filter_advanced_preview_test.dart` | 新增 3 条用例（见二、三节） |
| `specs/045-filter-preview-mode/{spec,plan,tasks}.md` | 本台账 |

## 六、下一轮入口

1. **矩阵 #22 的回写**（docs 仓）：本 PR 合并后，《05-过滤器》`:65`「预览模式」那一面从「缺」变成
   "有（FL）"，且要在同一行里把它与 `:61/:71` 的「或/且」布尔组合（FL #334，仍缺）分开写清楚。
   **注意**：`#22` 这一行号在 `dida-parity-matrix.md` 里散在**多张表**（主表 + 校对/快照样），
   改前先按行号搜遍再动，别只改一处造成自相矛盾；且 `!102`/`!105` 都在改同一份文件 ⇒
   优先追加到其中一条已开的 docs 分支上，不要再新切一条。
2. 只读复核（`claude -p` 门禁）拿 `VERDICT`，通过后 push → 开 PR 指向 `develop`，正文 `Refs #335`。
3. 台账自扫判据：本分支不含 `tool/check_spec_selfscan.py`（它在 FL PR !364 的分支上），
   取法同第 86 轮：`git show origin/feat/361-calendar-list-timeline:tool/check_spec_selfscan.py`，
   跑 `python3 <该脚本> specs/045-filter-preview-mode/tasks.md` 现读到「失项 0 条」才算改完。
4. `:61`/`:71` 的「或/且」布尔组合与同条件内标签且/或 —— FL #334，未排期。
