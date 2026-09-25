# 任务清单：日历「列表视图 - 显示时间轴」（specs/052 / FL Issue #361 / 矩阵 #29）

分支 `feat/361-calendar-list-timeline`，基线 `origin/develop@9032005`。代码提交 `899dcf2`。

## 完成情况

- [x] `spec.md` 来源表：《04-列表视图：按天查看任务.md》`:7/:9/:16/:18/:23` 逐字引用；
      《08-常见问题.md》按 tab 分类（`:11` mobile 长按 / `:19` desktop 点击 / `:32` 全天任务栏拖拽 /
      `:79`+`:83` 隐藏时段 / `:41`+`:172-175` 桌面缩放）⇒ 四条进「明确不做」并各给理由
- [x] 红测（步骤见下「红测读数」——**这一条是编译红，不是行为红**，如实标注）
- [x] `tasksOnDayByTime` 共享取数 + `_DayTimeline` + 工具条「显示时间轴」图标（FR-1/FR-2/FR-4/FR-8）
- [x] 列表档锚点按天移动（FR-7，仅开启时）+ 生产调用点注入 `now`（FR-6）
- [x] 四件套：320×568 + 1.3 倍在日历列表档自己的 context 上量（`MaterialApp(builder:)` 传档位 +
      用例内自检继承值）、独立读屏语义（label 全等 + `isButton` + `isSelected`）、
      开→关→开行集合不变；④「过期响应不覆盖新响应」**不适用**（本面零异步新增，理由见 `spec.md` 五-4）
- [x] 六道门禁跑在**已提交终态 `899dcf2`** 的字节上，日志 `/tmp/r77/gates.log`
- [x] 九条反向探针 PN–PV，全部红在该咬的用例名上，`/tmp/r77/probes-final.log`
- [ ] **只读复核未派** ⇒ 这一格是欠的，不得当作已通过
- [ ] 矩阵 #29 回写（含本轮查出的"按天"错判纠正）——未合并前状态一律不翻，只写「已实现待合并」
- [ ] 第 78 轮入口：FL #362「列表视图下拉展开日历全景」（`spec.md` 已登记，不混进本单）

## 红测读数

```
$ flutter test test/features/task/calendar_list_timeline_test.dart
00:00 +0 -1: Some tests failed.
  Error: Method not found: 'tasksOnDayByTime'.        ×7
```

⚠️ **计数停在 `+0`、状态是 `loading …[E]` ⇒ 这是编译红**（新章节日的第一版测试引用了还不存在的 API）。
它只证明"接口没实现"，不证明"行为错"。真正钉行为的是绿测之后那九条反向探针。

绿测（同一条命令，实现接线后）：

```
$ flutter test test/features/task/calendar_list_timeline_test.dart
00:02 +17: All tests passed!
```

## 六道门禁（基准：已提交 `899dcf2`；日志 `/tmp/r77/gates.log`）

| # | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop HEAD` / `git diff --check HEAD` | rc=0 / rc=0（另：每次提交前 `git diff --cached --check` 均 rc=0） |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 3 个显式文件>` | `Formatted 3 files (0 changed)` rc=0 |
| 3 | `flutter analyze` | `No issues found! (ran in 2.6s)` rc=0 |
| 4 | `flutter test --tags golden` | `00:06 +9: All tests passed!` rc=0；`git status --porcelain -- test` 为空 ⇒ **9 张基线一张都没重录** |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:38 +915 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

计数对账：`915 − 17 = 898`。这个 898 与**第 72 轮复核独立推导出的 develop 全量基线 898**
（那轮是 `905 − 7`）对上 —— 两条互不相干的分支各自减出自己的新增数，落回同一个基线。
`~26` 与既有各轮一致（未新增 skip）。`pubspec.lock` 未进提交：`git log --stat origin/develop..HEAD -- pubspec.lock` 为空。

## 反向探针（九条，`/tmp/r77/probes-final.log`，末行「异常计数 = 0」）

每条都：起跑前 `lib/` 干净 → 对照组先绿 → 打补丁 → 跑测试 → copy 回 + `cmp -s` 逐字节一致。

| 编号 | 摘掉的是什么 | 读数 | 红在哪 |
| --- | --- | --- | --- |
| PN | `tasksOnDayByTime` 不按天过滤（时间轴退化成"全部任务"） | `+2 -15` | 判据面 5/15 命中预期名 |
| PO | 列表档恒渲染旧 `_ListView`（开关完全不接线） | `+9 -8` | 8/8 命中 |
| PP | 「全天」栏整段消失，全天任务被塞进时点段 | `+14 -3` | 3/3 命中 |
| PQ | 入口图标在所有档都出现（把"列表档图标"变成全局开关） | `+16 -1` | 1/1 命中「列表档才有这个图标」 |
| PR | 生产调用点不再把注入的 `now` 喂给 `CalendarView` | `+16 -1` | 1/1 命中「锚定注入的今天」 |
| PS | 列表档关闭时也照议程档移动锚点（FR-7 的"仅开启时"条件被摘） | `+16 -1` | 1/1 命中「不动锚点」那条 |
| PT | 工具条标题恒写「全部任务」（开启后仍给假口径） | `+12 -5` | 5/5 命中 |
| PU | 图标选中态写死 `false`（读屏念不出当前是时间轴） | `+16 -1` | 1/1 命中「选中态随开关翻转」 |
| PV | 议程档自己抄一份取数并丢排序（长出第二个事实源） | `+16 -1` / 既有套件 `+18 -1` | 两条各 1/1 命中 |

**两条如实记录、不算覆盖的结论**（参考面绿，不是探针失败）：

