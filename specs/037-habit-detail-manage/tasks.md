# 037 任务清单

关联：Gitea `izhaong/zh-cloud-todo-flutter#290`；契约侧未合并依赖 `izhaong/zh-cloud-service!276`（归档，本单不接）；契约缺口 `izhaong/zh-cloud-service#277`（NOT_NULL 更新策略 / 删除不级联打卡 / 逻辑删除）。

## 第 1 轮

- [x] T-001 详情页可达：点击习惯卡片 → `HabitDetailPage`（FR-1；探针 PA 摘掉 `_HabitTile.onTap` → 11 条红）
- [x] T-002 「...」恰含「编辑」「删除」，且**不含**「归档」（FR-2；探针 PB 删「编辑」项 → 8 条红；「不含归档」是刻意的反向断言，归档端点只在未合并的 !276 里）
- [x] T-003 `HabitRepository.update` → `PUT /habit/update`，body 含 `id` + 六个可编辑字段 + 原 `sortOrder`（FR-3；探针 PC 把 `id` 改名 `idx` → 红；PN 抽掉 `icon` → 红）
- [x] T-004 未改动的提示原样回传，不发 `null`（FR-3 边界②；探针 PE 把 `reminderAt` 恒置 null → 红）
- [x] T-005 `HabitRepository.delete` → `DELETE /habit/delete?id=`；取消确认不发任何写请求（FR-4；探针 PF 摘掉 delete 调用 → 红；PG 摘掉 `!confirmed` 早退 → 红）
- [x] T-006 失败保留已加载数据 + 提示落在弹层内联可见（探针 PH 摘掉 `_submitError` 赋值 → 红）
- [x] T-007 新建与编辑共用同一张表单，`create` 带齐 7 个字段（FR-5；新增用例 + PN 红；复核 NIT8 的「FR-5 零用例」已补）
- [x] T-008 时间字段按 epoch 毫秒上送（FR-6；探针 PJ 让 `checkedAt` 退回 ISO → 红）
- [x] T-009 四件套：320px + 1.3 档位在**四个**新表面（详情页 / 编辑弹层 / 「...」菜单路由 / 删除确认框）各用自己的 context 复检；「...」与色块有独立读屏语义；校验错误落在字段上（探针 PM 摘掉 `errorText: _nameError` → 红）
- [ ] T-010 六项门禁日志齐全（见下）
- [x] T-011 矩阵 #43–46 补 `文件:行号` 证据；PR 未合并前不翻「有」（`zh-cloud-docs!72`，落点 `todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 第 95-98 行，基准 SHA 见文末对账）
- [x] T-012 契约缺口按规则 5 另开 Service 单：`zh-cloud-service#277`

## 反向探针的两个「绿」，以及它们真正说明什么

`保存在飞期间重复点保存 ⇒ 只发一次 PUT` 这条用例，**摘掉任一侧都仍然全绿**：

| 探针 | 摘掉什么 | 结果 |
| --- | --- | --- |
| PI | 只摘按钮的 `loading: _saving` | 绿 |
| PK | 只摘 `if (_saving) return;` | 绿 |
| PL | 两处**同时**摘 | **红** |

⇒ 这条用例覆盖的是**这一对守卫的协同**，不是其中某一行。两侧职责不同：`loading` 管可感知（按钮点不动 + 转圈），早退守卫管正确性（键盘 Enter、重建后的残留回调这类不经过指针的触发）。**保留两处**，并按上面的粒度记录，不写成「两行各有独立用例」。

`maxLength: 64`（对齐 `AppTodoHabitBaseVO:15` 的 `@Size(max = 64)`）**没有反向探针覆盖**——现有 17 条用例里没有「输入 65 字」这条。它是一行纯声明式护栏，本轮如实标注为「未钉住」，不宣称有测试证明。

「...」菜单路由与确认框的 320px 档位自检同样**没有反向探针**：档位继承自框架，没有一段生产代码可以摘掉来让它变红。这条只能算「跑了没溢出」，不算机制被钉住。

## 复核（第 1 轮）

复核手段替换：`claude` CLI 本机不可用（`unrecognized_model`）⇒ 用本会话**只读子代理**审本单 FR，被明确要求不得 Edit/Write。结果 **`VERDICT: FAIL`**，3 BLOCKERS + 16 NITS。逐条处置：

### BLOCKERS（全部已修，并独立复验过事实）

