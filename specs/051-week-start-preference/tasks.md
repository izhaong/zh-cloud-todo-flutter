# 任务清单：星期开始于（specs/051）

## 完成情况

- [x] `spec.md` 来源表：4 个锚点逐字引用（`01-欢迎/03-常见问题.md:125/:134/:143/:159`、`02-功能指南/02-日历/08-常见问题.md:145/:149/:155`）；移动端「星期开始于」/ 桌面「每周开始于」的措辞差异如实登记，本仓采移动端措辞
- [x] 红测（步骤 2）
- [x] `WeekStart` 纯函数 + 偏好仓储 + provider（步骤 3–5）
- [x] 日历/时间线 8 处周一硬编码接线（步骤 6；判据见 `spec.md` 现状表两条 `git grep`）
- [x] 设置「日期与时间」-「星期开始于」三档入口 + 四件套（步骤 7）
- [x] 六道门禁：跑在**复核修复后**的终态 head `1f50929`（前一次终态读数在 `5fb1d30`，见下表脚注）
- [ ] 只读复核：第 1 轮 `VERDICT: FAIL`（3 条测试判据问题，全部采纳并已修，见「复核第 1 轮」表）⇒ **第 2 轮待回**，回来前不得勾
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

## 复核第 1 轮（`VERDICT: FAIL`）→ 逐条回源复验 → 三条全部采纳

只读复核员审七项，行为侧（数学、8 处接线、消副本、探针复跑、六道门禁读数）它自己跑命令后认了；
FAIL 全落在**测试判据**上。三条我逐条回源码复验，都成立，没有一条需要驳回：

| # | 复核的发现 | 我的复验 | 处置 |
| --- | --- | --- | --- |
| 4(a) | 「保存失败不改档位」是**恒真断言**：`_ThrowingRepository` 覆盖 `save` 后在 `super.save` 之前就抛，仓储从未写库，所以 `expect(await repository.get(), DateTime.monday)` 结构上不可能红 | 属实。我原来的前提（"它走真 DB"）说错了一半——`get()` 确实走真 in-memory DB，但 `save` 从没执行到写库那一行 | 采纳（`1f50929`）：改成**真仓储 + 坏写队列**（`_ThrowingQueue extends SyncChangeQueue` 只让 `enqueue` 抛）。写偏好行与入队仍在同一 `_db.transaction` 内 ⇒ 现在绿；谁把写库挪出事务 ⇒ 当场红。FR-9 从此有可红判据 |
| 4(d) | `有值用值`（`data(7)` ⇒ 7）从来没被任何探针证伪：PH 摘的是兜底，`requireValue` 在有值时照样返回 7 | 属实。翻 `probes3-gates.log` 的 PH 段，6 条红里确实没有它 | 采纳：新增探针 **PK**（`resolveWeekStartFirstDay` 恒回默认档）。PK 实测红 4 条，其中正是 `resolveWeekStartFirstDay（FR-7 三态） 有值用值` |
| 7 | 生产注入线 `tasks_by_list_page.dart:411` 零覆盖：`TimelineView` 的 `firstDay` 有默认值，忘注入会静默退回周一 | 属实。它 `git grep weekStart -- test` 在本轮 4 个新文件外 0 命中，我这边也确认没有任何用例从页面进 | 采纳：新增两条走 `TasksByListPage` 的用例 + 探针 **PL**（删掉调用点那句实参）。PL 实测**只**红 `周日档：同一入口把周窗口挪成 9/20–9/26` 一条 ⇒ 归因精确 |

复核另外两点**不要求改代码、但要求把话说清**，已并入下面两张表：

- 我主张"门禁 2 首跑 `9 changed`"的那次读数**在 `/tmp/r76` 里已经找不到了**（同名日志被后来的运行覆盖）。
  推理方法它认（`git show HEAD:<file>` 干净 ⇒ 脏来自本轮），但**证据链断了** ⇒ 下表按"无可引用日志"记，不当已证。
- 门禁 4 的 `+9` **不能当"月网格逐像素相同"的证据**：9 张基线全在 `test/visual/todo_workspace_golden_test.dart`，
  它 pump 的是 `HomeShell` 列表态，全文不含 `CalendarView`。这条限定已写进下表第 4 行。

它也给了一条我自己没想到的正面结论：`(c)` 时间线那两条"段标题在/不在"的用例，
若把 `timeline_view.dart:121` 的空段守卫删掉会**变红**（不是恒过），失败方向是吵不是静。

## 用例账