- PN 打补丁后 **`test/m11_b3_calendar_test.dart` 19 条全绿** ⇒ 既有日历套件**不覆盖"按天过滤"**这个机制
  （它有一条 `CalendarView 列表模式按日期排序`，但那条测的正是"跨日清单"，摘掉按天过滤对它零作用）。
  这条恰好反过来印证本轮查出的矩阵事实：**develop 的列表档从来就不是按天的**（`spec.md` 现状表 ⚠️）。
- PS 打补丁后同一套件也全绿 ⇒ "列表档锚点动不动"在既有套件里不可见，只有本轮新写的
  「关闭态拨『下一个』不动锚点：随后开启仍从原选中日开始」钉得住。
  这条断言的设计原因：关闭态下锚点移动与否**对用户不可观察**（内容不看锚点），
  所以只能借"关闭时拨一格、再开启，看到的仍是原选中日"把它变成可观察的。

成对 grep 判据（同一日志末尾）：

```
ABSENT  议程档内联按天过滤（date.year == anchor.year）      命中 0（期望 0）
PRESENT tasksOnDayByTime 消费者                             命中 3（定义 + 议程档 + 时间轴）
PRESENT 正对照：按天过滤仍在（收在 _isOnDay 里）             命中 1
PRESENT 正对照：resolveTaskDate 全仓仍在用                  命中 10（证明 grep 本身有牙）
```

## 本轮我自己造成的缺陷（逐条登记，不藏）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| 首跑 `Failed to load`，报 `The getter 'hasSize'/'size' isn't defined for the type 'RenderObject'` + `'first' isn't defined` | 我在溢出测量里把 `RenderObject` 当成 `RenderBox` 用，并对 `tester.renderObject(finder)` 的返回值再取 `.first`（它本来就返回单个） | 按编译器给出的**源文件绝对路径**读真实签名后改：子节点 `is! RenderBox` 先 cast、根节点直接用。**教训仍是记忆里那条：别猜 harness API，编译器报错会印出文件路径，一条 grep 就能确认** |
| 断言 `expect(… isSelected, isFalse)` **恒红**，失败写着 `Actual: Tristate:<Tristate.isFalse>` | 本机 Flutter 3.44.8 的 `SemanticsFlags.isSelected` 是 **`Tristate`**，不是 `bool`（`isButton` 才是 bool） | 改成 `Tristate.isFalse` / `Tristate.isTrue`（配 `import 'dart:ui' show Tristate;`）。已在测试里留注释，防止下一个人再按 bool 写 |
| 探针脚本 `py_compile` 直接 `SyntaxError` | 我在描述里用 ASCII 双引号包中文短语（`"全部任务"`），把 Python 字符串截断 | **靠"先 py_compile 再 check"这两道前置挡住**（第 76 轮那次是没人挡，四条探针一次都没跑）。这次锚点干跑 10/10 命中后才进 `all` |
| PV 首跑判"归因未证实" | 我的预期用例名只写了新文件那条，漏了既有套件里真实红掉的 `日程视图按任务固定时区显示墙钟时段` | 回源码确认它钉的正是"议程档排序"这一机制（不是撞巧红）⇒ 补进预期名，单跑 PV 转 OK。**没有为了让脚本绿而放宽判据** |
| 首版「开→关→开」用例用 `find.descendant(of: byType(ListTile))` 收集行 | 时间轴的行**不是** `ListTile`（自定义 Row），那样会静默量到空集，`orderedEquals(空)` 就恒真 | 改成按固定标题清单取"当前看得见哪些"，两种档共用同一判据，不依赖行 widget 的形状 |
| 导入 `/tmp/r77/sync_gitea_r76.py` 复用它的 API helper，结果**该脚本没有 `__main__` 守卫**，import 即把第 76 轮的同步全流程重跑一遍 | 我要的是 `call()`，随手挑了个同名脚本 import | 副作用：PR !360 与 Issue #349 各多出一条**逐字重复**的留言（id 9333 / 9336），PR !360 正文被同内容重写（无差异）。已 `DELETE` 两条重复留言并读回确认（!360 回到 2 条、#349 回到 7 条，9333/9336 均不在）。**今后只 import 带守卫的 `/tmp/r74/gitea.py`**；顺带记：跑任何"看起来是库"的脚本前，先 `tail` 一眼有没有 `__main__` 守卫 |

## 遗留与下一轮

- **只读复核未派**：派单基准 `origin/develop..feat/361-calendar-list-timeline`（head `899dcf2`）。
  要它重点看的三处：① 嘀嗒口径有没有超出（我把它 `:18`"以时间为线"实现成"轴 + 时刻 + 全天栏"，
  **没做**小时刻度尺，见 FR-9 的取舍）；② 溢出判据是手工量 `RenderFlex` 子节点越界，
  它会不会因为 `ListView` 懒建而只量到首屏 ⇒ 用例里已先断"最坏内容真在树里"；
  ③ PV 那条"共用取数"的机制主张，成对 grep 是否够硬。
- **矩阵 #29**：本轮把「显示时间轴」这一格从"缺"变成"已实现待合并"，
  同时要把 develop 主表那句 **「`_ListView`：按选中日过滤 = 确实是『按天』」改判**
  （代码里 `CalendarMode.list => _ListView(tasks: _visibleTasks, …)` 从未收到 `anchor`）。
  按"未合并不得翻转状态"，状态列仍是「部分」，改动只落在说明/缺口列。
- **FL #362**（列表视图下拉展开日历全景）另起一轮，不夹带。
- 明确不做清单里那三条（长按落点建任务、全天栏拖拽改时间、隐藏时段）各自需要新交互管线或新首选项，
  要做得各开一张 Issue。
