# 任务台账：specs/055「设置 → 日期与时间 → 时区」总开关（FL Issue #368）

基准：`zh-cloud-todo-flutter origin/develop@9032005`（分支 `feat/368-timezone-switch`）。
勾选规则：只有**实际跑过且读数对上**的才勾；没判据的写「无判据 + 为什么」。

## 一、实现

- [x] `lib/state/repositories/timezone_preference_repository.dart`（新增，`DATE_TIME`/`timezone` 一行 + `view_preference` 入队）
- [x] `lib/state/providers.dart`：`timezonePreferenceRepositoryProvider`、`timezoneEnabledProvider`
- [x] `lib/features/settings/settings_route.dart`：`_Section('日期与时间')` + `_TimezonePreferenceTile`
- [x] `lib/features/task/task_detail_pane.dart`：提醒编辑器「固定时区」按偏好显隐（`_showReminderEditor` 补 `WidgetRef` 形参）

## 二、按 FR 的判据台账

| 条目 | 判据 | 实跑读数 |
| --- | --- | --- |
| FR-1 有「日期与时间 → 时区」开关 | W1 `find.text('日期与时间')` + `ValueKey('settings-timezone-enabled')` 内的 `Switch` | `+9`（两份测试合计，见「四」） |
| FR-2 关掉 ⇒ 「固定时区」不出现、IANA 输入框仍在 | `test/features/task/reminder_timezone_gate_test.dart` 两条（开/关各一条，成对） | 同上；**这条先红过一次**（见「三-1」） |
| FR-3 开关不改写任务数据 | R2：切三次后逐字段比对 `timeZone` / `fixedTimezone` | 同上 |
| FR-4 持久化 + 同步 | R1：`get()` 默认开、`todo_view_preferences` 恰 1 行、`todo_sync_changes` 恰 1 条 `entity=viewPreference`、再开仍是 1 行 | 同上 |
| FR-5 展示层不受影响 | **无行为测试**，用两条静态判据：`git grep -n "timezoneEnabledProvider" -- lib` ⇒ 3 命中（定义 + 设置页 + 提醒编辑器），`lib/core/time` 内 0 命中；`git status --porcelain lib/core/time \| wc -l` = 0，`task_time_formatter.dart:167` 的「`<IANA> 固定时区`」原样 | 命令已跑（本次会话内），读数如左 |
| FR-6 「固定时间」档 | **本面不做**，另立 FL #369（前置是 service 的逐任务三态模式位） | — |

四件套：

| 件 | 判据 | 状态 |
| --- | --- | --- |
| 1 320px + 1.3 倍字号（本路由自己的 context） | W3：视口宽 320、`TextScaler.linear(1.3)`，先确认 `Switch` 真被渲染，再 `expect(tester.takeException(), isNull)` | 有判据、绿 |
| 2 独立读屏语义 | W2：合并节点 label 含「时区」+「已开启」，切换后含「已关闭」；另判 `onChanged != null` | 有判据、绿（**判据形态是被红测逼出来的**，见「三-2」） |
| 3 失败保留已加载数据 | W4（仓储为 null ⇒ 「时区设置暂不可用」）+ W5（写抛错 ⇒ 「时区设置未保存」且开关与内存态都停在原值） | 有判据、绿 |
| 4 过期响应不覆盖新响应 | **无判据**：本面 UI 没有"异步读回来覆盖"的路径 —— 写只走 `setEnabled`，读只走 drift 的 `watch()`（同一行的流按写入顺序出事件），不存在两个并发读互相覆盖。取证的命令是 `grep -n "await" lib/features/settings/settings_route.dart`（4 命中，全部在 `_save` 内且都写后不回填）。**登记为取舍**，不删判据 | 已登记 |

## 三、红测记录（真红过两次，各修一处）

1. **FR-2 红在实现**（`flutter test test/features/task/reminder_timezone_gate_test.dart` → `+1 -1`，
   红在第 45 行）：`findsNothing` 实得 1 个 `SwitchListTile-[<'task-reminder-fixed-timezone'>]`。
   根因：实现写的是 `ref.read(timezoneEnabledProvider).valueOrNull ?? true` —— `StreamProvider` 首帧是
   `AsyncLoading`，`valueOrNull` 为 null ⇒ 恒退成「开」，"关没关掉"取决于用户在流首帧到达前点了多久。
   修法：`await ref.read(timezoneEnabledProvider.future)`（取"打开这一刻"的持久值），并在 await 之后补 `context.mounted` 才 `showDialog`。