| 文件 | 条数 | 覆盖 | 实测读数（终态 head） |
| --- | --- | --- | --- |
| `test/core/time/week_start_test.dart` | 13 | `startOf` 4、`columnOrder` 4、档位与文案 3、`offsetOf` 2 | 探针对照组 `00:00 +13: All tests passed!` |
| `test/week_start_preference_repository_test.dart` | 7 | 默认/读写/单行更新/watch 推新值/拒写非三档/出箱一条/服务端包装可读/脏数据兜底（合并成 7 条 `test`） | 探针对照组 `00:00 +7: All tests passed!` |
| `test/features/task/week_start_consumers_test.dart` | 20 | 网格 4、表头字形 2、周档标签 2、`resolveWeekStartFirstDay` 三态 3、日历端到端 5、时间线端到端 2、**生产接线（走 `TasksByListPage`）2** | 探针对照组 `00:01 +20: All tests passed!` |
| `test/features/settings/settings_week_start_test.dart` | 8 | 分组与档位显示、**首值未到兜底（`52b2c6f` 新增）**、三档与勾选、即时生效、保存失败（`1f50929` 换成真仓储 + 坏队列）、库未就绪、字面值语义、320px+1.3 | `00:01 +8: All tests passed!`（`/tmp/r76/settings7.log`） |

> **勘误两次**：本表上一版把仓储文件写成 8 条、把 consumers 写成 13 条 —— 13 是补 FR-7 三态组之前的数，
> 8 是照着"我以为写了几个"数的。加/删用例后不重数就会漂，而这类错**不会让测试变红**，只会让证据与状态脱节。
> 现在四个数（13 / 7 / 20 / 8 = **48**）每个都对应一次实际运行的 `+N` 读数，
> 全量门禁 5 的 `+946` 也与上一 head 的 `+944` 相差 2（正是本轮新增的两条生产接线用例）。

## 六道门禁（终态 head `1f50929`，日志 `/tmp/r76/gates-1f50929.log`）

| # | 门禁 | 跑在哪 | 读数 |
| --- | --- | --- | --- |
| 1 | `git diff --check` | 每次提交前 | 本轮五个后续提交（`52b2c6f` `5fb1d30` `0f6bd64` `859963d` `1f50929`）各 `rc=0`；终态工作树 `dirty=0` |
| 2 | `dart format --output=none --set-exit-if-changed <11 个显式文件>` | head `1f50929`；11 = 7 个 `lib/`（含 `tasks_by_list_page.dart`）+ 4 个测试 | `Formatted 11 files (0 changed)`、`G2 rc=0`。脚本标题那行写着「10 个」是旧注释，实列表 11 项 |
| 3 | `flutter analyze` | head `1f50929` | `No issues found!`、`G3 rc=0` |
| 4 | `flutter test --tags golden` | head `1f50929` | `00:09 +9: All tests passed!`、`G4 rc=0`，且紧随的 `git status --porcelain -- test` **输出为空** ⇒ 9 张基线一张没重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | head `1f50929` | `02:49 +946 ~26: All tests passed!`、`G5 rc=0`（`~26` 是仓库存量 skip，非本轮引入） |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | head `1f50929` | `✓ Built build/web`、`G6 rc=0` |

两处必须说清的限定，都是第 1 轮复核逼出来的（不写就等于把证据说过头）：

- **门禁 4 不能当「月网格逐像素相同」的证据。** 9 张基线全在 `test/visual/todo_workspace_golden_test.dart`，
  它 pump 的是 `HomeShell` 列表态，全文不含 `CalendarView` 与 `TaskViewMode` ⇒ G4 只证明「列表态没动」。
  「默认档=周一时月网格与 develop 等价」是靠两条**等价用例**承担的：
  `week_start_test` 的「周一档就是 develop 现在的表头顺序 一…日」+
  `week_start_consumers_test` 的「默认档与 develop 一致：6 月 1 日就是左上角第一格」。
  周日/周六档下网格本来就会变 —— 那是新能力的正确行为，不是基线漂移。
- **门禁 2 首跑那句 `9 changed` 的原始日志已经不在了**（被后续运行覆盖，复核员也无法在 `/tmp/r76` 里找到）。
  推理方法它认（`git show HEAD:<file>` 版那 4 个既有文件 format-clean ⇒ 脏必然来自本轮 diff），
  但**证据链断了** ⇒ 这句降级为「方法成立、读数丢失」，不当已证。