| # | 结论 | 处置 |
| --- | --- | --- |
| B-1 | 非 golden 套件实际是红的：`efficiency_api_contract_test.dart:349` 仍钉 `create` 的 3 键 body，而 FR-5 把它变成 7 键 ⇒「六项门禁齐全」当时是假的 | 接受。已改为钉 7 键。**我先前跑门禁用的是 `tail`，只看到 `Some tests failed` 前几行就以为只有习惯文件的问题**——复核员给了计数才逼出这条。本地独立复现：`+722 ~26 -1`，红的那条正是它。 |
| B-2 | 详情页的统计卡看的是 `habitStatsProvider` = `overviewStats()`（跨**所有**习惯的 max/sum），却标着「连续打卡 / 本周完成 / 总打卡」放在单个习惯里；`_HabitStats.habitId` 在 `build` 里一次都没读 | 接受。整块 `_HabitStats` 删除。这是「给错数」不是风格问题，而且不在任何 FR 里。 |
| B-3 | 删除确认文案「所有打卡记录也会被清空」后端不兑现：`TodoHabitServiceImpl:70-74` 只有 `deleteById`，`TodoHabitCheckInMapper` 无按 `habitId` 删除的方法；`deleted` 还是 `@TableLogic` 逻辑删除 | 接受，但**不改文案**（FR-4 要求逐字对齐嘀嗒 :122）。按规则 5 开 `zh-cloud-service#277`，并在 spec 边界表写明「本条结掉前该承诺对外不成立」。 |

### NITs：接受并已改

1 → 手写 `AlertDialog` 改走仓里统一的 `AppDialog.confirm(danger: true)`（原来删除按钮是 accent 色不是 destructive 色）。
2 → 「目标次数」改「目标」（spec.md:16 自禁同义词，词是从 VO 的 `@Schema` 抄来的，不是从嘀嗒来的）。
3 → 名称补 `maxLength: 64`（`AppTodoHabitBaseVO:15` 的 `@Size(max = 64)`）。
4 → 「每天8 次」补空格，与列表页一致。
5 → 详情页那个不在任何 FR 里的「打卡」按钮整块删除（无 try/catch ⇒ 失败是未处理异常；无在飞守卫 ⇒ 会连发；而 `checkIn` 的去重是按 `checkedAt` 精确等值，两次毫秒不同就真的多一条）。列表行仍可打卡。
6 → 保存按钮改 `AppButton(loading:)`，与 NIT-B2 的守卫结论一致。
7 → 补「...」菜单路由 + 删除确认框的 320px + 1.3 自检。
8 → 补 FR-5 用例（新建走同一张表单 + 7 键 body）。
9 → 删调 `checkIn` 里没人调用的 `note` 形参。
10 → 校验错误改落 `errorText` 在字段上（本仓 `ux-preferences.mdc:50` 明写「优先在字段附近」）。
11 → spec 的「8 条路由」改为实测的 7 条（`grep -cE "@(Get\|Post\|Put\|Delete)Mapping"` = 7）。
12 → plan.md 里 `reminderAt` 仍写 ISO 形状、PK 探针描述与实现不符 ⇒ 重写探针表为 PA–PN 的实际结果。
13 → `await` 之后用 `ref` 前补 `context.mounted`（列表页 + 详情页两处）。
15 → FR-6 补「同族仍有 21 处 `toIso8601String`，未逐处判定，另开单」，不把习惯当孤例。
16 → 矩阵回填落点写进 T-011（`zh-cloud-docs` 的 `dida-parity-matrix.md` 第 95-96 行）。

### NITs：不采纳（附理由）

- **NIT 14（`_HabitHeader` 与列表头像行重复）不改**：两处只有半径不同，抽公共组件属未被要求的重构，且会牵动已验收的 `HabitPage` 布局。
- **不删 `?? initial` 回退**（复核员自己也归入 REJECTED）：`myHabitsProvider` 处于 loading/error 时详情页仍可显示与操作，这正是四件套「失败保留已加载数据」。
- **「保存失败：$error」把 DioException 整个插进文案不改**：`note_page.dart:68`、`task_comments_page.dart:136`、`calendar_subscription_page.dart:88` 全仓既有风格，要收就全仓一次收，不在本轮单点改。
- **`targetPerWeek` 兜底（`habit_repository.dart:39`）不删**：本轮之前就有的遗留兼容，按「发现无关死代码只提醒不删」处理，已在此留痕。
- **提示列的「绝对时点 vs 每日重复」不改 UI**：属契约语义缺口，已补进 spec 边界①-b，需要 Service 侧先动。

