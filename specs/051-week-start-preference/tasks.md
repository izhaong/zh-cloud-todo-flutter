# 任务清单：星期开始于（specs/051）

## 完成情况

- [x] `spec.md` 来源表：4 个锚点逐字引用（`01-欢迎/03-常见问题.md:125/:134/:143/:159`、`02-功能指南/02-日历/08-常见问题.md:145/:149/:155`）；移动端「星期开始于」/ 桌面「每周开始于」的措辞差异如实登记，本仓采移动端措辞
- [x] 红测（步骤 2）
- [x] `WeekStart` 纯函数 + 偏好仓储 + provider（步骤 3–5）
- [x] 日历/时间线 8 处周一硬编码接线（步骤 6；判据见 `spec.md` 现状表两条 `git grep`）
- [x] 设置「日期与时间」-「星期开始于」三档入口 + 四件套（步骤 7）
- [x] 六道门禁：全跑在终态 head `5fb1d30`，日志 `/tmp/r76/gates-5fb1d30.log`（读数见下表）
- [ ] 只读复核 `VERDICT`（派单前自查已完成；结论回来前不得勾）
- [x] 矩阵 #31 缺口列回写：`zh-cloud-docs` 分支 `docs/parity-replay-combined`（PR !102）提交 `be58c97`
      —— **未合并**，所以主表状态仍按 develop 判「部分」，本轮不翻转
- [ ] 第 77 轮入口：矩阵 #30 日程视图（见文末）

## 红测读数

```
$ flutter test test/core/time/week_start_test.dart test/week_start_preference_repository_test.dart
00:00 +0 -2: Some tests failed.
  Error when reading 'lib/state/repositories/week_start_preference_repository.dart': No such file or directory
```

⚠️ **这一条是编译红，不是行为红**（`loading …[E]` 且计数停在 `+0`）——两个文件引用的 API 还不存在。新章
节的第一版测试只能证明"接口没实现"，不能证明"行为错"。真正的行为约束见下面的绿测。

## 绿测与接线过程中发现的两处自身缺陷（都已真修，不记成存量欠债）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| `+19 -1`：`offsetOf 给出某天距本周起点要回退的天数` 红，报 `Expected <7> Actual <2>`（`firstDay=7 weekday=1`） | **我的断言算错了方向**：把"回退 offset 天"写成了"前进 offset 天" | 实现是对的（同组 `startOf` 的周日档用例同时是绿的）。改断言为 `((weekday - 1 - offset) % 7 + 7) % 7 + 1`，复跑转绿。先怀疑预期值，不先改实现 |
| 提交后自查发现**同一个数字在四处写错**（spec / plan / tasks / PR 描述 / Issue 评论都写「7 处，全部同型表达式」） | 数的时候把 `calendar_view.dart:333` 的 `leadingBlanks = firstOfMonth.weekday - 1`（不是 `subtract` 式）和整行 `const` 表头都算进了"同型"，又把总数少算成 7 | `git grep -nE "Duration\(days: [a-zA-Z]+\.weekday - 1\)" origin/develop -- lib` = **6**，加 `weekday - 1` 非 subtract **1** 与 const 表头 **1** ⇒ 共 **8 处**，其中只有 6 处同型。四处文档已按实测改写，判据命令本身写进 `spec.md` 现状表。**这一条是派复核之前自己量出来的**，不是复核抓的 |
| `dart analyze` 4 条 error：`Expected to find '}'` ×3 + `Undefined name 'weekStartProvider'` | 脚本给三个公开函数加命名参数时写成 `… scale, { int firstDay = …,\n) {`，漏掉收尾的 `}`；`timeline_view.dart` 本来没 import `state/providers.dart` | 三处补 `}) {`；按 `calendar_view.dart` 的既有 import 顺序补 import。**教训：脚本换函数签名时，带 `{` 的命名参数列表必须整段自己写全，不能只改参数行** |
| 门禁 5 报 `+922 ~26 **-17**`，17 条全是 `Bad state: No ProviderScope found`（另一份 spec 的 `timeline_view_*_test.dart`） | 我在 `TimelineView.build` 里加了 `ref.watch(weekStartProvider)`，而既有用例是**裸 `pumpWidget`**（不套 `ProviderScope`） | `c32804e`：改成 `TimelineView` 收 `firstDay` 构造参数（默认 `WeekStart.defaultFirstDay`），由唯一生产调用点 `tasks_by_list_page.dart:411` 取值注入。**不动别人的测试文件**；改完门禁 5 回到 `-0`。教训：给公共 widget 加 provider 依赖前，先 `git grep -l "TimelineView(" test` 数有几个裸 pump |
| 探针脚本首版 `probes.py` 第 73 行把 PH 的元组闭成 `],` ⇒ **`SyntaxError`，四条探针一次都没执行** | 我"写了探针计划"就当成了"跑过探针"；`lib_probe.txt` 0 字节可证从未运行 | 重写为 `probes76.py`，并固化两个前置：`python3 -m py_compile` + `probes76.py check`（只报锚点命中数、不写盘）；再加"起跑前 `lib/` 必须干净"的闸门。**教训：反向探针脚本自己也要被探针** |
| PH 探针在 `settings_week_start_test.dart` 侧**绿**（`+7`、后来加了 loading 用例仍 `+8` 全绿） | 不是"用例只钉行为不钉机制"——是 `settings_route.dart:29-30` 与 `:214` **各内联抄了一遍** `valueOrNull ?? WeekStart.defaultFirstDay`，绕过了 `providers.dart` 的 helper，所以摘 helper 的兜底对设置页零作用 | `5fb1d30` 两处改成调 `resolveWeekStartFirstDay`。改后同一探针让设置侧 `+0 -8` **全红**（连"整个设置页第一帧就抛"都被演了一遍）。成对判据：`git grep "weekStartProvider).valueOrNull"` = 0、`"valueOrNull ?? WeekStart.defaultFirstDay"` 全仓只剩 `providers.dart:336`、正对照 `valueOrNull` 在 `lib/` 仍几十处命中（证明判据不是恒 0） |

