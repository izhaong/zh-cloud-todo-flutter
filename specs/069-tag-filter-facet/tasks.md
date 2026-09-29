# 069 · 台账（第 148 轮，2026-09-30）

FL Issue #417。分支 `feat/334-tag-filter-logic`（工作树 `/private/tmp/wt-fl-334`），基线 FL `origin/develop@5a831a1`。

## 一、红测（先红后实现）

实现前跑 `flutter test test/features/filter/task_filter_tag_logic_test.dart`：

```
test/features/filter/task_filter_tag_logic_test.dart:71:7: Error: No named parameter with the name 'taskTagIds'.
      taskTagIds: null,
lib/features/task/tasks_by_list_page.dart:2147:16: Context: Found this candidate, but the arguments don't match.
```

⇒ 红在编译期，钉的就是"这里根本没有标签分支"这条主张（与 spec §二 第 1 条同源）。

## 二、反向探针（证明新用例真会红）

摘掉 `applyTaskFilter` 里那段标签分支 ⇒ `flutter test test/features/filter/task_filter_tag_logic_test.dart` 回 `00:00 +2 -2`（4 条里红 2 条），
`cp` + `cmp -s` 还原后报 `restored byte-identical`。日志 `/tmp/r136/gates334.log`。

红的是"只含其一不该出现"与"超集仍命中"这两条判据本身，不是崩溃；第 3 条（未选标签时不受影响）与第 4 条（守卫撤销）在摘分支后仍绿，
说明它们钉的是另两件事，这条差异如实记在这里。

## 三、既有用例的期望改动（本轮动了别人写的测试：只这一份文件）

`test/features/filter/saved_filters_test.dart:230` 原来断言 `in_progress` 与 `tagIds` 两条都标「本机暂不支持套用」且都点不动。
第 4 条正是 #417 的病症本身 ⇒ 期望改成：只 `in_progress` 一条不支持、仍点不动；带标签的那行用
`find.ancestor(of: text('带标签的'), matching: textContaining('本机暂不支持套用')) ⇒ findsNothing` 反过来钉住它已恢复可套用。
真不支持的判据没有丢（`in_progress` 那条保留）。

## 四、六道门禁（最终字节 = `git -C /private/tmp/wt-fl-334 rev-parse HEAD` 现读 `7449d94a1`，日志 `/tmp/r136/gates334b.log`）

| # | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --cached --check`（`git add -A` 后，即对 develop 的差集） | rc=0 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 6 个 dart 文件>` | `Formatted 6 files (0 changed)` rc=0 |
| 3 | `flutter analyze` | `No issues found! (ran in 1.9s)` rc=0 |
| 4 | `flutter test --tags golden` | `00:04 +9: All tests passed!` rc=0（`png=9`、`goldens_dirty=0` ⇒ 基线未重录） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:10 +1231 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

`pubspec.lock` 未进差集（`lock_in_diff=0`）。首轮跑门禁时门 2 rc=1（我 python 插进去的代码没格式化）、门 5 rc=1
（上一条既有用例的旧期望），两处都是真修：`dart format` 就地只格式化本轮 6 个文件、期望按上面第三节改，
然后六道在最终字节上重跑，才是这张表里的数。

## 五、四件套

本轮不新增界面、不改视觉结构（只在既有 builder 里加一个提前 return 的加载分支）⇒ ① 320px + 1.3 倍字号、② 独立读屏语义
判「本轮无新增承载体」；③④ 见 `spec.md` §四：索引流出错时 `valueOrNull` 保留旧索引（不清空已加载任务），
列表与预览读同一个 provider 实例、`watch()` 后到覆盖先到。

## 六、没做与下一步

- `:71` 的「或」与跨条件布尔组合、多语句查询 = FL Issue #334（`TaskFilter` 需 `tagLogic`；写契约时值用小写 `and`/`or`）。
- 高级筛选 sheet 里没有「且/或」控件；加控件会碰 golden（9 张基线）⇒ 触碰前先要重录基线的授权。
- 矩阵 `#21/#22` 的 FL 面本轮只推进"标签维度生效"一格。PR !418 已于 2026-09-30 合进 develop（`git rev-parse origin/develop` 现读
  `0c7bce9c4d74ec44fe3a94423e656f76bf5af198`），本节第六道那条「未合并」的约束从此解除；但矩阵翻转要落在 docs 仓的
  对照表 PR 里、且要等 docs !113 那轮先落地（同一张表并行开分支会互相覆盖），本轮只登记不翻。

## 七、第 1 轮只读复核（`claude -p --permission-mode plan`，报告 `/tmp/r136/review-418-r1.report.md`）

结论 `VERDICT: PASS`。复核进程自报的取数基准 = `origin/develop@5a831a19`，被审字节 = `7449d94a1f7b8ca1c3394aab2cd57adea6ca9473`
（判据 `git -C /private/tmp/wt-fl-334 rev-parse HEAD`，2026-09-30 现读同值）⇒ 审的就是第四节那张表所在的最终字节，不是中途的旧提交。

四条 NIT 逐条给处置：

| NIT | 复核原文摘要 | 处置 |
| --- | --- | --- |
| D | `saved_filters_test.dart` 只钉了带标签行「未标不支持」，未在 `TasksByListPage` 上端到端断言点 `pulled-with-tag` 后真筛出标签结果集 | 认，本轮不补：那一跳要钉的是 `TaskFilter.tagLogic` 的语义 = FL Issue #334 的判据面，本轮加 tap 会把两件事塞进一个用例 |
| C（性能） | `ref.watch(taskTagIndexProvider)` 无条件订阅整表，任一标签写入都重建整 Map | 认，不改：整表索引是 `spec.md` §三 第 3 条写明的取舍，按清单收窄要改 `watchTagIndex()` 的 SQL |
| B | 索引未就绪时列表转圈、预览报 0 项，两端不对称 | 认，不改：两侧行为各在 `spec.md` §四 的口径内，且预览面板只能在列表渲染后打开 |
| E | 门禁表未内嵌 head SHA，只以 worktree 路径推断 | 按本条修：第四节标题现直接带 `7449d94a1` 与取数命令（本节开头那句是同一改动的另一处） |

复核员自己的两处锚点错位，回源后按仓内实际字节改指（只改证据位置，不改结论）：

- A 项把「AND 用例」的可复算指针写成 `test/features/filter/ui_tag_logic_test.dart` 加 `:41-44` 两段拼出来的，
  而这份文件在仓内不存在（判据 `git -C /private/tmp/wt-fl-069wb ls-files test/features/filter` 现读三份文件，无此名）⇒ 真锚点是
  `test/features/filter/task_filter_tag_logic_test.dart:41`，用例名「标签条件按“且”求值：只含其一的任务不该出现」，
  同文件 `:57` 钉超集仍命中、`:72` 钉映射缺失、`:84` 钉还原成本机条件。
- A 项把标签分支区间写成 `:2182-2186`，尾行不对：`:2184` 才是 `if (!owned.containsAll(filter.tagIds)) return false;`，
  `:2186` 已是优先级分支（判据 `grep -n "filter.tagIds" lib/features/task/tasks_by_list_page.dart` 现读三处命中 183、2182、2184）。

台账自扫：`python3 tool/check_spec_selfscan.py specs/069-tag-filter-facet/tasks.md` ⇒ rc=0、失项 0 条。