### 复核员替我挡住的两个陷阱（记录以免下次重犯）

1. `PopupMenuItem` 的语义断言原本是空转——SDK 的 `Tooltip` 给的是 `Semantics(tooltip:)` 而非 `label:`，`find.bySemanticsLabel('更多操作')` 恒 0 命中；实现里那句显式 `Semantics(label:)` 是**必需**的，不是重复语义（我一度想删掉它）。
2. `?? initial` 方向相反的那个风险才是要害：`invalidate` 之后 `AsyncValue.valueOrNull` 会 `copyWithPrevious` 继续给**旧列表**，所以「保存成功 → 重拉」这个往返里标题短暂回旧值，此时再点编辑会用旧值预填，直接保存就覆盖掉刚做的修改（lost update）。窗口约一次 `/habit/page` 往返（100–300ms），人手赶不上 ⇒ 记为**已知限制**，不在本轮修；根治方向是保存成功后本地合并，而不是只 `invalidate`。

## 门禁原文记录（最终状态一次跑完，日志 `/tmp/r21-gates-final.log`）

```
$ git diff --check
exit=0

$ dart format --output=none --set-exit-if-changed <本轮 6 个显式文件>
Formatted 6 files (0 changed) in 0.03 seconds.
exit=0

$ flutter analyze
Analyzing zh-cloud-todo-flutter...
No issues found! (ran in 1.6s)

$ flutter test --tags golden
00:03 +9: All tests passed!                      # 9 张基线未变，未重录

$ flutter test --exclude-tags 'golden || performance' --concurrency=1
01:53 +726 ~26: All tests passed!                # 726 passed / 26 skipped / 0 failed

$ flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1
Compiling lib/main.dart for the Web...    19.8s
✓ Built build/web
```

格式门禁**先红后绿**：第一次跑 `dart format` 报了 4 个文件 `Changed`（`habit_page` / `habit_detail_page` / `habit_editor` / `habit_detail_page_test`），
`exit=1`。为排除"存量欠债"，把 HEAD 版单独抽出来量同一判据：`/tmp/hp_head.dart`、`/tmp/hr_head.dart` 都 `0 changed / exit=0`
⇒ 这 4 处红是我本轮引入的，就地只格式化这 4 个文件（不整仓原地格式化），红日志留存。

- [x] T-010 六项门禁日志齐全（见上）

测试计数对账（已定死，不靠推测）：在干净 worktree `/tmp/zh-tf-develop`（HEAD = `a1d7733`）实跑同一判据 ⇒
`flutter test --exclude-tags 'golden || performance' --concurrency=1` → **`+709 ~26: All tests passed!`**
分支 726 = 709 + 本文件 17 条新用例，**逐条对上，没有凭空消失的用例**。
⇒ 目标里记的「基线 713 passed / 26 skipped」**多算了 4 条**，后续轮次按 709 起算（日志 `/tmp/r21-baseline-develop.log`）。


## T-011 矩阵回写对账（`zh-cloud-docs!72`，基准 SHA 已逐个 `sed -n 'Np'` 打印核对）

| 矩阵行 | 已合并证据（`develop@a1d7733`） | 待合并（`feat/290@a815c9a` = 本 PR !291） |
| ------ | ------------------------------ | ---------------------------------------- |
| #43    | `habit_page.dart:199` 行内打卡、`habit_repository.dart:44` 列表 / `:72` check-in | — |
| #44    | `habit_page.dart:88,103`、`habit_repository.dart:59`（仅「填名称即建」） | `habit_editor.dart`、`habit_detail_page.dart:48,49`、`habit_repository.dart:120` update / `:148` delete |
| #45    | —（维持「无」） | 提示只有单时点 `habit_editor.dart:263-271` |
| #46    | `habit_repository.dart:84` stats / `:95` overviewStats、`habit_page.dart:29,39,49` | 复核 B-2 已摘聚合统计卡 ⇒ `habit_detail_page.dart` 无统计卡 |

四行「状态」列一个字未改（`origin/develop` 仍在 `a1d7733` ⇒ !291 未合并）。#43 落点端 `BE(admin)/WEB` → `BE(admin)/FL` 是**证据口径替换**而非能力升级：图例里 `WEB=apps/todo` 已废弃，行内写明「撤回」二字留痕。
`!291` 合并后回来做第二遍：把「已实现待合并」换成已合并 SHA，并复评 #43/#44 的状态列。

