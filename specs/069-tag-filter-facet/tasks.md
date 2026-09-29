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

## 四、六道门禁（跑在最终字节上，日志 `/tmp/r136/gates334b.log`）

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
- 矩阵 `#21/#22` 的 FL 面本轮只推进"标签维度生效"一格；未合并 ⇒ 不翻状态，只在这里记「已实现待合并」。