2. **四件套-2 红在判据的假设**（`+3 -1`，红在 `Expected: CheckedState.isTrue / Actual: CheckedState.none`）。
   临时探针（跑完即删，未入库）实测：`SwitchListTile` 挂 key 的节点与其内部 `Switch` 解析到**同一个**
   `SemanticsNode`，该合并节点 `isChecked=none`、`isToggled=none`、`isButton=false`、`isEnabled=true`、
   label=「时区\n开启后可为任务选择「固定时区」」⇒ `Switch` 自带的状态位到不了读屏（merge 只合并 label）。
   修法：状态写进 `title` 的 `semanticsLabel`（「时区，已开启 / 已关闭」），判据落在 label 的正反两条上。

## 四、六道门禁

基准：已提交终态 **`b571ef1`**（`ac51c0b` 是功能那一笔，`b571ef1` 只把门禁 2 判红的三处换行收齐）；
日志 **`/tmp/r82/gates-b571ef1.log`**（1397 行；文件名带 sha ⇒ 不会被下一轮覆写）。六项 **rc 全 0**。

| 门禁 | 读数（从上面那份日志现读，行号是日志内的） |
| --- | --- |
| 1 `git diff --check 9032005..HEAD` | 无输出，`rc=0`（`:4`） |
| 2 `dart format --output=none --set-exit-if-changed`（本轮 6 个文件） | `Formatted 6 files (0 changed)`，`rc=0`（`:7`、`:8`） |
| 3 `flutter analyze` | `rc=0`（`:74`） |
| 4 `flutter test --tags golden` | `00:09 +9: All tests passed!`（`:148`）⇒ **9 张基线一张没重录**，设置页新增一节没进任何一张的视口 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:27 +907 ~26: All tests passed!`（`:1314`） |
| 6 `flutter build web --release`（带 test 域名与租户两个 dart-define） | `✓ Built build/web`（`:1393`），`rc=0` |

计数对账（不是减法反推，两端各有实跑来源）：`907 − 本轮新增 9 = 898` = develop 全量基线，
那份基线的实跑留痕是 `/tmp/r68/baseline_develop.log:1152`（`+898 ~26`，全文 1153 行、`:1153` 才是物理末行）
与 `/tmp/r77c/rerun-898.log:1155`；`~26` 与 develop 的 26 条 skip 一致（本轮没新增 skip）。
复算命令：`grep -n "All tests passed" /tmp/r82/gates-b571ef1.log`、
`git log --oneline 9032005..HEAD | wc -l` = 2。

⚠️ 门禁 2 **第一次是红的**：`ac51c0b` 上 `Formatted 6 files (3 changed)` ⇒ `rc=1`
（第一份日志 `/tmp/r82/gates-ac51c0b.log`，读数留在 `:6-11`，没被覆写）。
处理方式是把三个文件按 formatter 收齐再重跑全套 —— 没有改判据、没有跳过。

跑完门禁后 `git status --porcelain pubspec.lock` 为空（同日志收尾行 `脏项数=0`）⇒
`pubspec.lock` 没被本机镜像扫进这笔。


## 五、编译红（不充当行为证据，只留名字）

- `TextFormField` 没有公开的 `decoration` getter ⇒ 改判渲染出来的 label 文本。
- `dart:ui` 的 `SemanticsFlags` 上没有 `isToggle` / `hasCheckedState`（真名 `isToggled` / `isChecked`），
  `SemanticsNode` 没有 `.node`（是 `.id`）；`CheckedState` 需要 `import 'dart:ui' show CheckedState`。
- `import 'package:drift/drift.dart'` 与 matcher 的 `isNull` / `isNotNull` 撞名 ⇒ `hide isNull, isNotNull`
  （但 `&` 组合条件要整个 drift 导入，不能 `show Value`）。

## 六、踩到并已绕开的测量坑

- `ListView(children: …)` 只构建进视口的行：320×700 下「日期与时间」整节没被构建 ⇒ `find.text` 0 命中，
  看着像"控件没做"其实是"没滚到"。修法：视口高度给到 2400（`_pumpSettings` 里注明了原因）。
- UI 测试**不接** in-memory Drift 的读流：接了收尾必炸 `A Timer is still pending…`；
  改成"收尾 settle 再关库"反而拖到 10 分钟超时。持久化的真库判据留在 R1/R2，UI 侧用 `implements`
  的假仓储（`timezoneEnabledProvider` 仍走真实实现去 `watch()` 它，所以接线本身还是被测的）。
  仓内既有先例是 `TodoVisualFixture` 用 `closeStreamsSynchronously: true` —— 提醒编辑器那两条就是走这条路。

## 七、遗留与下轮入口

- 矩阵 #12 只去掉缺项 ⑥（总开关），仍留 ⑤（「固定时间」档）⇒ **状态不翻**，缺口列改窄并指向 FL #369。
- PR 未合并前，矩阵措辞用「已实现、未进 develop」。
- FL #369 的第一道门是 service 契约（逐任务三态模式位），按「后端缺契约先修契约」排在下一面。