## 第 63 轮（Issue #308）：新建表单的 6 条负路径与四件套 —— 只补测，不改行为

先把结论摆正：**这 6 条行为在 `origin/develop@9032005` 上本来就是对的**，缺的是用例，所以本轮 `lib/` 一行未改。
这不等于"顺手补个测试"——探针 P0 从测试基建里挖出一条真漏口（见下）。

| Issue #308 条目 | 用例（`test/features/habit/habit_detail_page_test.dart`） | 判据 |
| --------------- | -------------------------------------------------------- | ---- |
| 1、2 目标填 0 / 负数 / 空 / 非数字 | 「目标填「0」「-3」「」「abc」」4 条（`for` 参数化） | 字段 `decoration.errorText == '目标至少为 1'`、错误文案在弹层内可见、`server.writeRequests` 为空、弹层没关 |
| 3 创建失败保留输入 | 「新建失败：名称、频率、目标全都留着，不用重填」 | 名称仍 '晨跑'、目标仍 '5'、`ChoiceChip(period-2).selected == true`、弹层内出现「保存失败」 |
| 4 320px + 1.3 不溢出 | 「320px + 1.3 倍字体：新建表单（含字数计数器）排得下且用自己的档位」 | 档位取的是**弹层自己 context** 的 `textScaler`、`takeException()` 为 null、「保存」可命中 |
| 5 「频率」「目标」读屏 | 「读屏：『频率』组名与『目标』字段各自念得出来…」 | `ensureSemantics()` + `bySemanticsLabel` 限定在弹层内 |
| 6 默认「每天 / 1 次」 | 「新建默认值是『每天 / 1 次』，且不带上一条习惯的回填」 | 三档 chip 只有 period-1 `selected`、目标文本 '1'、名称为空 |

字段名回源：`频率` 见《05-习惯打卡/01-开始坚持一个习惯》:85，`目标` 见同页 :95 —— 与实现里的
`habit_editor.dart:232`、`:251` 一致，没有自造同义词。
读屏那条只证到"有可读标签"，`频率` 组名用的是 `Text` 而非 `Semantics(label:)`：这一组是三个
`ChoiceChip`，chip 自带文案，组名走普通文本即可被念出，不需要第 1 轮 B-1 那种显式包一层。

### 反向探针（每条先跑"未打补丁"的对照组）

第一轮就踩了坑：把被打补丁的 `lib/...` 直接喂给 `flutter test` ⇒ 6 条全 `rc=64`（生产代码不是测试入口），
看着像"全都红"其实一条都没跑。另外 `--plain-name` 命中 0 条时 `flutter test` 也报绿，
所以每条探针必须先跑对照组，否则分不清"用例不会红"和"根本没跑到用例"。

| 探针 | 抽掉什么 | 对照（未打补丁） | 打补丁后 |
| ---- | -------- | ---------------- | -------- |
| PA | `_targetError` 恒 null（`:86`） | `+4` 全绿 | `-4`：四条「目标填」全红 |
| PB | 失败分支顺手 `pop`（`:122` 后） | `+1` | `-1`：「新建失败保留输入」红 |
| PC | 默认频率 1 → 2（`:63`） | `+1` | `-1`：默认值用例红 |
| PD | `labelText: '目标'` → '数值'（`:251`） | `+1` | `-1`：读屏用例红 |
| PE | 「选择时间」文案撑爆操作行（`:273`） | `+1` | `-1`：320px + 1.3 用例红 |
| P0 | 假服务对 `/todo/habit/create` 的接住（改的是测试文件） | `+1` | `-1`：**FR-5 红**，`Actual: Found 1 widget with key <'habit-editor-sheet'>` |

P0 证明了两件事：

1. 本轮给 `FakeHabitServer` 补的 create 分支不是装饰——抽掉就有用例红。
2. **原本一直绿的 FR-5 其实是在一次失败的 create 里读请求体**：create 落到 `handler.next()` ⇒ dio 报错 ⇒
   走 catch ⇒ 弹层不关并显示「保存失败」，但请求体照样被拦截器记下，而旧用例只断言请求体。
   补上「弹层收掉 + 不出现失败提示」这两条正向对照后它才会红。
   ⇒ 教训：**请求体对 ≠ 这一面走得通**，成功路径要断言"看得见成功"。