## 用例账

| 文件 | 条数 | 覆盖 | 实测读数（终态 head） |
| --- | --- | --- | --- |
| `test/core/time/week_start_test.dart` | 13 | `startOf` 4、`columnOrder` 4、档位与文案 3、`offsetOf` 2 | 探针对照组 `00:00 +13: All tests passed!` |
| `test/week_start_preference_repository_test.dart` | 7 | 默认/读写/单行更新/watch 推新值/拒写非三档/出箱一条/服务端包装可读/脏数据兜底（合并成 7 条 `test`） | 探针对照组 `00:00 +7: All tests passed!` |
| `test/features/task/week_start_consumers_test.dart` | 18 | 网格 4、表头字形 2、周档标签 2、`resolveWeekStartFirstDay` 三态 3、日历端到端 5、时间线端到端 2 | 探针对照组 `00:00 +18: All tests passed!` |
| `test/features/settings/settings_week_start_test.dart` | 8 | 分组与档位显示、**首值未到兜底（`52b2c6f` 新增）**、三档与勾选、即时生效、保存失败、库未就绪、字面值语义、320px+1.3 | `00:01 +8: All tests passed!`（`/tmp/r76/settings6.log`） |

> **勘误**：本表上一版把仓储文件写成 8 条、把 consumers 写成 13 条。13 是补 FR-7 三态组之前的数，
> 8 是照着"我以为写了几个"数的 ⇒ 加/删用例后不重数就会漂。现在四个数**都对应一次实际运行的 `+N` 读数**
> （门禁 5 全量为 `+944 ~26 -0`）。合计新增 **46** 条。

## 六道门禁

| # | 门禁 | 跑在哪 | 读数 |
| --- | --- | --- | --- |
| 1 | `git diff --check` | 每次提交前，工作树 | 两个后续提交各 `rc=0`（`52b2c6f`、`5fb1d30`） |
| 2 | `dart format --output=none --set-exit-if-changed <本轮显式文件>` | head `5fb1d30`，11 个显式文件 = 7 个 `lib/`（含 `tasks_by_list_page.dart`）+ 4 个测试 | `G2 rc=0`（日志 `/tmp/r76/gates-5fb1d30.log`；脚本标题那行还写着"10 个"是旧注释，实际列表 11 项）。⚠️ 首版跑在 `f59f895` 时 `9 changed` 全部来自**本轮引入**（HEAD 上这 4 个既有文件本来就 format-clean），修法是把这 9 处按 formatter 的规则改掉，**没有**全仓原地格式化 |
| 3 | `flutter analyze` | head `5fb1d30` | `No issues found!` `G3 rc=0` |
| 4 | `flutter test --tags golden` | head `5fb1d30` | `00:10 +9: All tests passed!` `G4 rc=0`；紧随其后的 `git status --porcelain -- test` **输出为空** ⇒ 9 张基线一张都没重录。**限定条件要说清**：默认档=周一 ⇒ 首屏与 develop 逐像素相同；周日/周六档下月网格本来就会变，那是新能力的正确行为，不是基线漂移 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | head `5fb1d30` | `02:48 +944 ~26: All tests passed!` `G5 rc=0`（`~26` 是仓库存量 skip，非本轮引入）。上一 head 在这里是 `+922 ~26 -17`，那 17 条见上面缺陷表第 4 行 |
| 6 | `flutter build web --release --dart-define=…` | head `5fb1d30` | `✓ Built build/web` `G6 rc=0`；收尾 `git status --porcelain` 为空 ⇒ `pubspec.lock` 没被 pub get 改脏，没混进提交 |

> 中止过一次：`gates-52b2c6f.log` 的 G5 被我杀掉（随后又改了 `lib/`），那版**不是终态**，
> 只有 G2/G3/G4 有读数；终态读数一律以 `gates-5fb1d30.log` 为准。

## 反向探针（`/tmp/r76/probes76.py`，输出 `/tmp/r76/probes3-gates.log` + `/tmp/r76/probes/*.log`）