> 三份日志的分工：`gates-1f50929.log` = **终态**（首行 `head=1f50929 dirty_files=0`，末行收尾 `dirty=0`）。
> `gates-5fb1d30.log` = 上一个 head 的同构读数（G4 `00:10 +9`、G5 `+944 ~26`）——留着是为了能复算
> 「用例集变化会不会推动计数」：`+944 → +946` 正好等于本轮新增的两条生产接线用例。
> `gates-52b2c6f.log` 是我**中途中止**的一次（只有 G2/G3/G4 有读数），不作证据。

## 反向探针（`/tmp/r76/probes76.py`，终态输出 `/tmp/r76/probes4-gates.log` + `/tmp/r76/probes/*.log`）

| 编号 | 摘掉什么 | 结果 | 红在哪（归因） |
| --- | --- | --- | --- |
| PF | `WeekStart.offsetOf` 退回 `weekday - 1`（档位完全不参与） | 红 ✅ | `week_start_test` `+10 -3`（`startOf 周日档`、`startOf 周六档`、`offsetOf …永不为负`）；`consumers` `+13 -5`（网格周日/周六档、`每行的星期序列`、`周档标签随档位移动`、`时间线接线 改成周日档`） |
| PG | 网格跟随档位、表头退回写死的 `一…日`（只做一半） | 红 ✅ | `档位改成周日，表头整行左移到「日」开头` + `先给周日、随后流报错：旧档位保留` ⇒ 表头与网格是**两个独立判据**，漏一半会被抓到 |
| PH | `resolveWeekStartFirstDay` 改成 `requireValue`（FR-7 兜底被摘） | 红 ✅ | `consumers` `+12 -6`；`settings` `+0 -8` **整页全红**（`5fb1d30` 之前这里是绿的 ⇒ 见缺陷表最后一行） |
| PI | `allowedFirstDays` 加第四档「周二」 | 红 ✅ | 三个文件各咬一条：`只有嘀嗒给的三档`、`点开后正好三档…`、`只接受嘀嗒给的三档，其余值不入库` |
| PK | `resolveWeekStartFirstDay` 无视传入值、恒回默认档 | 红 ✅ | `+16 -4`，其中正是 `resolveWeekStartFirstDay（FR-7 三态） 有值用值`（复核 4(d) 指出这条**从未被证伪**，PK 就是为它加的） |
| PL | 生产调用点不再把档位喂给 `TimelineView`（退成构造默认值） | 红 ✅ | `+19 -1`，**只**红 `生产接线（tasks_by_list_page.dart 的注入线） 周日档：同一入口把周窗口挪成 9/20–9/26` ⇒ 归因精确到那一条 |
| PJ | `save()` 去掉「只接受三档」守卫 | 仓储侧红 ✅ / **设置侧绿** ⚠️ | 红在 `只接受嘀嗒给的三档，其余值不入库也不改当前档`；设置侧绿是**职责边界不是缺口**：弹层选项由 `WeekStart.allowedFirstDays` 生成，UI 按构造产不出非法值，能进来的只有编程式/服务端脏值 ⇒ 该守卫的判据只归仓储用例。如实记下，不写成「已覆盖」 |

> 脚本纪律：起跑前 `py_compile` + `probes76.py check`（只报锚点命中数，5 个锚点各命中 1 才放行）；
> `lib/` 不干净就拒绝打补丁；每条先跑**对照组**（未打补丁必须绿，否则结论无效）；
> 打补丁后按 ` [E]` 行归因，红必须落在预期用例名上才算数；收尾 `cmp -s` 判逐字节一致 +
> 再查一次 `git status --porcelain -- lib` ⇒ 本次输出「干净（与 HEAD 一致）」。
> **加/删用例之后全部重跑**：上面的数来自 `1f50929`，不沿用 `5fb1d30` 那次。
> 首版脚本把 PH 的元组闭成 `],` ⇒ `SyntaxError`、四条探针一次都没跑过（缺陷表倒数第 3 行）。

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
落点已在 develop 存在，不需要新路由、不需要 BE 契约、不动 9 张黄金基线。
"黄金集不覆盖日程视图"这一条**已取证（成对判据）**：唯一带 `@Tags('golden')` 的文件是
`test/visual/todo_workspace_golden_test.dart`，其中 `CalendarView` 命中 **0**；
正向对照 `git grep -l "CalendarView" -- test` = 3 个文件（`calendar_display_settings_test.dart`、
`week_start_consumers_test.dart`、`m11_b3_calendar_test.dart`）⇒ 0 命中不是抓取失效。
候选替代：#28 年视图缺"按日热力图"、#8 任务详情缺"复制链接"（单面，不足以翻行）、#50 倒数纪念日缺
"四类自动分组/置顶/归档"（归档卡在未合并的 service `!276`）。