### 320px + 1.3 的实测读数（不要把"要滚动"当结论）

```
NEW_SHEET_320_1_3 maxScrollExtent=0.0 pixels=0.0 viewport=559.6
                  hitTestable(保存): true→true bottom=692.0 sheetBottom=704.0
```

⇒ 这一档下新建表单**本来就排得下**，不需要滚动。我最初写的注释是"计数器在 1.3 倍下多占一行、
要滚到底才建得出来"，这个说法被上面的读数否掉，已按实测改掉。
用例里保留 `if (maxScrollExtent > 0) expect(pixels, greaterThan(0))` 这条条件对照：
将来表单加高到需要滚时，它仍在检验可达性，不会悄悄退化成"只读一屏就算过"。

### 修测试基建时踩到的两个"找不到"

- `find.descendant(of: <habit-editor-sheet>, matching: SingleChildScrollView)` 恒 findsNothing：
  那个 key 就打在 `SingleChildScrollView` 自己身上（`habit_editor.dart:158`），而 descendant 不含起点。
- 想按类型在 sheet 子树里找 `Scrollable` 取 position ⇒ `Bad state: Too many elements`
  （每个 `TextField` 内部各有一个 Scrollable）。改成从「保存」往上取最近祖先，才是这张表自己的。

### 用例计数

`test/features/habit/habit_detail_page_test.dart`：声明数 18 → 22（`grep -cE '^  (testWidgets|test)\('`），
运行时用例 18 → 26（+8）。差额是那 4 条「目标填 X」由一条 `for` 循环展开、缩进 4 空格所以不进声明计数。
本文件单跑：`00:02 +26: All tests passed!`。
全量对账：干净 worktree 里实跑基线 `9032005` ⇒ `02:29 +898 ~26: All tests passed!`，
分支 `+906` = `898 + 8`，**逐条对上，没有凭空消失的用例**。