| 编号 | 摘掉什么 | 结果 | 红在哪（归因） |
| --- | --- | --- | --- |
| PF | `WeekStart.offsetOf` 退回 `weekday - 1`（档位完全不参与） | 红 ✅ | `week_start_test` `+10 -3`：`startOf 周日档`、`startOf 周六档`、`offsetOf …永不为负`；`consumers` `+13 -5`：网格周日档/周六档、`每行的星期序列`、`周档标签随档位移动`、`时间线接线 改成周日档` |
| PG | 网格跟随档位、表头退回写死的 `一…日`（只做一半） | 红 ✅ | `档位改成周日，表头整行左移到「日」开头` + `先给周日、随后流报错：旧档位保留`（两条都靠 `_headerGlyphOrder`）⇒ 表头与网格是**两个独立判据**，漏一半会被抓到 |
| PH | `resolveWeekStartFirstDay` 改成 `requireValue`（FR-7 兜底被摘） | 红 ✅ | `consumers` `+12 -6`（含 `首值未到退回默认周一`、`报错且没有旧值`）；`settings` `+0 -8` **整页全红**（`5fb1d30` 之前这里是绿的 ⇒ 见缺陷表最后一行） |
| PI | `allowedFirstDays` 加第四档「周二」 | 红 ✅ | 三个文件各咬一条：`只有嘀嗒给的三档`、`点开后正好三档…`、`只接受嘀嗒给的三档，其余值不入库` |
| PJ | `save()` 去掉「只接受三档」守卫 | 仓储侧红 ✅ / **设置侧绿** ⚠️ | 红在 `只接受嘀嗒给的三档，其余值不入库也不改当前档`；设置侧绿是**职责边界不是缺口**：弹层选项由 `WeekStart.allowedFirstDays` 生成，UI 按构造产不出非法值，能进来的只有编程式/服务端脏值 ⇒ 该守卫的唯一判据归仓储用例。这一条如实记下，不写成"已覆盖" |

> 每条探针都带**对照组**（未打补丁先跑一次，必须绿）与 `cmp -s` 逐字节还原校验；
> 脚本收尾再查一次 `git status --porcelain -- lib` ⇒ 本次输出「干净（与 HEAD 一致）」。
> 加/删用例之后探针**全部重跑**（本文件上面的数字来自 `5fb1d30` 这次重跑，不沿用 `c32804e` 那次）。

## 已登记的残留（不当成已解决）

- **四件套 ④ 的写入并发**：`save` 落的是"点中的字面值"，所以不存在取反/盖回；但两次点选的写入若在 SQLite 事务层面重叠，仍可能是先点的后落地。本轮**没有**加写队列（那要为一条从未观察到的小窗口引入新机制），已按现状把测试钉成"重复点同一档不变 + 顺序点选停在最后一次"。若复核认为该窗口不可接受，再加序列化。
- **习惯「本周完成」仍是服务端周界**（`/app-api/todo/habit/stats` 的 `weeklyDone`），不随本偏好变，见 `spec.md`「明确不做」。

## 矩阵

`#31 日历显示设置` 的缺口列要补上「星期开始于」，并且它原本的 `firstDayOfWeek` 0 命中判据在合并后不再是 0（本 PR 引入了 `WeekStart`，但**不引入** `firstDayOfWeek` 这个词）——复跑口径要在回写时重测一遍再写，别提前抄。

实测（head `5fb1d30`，成对判据）：`git grep -n "firstDayOfWeek" -- lib` = **0**（这一项判据本身仍然成立，
本轮没有偷塞服务端同名字段）；正向对照 `git grep -l "WeekStart" -- lib` = **7 个文件**命中（证明 grep 有牙）。
主表 #31 状态**不翻转**：`!360` 未合并 ⇒ 按 develop 仍是「部分」；已回写的只有缺口列文字（docs `be58c97`）。

## 第 77 轮入口（已定位，未开工）

矩阵 **#30 日程视图**（当前「部分 / FL / M6」）。嘀嗒原文《02-功能指南/02-日历/05-日程视图：以时间串联任务.md》
只有两条主张：① 桌面端"所有安排好时间的任务会显示在一个**时间轴**中"；② "可以同时看到**过去已完成**的任务、
当前的进度和**未来的计划**"；入口小节《如何开启日程视图？》= 日历右上角切换视图选「日程视图」。
本仓缺口逐字可复现：`calendar_view.dart:904-910` 的 `_AgendaView` 只按 `anchor` **单日**过滤
（year/month/day 三重相等），既不是跨日时间轴，也不呈现"过去已完成 + 未来计划"同屏。
落点已在 develop 存在，不需要新路由、不需要 BE 契约、不动 9 张黄金基线（黄金集是否覆盖日程视图
这一条**尚未取证** —— 上一轮我用 `grep agenda test/visual` 得 0 命中，但缺正向对照，
下轮要先按"图里到底有没有日程态"重判，不能拿这个 0 命中当免检依据）。
候选替代：#28 年视图缺"按日热力图"、#8 任务详情缺"复制链接"（单面，不足以翻行）、#50 倒数纪念日缺
"四类自动分组/置顶/归档"（归档卡在未合并的 service `!276`）。