## 门禁原文记录（跑在 `45c5dc3` 上，日志 `/tmp/g63/gates/`）

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check` | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed test/features/habit/habit_detail_page_test.dart` | `Formatted 1 file (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 3.4s)`，`rc=0` |
| `flutter test --tags golden` | `00:04 +9: All tests passed!`，`rc=0`，9 张基线未重录（日志里 golden 文件变更 0 处） |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:23 +906 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`，`rc=0` |

`lib/` 本轮 0 改动（`git diff --stat 9032005..HEAD` 只有 1 个测试文件 + 1 个 markdown），
所以这六道门禁检验的是"新用例本身不与任何既有行为冲突"，不是"新行为可用"。
格式与门禁顺序照惯例：先 commit 再跑门禁，`pubspec.lock` 未被顺手改（门禁后工作区只剩本轮的 markdown）。

复核 R1 修完后在 `5da193d` 上把六道门禁**整套重跑一遍**（日志 `/tmp/g63/gates2.out`）：
G1 `rc=0`、G2 `0 changed`、G3 `No issues found! (ran in 2.0s)`、G4 `00:05 +9: All tests passed!`（基线仍未重录）、
G5 `02:23 +906 ~26: All tests passed!`、G6 `✓ Built build/web`，跑完工作区 0 项。
（本轮之后只剩下面这段 markdown 追加，它不参与这六道判据。）

## 复核（PR !346 第 1 轮）：`VERDICT: FAIL`

复核员跑在自建 detached 副本上（未动本 worktree），三条必修全部回源复验后**都成立**，逐条处置：

| 编号 | finding | 复验结果 | 处置 |
| ---- | ------- | -------- | ---- |
| R1-① | 本文「下一轮入口」第 5 条引 `habit_month_grid_test.dart:96` 当作"弹层关闭" | 成立。`:96` 实为开表**前**的前置负断言；真正支撑结论的是 `:173`（失败后表还开着）、`:183`（错误可见）、`:273`（过期响应不覆盖新响应） | 已改引用；并承认我第一版"043 不在这条漏口里"说过头了 —— 043 的**成功**用例 `:142-163` 只断言假仓库计数器（`lastCheckIn*`、`overviewStatsCalls`），与 FR-5 原状态同类，见改后的第 5 条 |
| R1-② | 测试里 FR-5 注释写"抽掉接住后本文件 26 条仍然全绿" | 成立，且是我自己写反的：全绿的是**基线 18 条**；HEAD 上抽掉接住 ⇒ FR-5 红（`Found 1 widget with key <'habit-editor-sheet'>`） | 注释已按实测改写，并标出是「我把基线号写成当前号」 |
| R1-③ | 320px 那条：(a) 对照组 `find.text('目标至少为 1')` findsNothing 永不成立（该用例不点保存）；(b) 用例名叫"含字数计数器"却没钉计数器 | 都成立。(a) 我确认不可红；(b) 复核员探针 PJ：去掉 `maxLength: 64` 后计数器整行消失（视口 559.6→534.6）而用例仍绿 | (a) 删掉；(b) 补 `maxLength == 64` 与 `sheetChild(find.textContaining('/64')) findsOneWidget` 两条，自己复跑 PJ ⇒ `Expected: <64> Actual: <null>` 红，对照组 `+1` 绿 |

### 复核员替我补的探针（记下来，防止下次又只测半边）

| 探针 | 抽掉什么 | 结果 |
| ---- | -------- | ---- |
| PG | `Text('频率')`→'频次'（`:232`） | 读屏用例红 ⇒ 我的 PD 只打了「目标」半边，「频率」半边此前没被证过 |
| PF | catch 里清输入 | 红在 `Expected: '晨跑' Actual: ''` ⇒ 「保留名称/目标/档位」三条各自吃得住，不只是靠弹层关闭 |
| PH1 | 撑高弹层顶部 400 | `maxScrollExtent=259.6 pixels=259.6` 仍绿 ⇒ 那条 `if` 分支能激活，不是死代码 |
| PH2 | 撑高 + drag 位移归零 | 红 `Expected: a value greater than <0> Actual: <0.0>` ⇒ 条件对照在需要它时会真的红 |
| PI | 视口改成 320×**568** | `maxScrollExtent=23.6` ⇒ "排得下"只对 **320×720** 这档成立，文档里写"这一档"不是随口 |

### 一处不采纳（附理由）

复核员提示 FR-5 新加的 `find.textContaining('保存失败')` 用的是全局查找、没限定 surface，"方向偏严"。
**保持全局**：那条断言要证的正是"整个界面没有任何地方挂着失败提示"，而此刻弹层按预期已经收掉 ——
换成 `sheetChild(...)` 会在 surface 不存在时恒为 findsNothing，变成新的永真断言（就是 R1-③(a) 那类错）。

## 下一轮入口（本轮不接，避免顺手扩面）

1. **habit 归档 / 恢复接线**：端点在 `zh-cloud-service!276`（未合并）。合并后在详情页菜单加第 3 项，反向断言 `find.text('归档')` findsNothing 要同步改成正向断言。
2. **#45 打卡提示的多时点**：契约侧 `reminderAt` 是单个 `LocalDateTime`（绝对时点），嘀嗒是「每天 9:00/12:00/18:00/21:00」重复 ⇒ 需先在 Service 定义重复语义或改字段（spec 边界①-b），客户端不改。
3. **Service #277**：删除习惯不级联清打卡记录（`deleteHabit` 只 `deleteById`，`TodoHabitCheckInMapper` 无按 habitId 删除）⇒ 矩阵文案与嘀嗒口径差异取决于这张单的结论。
4. **同族时间字段**：全仓仍有 21 处 `toIso8601String`，未逐处判定是否同样与 `TimestampLocalDateTimeSerializer` 冲突（FR-6 已留痕）。
5. **#308 收尾（需先拿到合并授权）**：合并后把本轮用例路径写进矩阵 #44 的 FL 证据列（状态列一个字不改——本轮没有新增能力），并在 Issue #308 留言贴合并 SHA 后关闭。
   顺带记一条判据（不是待办，是复用时别再踩）：**"请求体对 ≠ 这一面走得通"**。本轮 FR-5 就栽在这里。
   这条漏口**不止习惯一处**：`habit_month_grid_test.dart:142-163`（043 的补记成功）同样只断言假仓库计数器
   （`lastCheckIn*`、`overviewStatsCalls`），没有一条"看得见成功"。
   043 另外两面是钉住的，别一并撤回：`:173`（失败后表还开着）、`:183`（错误在表内可见）、
   `:273`（过期响应不得覆盖新响应）。
   我第一版这里写的是"`:96` 断言弹层关闭 ⇒ 043 不在这条漏口里"——那是拿错行号得出的过头结论
   （`:96` 其实是开表**前**的前置负断言，复核 R1-①）。将来要扩先按同一判据逐文件抽查可红性，别凭印象推广。
