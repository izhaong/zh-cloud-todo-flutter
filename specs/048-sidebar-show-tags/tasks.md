# 048 · 任务清单（Issue #328 / 矩阵 #21）

分支 `feat/328-sidebar-show-tags`，基准 `origin/develop@9032005`。

## 实现

- [x] `SidebarVisibilityRepository`（`get/watch/save`，`SIDEBAR_VISIBILITY` + `global`，`viewPreference` outbox）
- [x] `sidebarVisibilityRepositoryProvider` / `sidebarShowTagsProvider`
- [x] 侧栏 `tagEntries` 门控（`lib/features/shell/sidebar.dart:70-82`）
- [x] 设置 →「智能清单」→「标签」行 + 显示/隐藏选项弹层（`settings_route.dart:137-158`、`_pickShowTags`）
- [x] `_Tile` 支持 `super.key` 与 `trailingText`（取值用文字而非勾，读屏同源）

## 验收（本轮新增 14 条用例，`flutter test` 实测全绿）

| FR | 用例 | 文件 |
| -- | ---- | ---- |
| FR-1 默认显示 | `默认值必须是「显示」…` | `test/sidebar_visibility_repository_test.dart` |
| FR-1 关掉就没 / 再开回来 | `侧栏标签条目跟着「显示标签」走：默认在、关掉就没、再打开又回来` | `test/features/shell/sidebar_show_tags_test.dart` |
| FR-1 取舍 1（入口行不收） | 同上第 3 条断言 `todo-sidebar-row-tags` 仍 `findsOneWidget` | 同上 |
| FR-1 读不到偏好不清空 | `偏好读不到时侧栏按默认「显示」处理…` | 同上 |
| FR-1 实时生效 | `watch 在写之后立刻推新值，侧栏不必重进` | 仓库层文件 |
| FR-2 一次点击写库 / 点回也写回 | `设置 →「智能清单」→「标签」：一次点击选「隐藏」就写库…` | `test/features/settings/sidebar_show_tags_settings_test.dart` |
| FR-2 取消不写 | `打开弹层后不选直接关掉：不写库、取值不变` | 同上 |
| FR-3 跨重启 + outbox | `保存「隐藏」落同一行、入 outbox，重开库仍读得到` | 仓库层文件 |
| FR-3 服务端包装可读 | `同步拉回的服务端包装格式要能读出来…` | 仓库层文件 |
| FR-4 默认值不动黄金基线 | `默认值必须是「显示」…` + 黄金门禁 ④ 未重录 | 仓库层文件 + 门禁 |
| FR-5 读屏 | `取值由这一行自己的读屏语义念出来，不是只画一个勾` | 设置文件 |
| FR-5 失败保留 | `写入失败时给出可见提示，取值与库里的值都保持原样` | 设置文件 |
| FR-5 320px + 1.3 | `320px + 1.3 倍字号：设置行与选项弹层都排得下…`、`320px + 1.3 倍字号下「显示」与「隐藏」两种侧栏都不溢出` | 设置 / 侧栏文件 |

## 四件套（新增界面 = 设置里那一行 + 选项弹层）

| 维度 | 结论 | 证据 |
| ---- | ---- | ---- |
| ① 320px + 1.3 | 通过：设置页与弹层各在自己的 context 上测（`MediaQuery.builder` 注入 1.3，视口 320×720），`takeException()` 为 null | 设置文件最后一条 |
| ② 独立读屏语义 | 通过：取值是 `trailingText` 的 `Text`，合并进该行的语义节点 ⇒ 念出「标签 … 显示」；配对反向断言（当前「显示」时念不到「隐藏」） | 设置文件第二条 |
| ③ 失败保留已加载数据 | 通过：`save` 抛错 → SnackBar「保存失败，显示标签仍为当前设置」，行内取值与 `todo_view_preferences` 行数都不变；SnackBar 4s 后自动消失仍被断言 | 设置文件第三条 |
| ④ 过期响应不覆盖新响应 | **通过（第一轮是假绿，复核已补）**：写入的是**点中的字面值**，不是 `!current`；`current` 只用于画勾选标记。设置第一条现在多走一步"当前已是显示时再点一次显示"，并断言界面取值与库里 `showTags` 都还是 `true` ⇒ 取反实现必须红 | 设置文件第 1 条 + 探针 PG |

## 反向探针（摘掉实现看测试会不会红）

| 探针 | 变异 | 期望 | 实测 |
| ---- | ---- | ---- | ---- |
| PA | 侧栏门控 `!showTags` → `!false && showTags`（等于永不收起） | 红 | 红 `-2` |
| PB | `defaultShowTags = false` | 红 | 红 `-5`（仓库 + 侧栏） |
| PC | `_decode` 丢掉服务端嵌套包装分支 | 红 | 红 `-1` |
| PD | `save` 的 id 改为每次新生成（update 命中 0 行） | 红 | **首跑绿 —— 假阳性，已补强后转红** |
| PE | 设置行 `trailingText` 的取值改成 `null` | 红 | 红 `-4` |
| PF | `catch` 里改成 `rethrow`（不再给可见提示） | 红 | 红 `-1` |
| PG | `_pickShowTags` 写成 `save(showTags: !current)`（取反而非照抄字面值） | 红 | **首跑绿（复核抓出的假绿）⇒ 补一步后转红 `-1`**，见下节 |

**PD 的教训（诚实记录）**：原断言只在 4 次 save 之后读一次最终值 ⇒ "id 漂移导致每次都写不进去、库里停在第一次的 false" 这条 bug 恰好也停在 `false`，测试全绿。
补强为**每次 save 后立刻回读** + 断言行 id 不变 + outbox 计数 4 ⇒ PD 转红（`改写必须真的落到那一行`）。

**④ 那条"副作用"是我写错的（复核判 P1，已复验并采纳）**：原话是"仓库层那条顺手把『写入字面值不是取反』锁住了"。
不成立 —— 仓库层用例直接调 `repository.save(...)`，**根本不经过 `_pickShowTags`**，实现里怎么写取反它都看不见。
而设置页那条又只走"当前显示 ⇒ 点隐藏 ⇒ 再点显示"，两次都点在与当前相反的那一项上 ⇒
取反实现逐点等价，`save(showTags: !current)` 变异后 14 条全绿（复核员与我各自在副本上实测一致）。
⇒ 修法：设置第一条末尾补一步"**当前已是显示时再点一次显示**"，断言 `_trailingValue` 仍是「显示」且库里 `showTags` 仍是 `true`。
补完后 PG 变异转红（`写入的必须是点中的字面值，不是"和当前相反"`），还原后 5 条全绿。
⇒ 一般化：**"写入的是点中的值"这类断言，必须有一条"点中的值 == 当前值"的路径**，否则永远测的是取反。

## 与嘀嗒的已知偏差（不写成"一字不差"）

1. 只收起标签**条目**，不收「标签」那一行入口（spec 取舍 1）。
2. 移动端 `:16` 的「清单管理页」本 App 不存在，开关放在设置页 ⇒ 可达但层级不同（spec 取舍 3）。
3. 帮助页两张截图取不到（离线镜像只有 .md）⇒ 无法核对"隐藏后整组是否留标题"。

## 门禁（最终字节，commit 之后跑）

跑在提交后的最终字节上。第一版 `2dd3dc1`（日志 `/tmp/r67-gates.log`）六条全绿；
复核补了 PG 那一步之后**六条在 `f7df38e` 上全部重跑**（日志 `/tmp/r67/gates_r2.log`），本表是重跑后的字节。

| # | 门禁 | 结果（`f7df38e`） |
| - | ---- | ---- |
| 1 | `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 7 个显式文件>` | `Formatted 7 files (0 changed)`，`rc=0` |
| 3 | `flutter analyze` | 第一遍（`2dd3dc1` 之前）`rc=1`（`prefer_is_not_empty` 一条）⇒ 改完重跑；重跑后 `No issues found!`，`rc=0` |
| 4 | `flutter test --tags golden` | `+9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:46 +912 ~26: All tests passed!`，`rc=0` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`，`rc=0` |

补的那一步在**既有用例内部** ⇒ 用例数不变，`+912` 与补之前一致（不是"没跑到"）。

计数对账：`+912 = 898 + 14`。14 = 本轮新增（仓库层 6 + 侧栏 3 + 设置 5）。
基线 898 **本轮由本轮自己的证据反算**：`git diff --name-status origin/develop...HEAD -- test` 全为 `A`（只新增测试文件、没改任何既有用例）
⇒ 基线 = 912 − 14 = 898。
（第一版这里写的是"沿用第 64/66 轮实跑记录"，复核指出 `/tmp` 里没有任何日志的**末行**是 `+898`
（`/tmp/r66-full.log` 的 `+898` 是 `02:52` 的进度行，该轮末行是 `+930`），那个数只是别处文档里的转述
⇒ 引用别轮"实跑"是不实措辞，已换成本轮可复算的口径。）
`~26` 跳过数：本轮未新增 skip。
`pubspec.lock` 未进提交：`git log --stat origin/develop..HEAD -- pubspec.lock` 为空。
**跑门禁必须带镜像 env**（`source ~/development/env-flutter.sh`）：不带时 `flutter analyze`/`test` 的隐式 `pub get`
会把 `pubspec.lock` 里 150 行 `url:` 从 `pub.flutter-io.cn` 翻成 `pub.dev`（复核在副本上实测），
此时"`git status --short` 为空"这句话在别人机器上就不成立。

第一遍只有门禁 3 红（测试里 `!finder.isEmpty` 应写成 `finder.isNotEmpty`）⇒ 单提 `style(test)` 提交 `2dd3dc1` 后**六条全部重跑**，本表是重跑后的字节。

## 复核（第一轮 `VERDICT: FAIL`：1 条 P1 + 3 条 P2）

逐条回源复验后的处置（不认的一律写了理由）：

| 复核发现 | 我的复验 | 处置 |
| -------- | -------- | ---- |
| **P1** ④「写入字面值不是取反」在 UI 层没有测试锁住：把 `save(showTags: picked)` 改成 `save(showTags: !current)`，14 条全绿 | 我独立在 `settings_route.dart` 上重跑同一变异 ⇒ 同样全绿；读代码确认原设置用例只点"与当前相反"的那一项，仓库层用例又根本不经过 `_pickShowTags` | **采纳**。补"当前已是显示时再点一次显示"一步 ⇒ 同一变异转红 `-1`（探针 PG）。原写在 PD 段末尾的那句"副作用：这条顺带锁住了字面值"是**不实陈述**，已删除并改写 |
| **P2** loading 与"读不到"共用默认值 ⇒ 库里是「隐藏」时冷启动首帧会先把标签区画出来 | 读 `sidebar.dart:70-72` 的 `valueOrNull ?? defaultShowTags` ⇒ 成立（`valueOrNull` 在 loading 也是 null）。复核的副本用例（仓库 `watch()` 永不出值 + 只 `pump()`）与结论一致 | **采纳为真缺陷，本轮不修**：改成"首值未到先不画"会让首帧少一块内容，9 张黄金基线含侧栏画面 ⇒ 可能要求重录基线，而**重录基线要先请示**、本轮无授权。已立 **#353** 记现象、复现路径与两条候选修法 |
| **P2** 898 的溯源写得不实：`/tmp` 里没有任何日志末行是 `+898`，它只是别处文档的转述 | 复核给的命令我认：本轮 `git diff --name-status origin/develop...HEAD -- test` 全是 `A` ⇒ 基线可由 `912 − 14` 反算 | **采纳**。门禁段改成"本轮自己的证据反算"，并保留"第一版写过不实措辞"的记录 |
| **P2** 「门禁跑完后 `git status --short` 为空」在别人机器上不成立：不带镜像 env 跑 analyze 会把 `pubspec.lock` 的 150 行 url 翻成 `pub.dev` | 与本仓 memory「门禁必须跑在 commit 之后、pub get 会重写 lock」同形；复核在副本上实测并还原了 worktree（我随后 `git status --porcelain` 确认 `/tmp/wt-flutter-328` 干净） | **采纳**。门禁段加了"必须 `source ~/development/env-flutter.sh`"的前置说明 |
| 复核未能复现 PC/PF 两条探针（时间预算） | 两条的机制与已复现的 PD 同形（都是"抽掉分支 ⇒ 断言读得到差异"） | 不作为缺陷，**也不假装已复现**；PG 这次由我自己独立复现，P1 那条才是关键防线 |

复核对 2/3/4/6 项的独立实测（默认值三条降级路径、写失败后界面停在原值、读屏两条配对断言各自变异都红、
`analyze` 干净、`diff --check` 干净、`pubspec.lock` 未进提交、本分支没碰 docs）与我的自述一致，无需返工。

**两处计数口径差异，记下来不藏**：复核在**单文件**口径下量到 PA 红 `-1`、PB `+4 -10`，
我在**全量**口径下记的是 `-2` 与 `-5` ⇒ 数字不同不是结论不同（都红、红在该门控上），
但探针表里的数字标明口径才有意义。本轮起：探针一律跑**单文件**并写明，全量口径交给门禁 5。

## 已知偏差（本轮不修，除 #353 外）

- ~~冷启动首帧按默认「显示」画标签区~~ ⇒ **#353 已在第 74 轮修于本分支（`04cc0ac`）**；
  但本分支尚未合并进 `develop`，所以对 `develop` 的口径而言这条**仍然成立**（矩阵 #21 因此不动，见下）。

## 残留缺口（本轮不做，留下轮）

- 矩阵 #21 其余面：任务详情输入 `#`、`TaskQuickAddSheet` 的 `#` 入口仍被未合并的 `!319/!322/!314` 挡着。
- 移动端「清单管理页」界面本身（嘀嗒 `:16` 的入口位置）——需要单独立项，属矩阵 #19。

## 第 74 轮：#353 落地（侧栏标签区在偏好首值未到达前不画）（两轮红绿）

### 病灶（一句话）

`valueOrNull ?? 默认` 把 **loading** 与 **error** 折成同一态：`valueOrNull` 在两种状态下都是 `null`，
于是"还没读到"被当成"读到了、值是显示" ⇒ 库里存着 `showTags=false` 的账号冷启动会先画出标签条目再收走。
FR-4 的"默认必须是显示"真正的兑现处在仓库层（`_decode(null) ⇒ true`：库里没有这一行 = 用户从没设过），
widget 只管三态各自落点。**这条最终版前后走了两轮，第一轮自己修出同一个病的新形态**，见下。

### 第一轮（`04cc0ac`）：改对了 loading，改坏了 error

红测（跑在 `ada7eb7`，日志 `/tmp/r74/red.log`）：`00:00 +3 -1`，红的正是新加那条，
失败点落在**首值未到达那一帧**（`sidebar_show_tags_test.dart:121`，`focusTag()` 实测 `Found 1 widget`）。
同一条用例里先跑两条正向对照（智能清单行在、`todo-sidebar-row-tags` 入口行在）⇒
红不是"整棵侧栏还没数据"造成的。

第一版实现写成三参数 `.when(data/loading/error)`，四条反向探针全绿（`/tmp/r74/PROBES.log` 的第一轮记录）。
**但 `.when` 把"出过一次值之后流才报错"也送进 `error` 分支**（带旧值的 `AsyncError` 不走 `data`）⇒
这种时候退回兜底默认 = 标签条目在流失败那一刻**闪回来**，
既违反四件套 ③「失败保留已加载数据」，也恰好是 #353 同一类错误（把两件事折成一个态）。
这条是我自己在写第二条用例时撞出来的（`gate.add(false)` 之后 `gate.addError(…)` ⇒ `+4 -1`），
不是复核抓的。

### 第二轮（`f11cdb1`，最终版）：三态各自落点

```dart
final showTagsAsync = ref.watch(sidebarShowTagsProvider);
final showTags =
    showTagsAsync.valueOrNull ??
    (showTagsAsync.hasError
        ? SidebarVisibilityRepository.defaultShowTags
        : false);
```

- 有值就用值 —— 含"出过一次值之后流才报错"（`valueOrNull` 在这种态下仍是旧值）；
- 无值且 `error` ⇒ 兜底默认（首值就读不到，FR-4 的口径）；
- 无值且 `loading` ⇒ 不画，与同文件 `lists`/`folders`/`tags` 的"没值画空"同一套。

两条新用例：`首值未到达前不画`（含放行 `true`/`false` 的双向对照）与
`出过一次值之后流失败仍保留「隐藏」`。修法不选 #353 列的「同步首值」「等高占位」，理由与代价见 `spec.md` 取舍 4。

### 门禁（跑在最终字节 `f11cdb1`，日志 `/tmp/r74/gates2.log`；第一轮那批读数在 `gates.log`）

| # | 门禁 | 读数 |
| - | ---- | ---- |
| 1 | `git diff --check` | `rc=0`，无输出；**所有提交落完后复跑一次**（第 72 轮 `!356` 复核 D1 抓到"md-only 提交给文件末尾添空行 ⇒ `git diff --check` 对自己所在 diff 不成立"，本轮起门禁 1 一律复跑） |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 2 个显式文件>` | `Formatted 2 files (0 changed)`，`rc=0` |
| 3 | `flutter analyze` | `No issues found!` |
| 4 | `flutter test --tags golden` | `00:17 +9: All tests passed!` ⇒ **9 张基线一张都没重录**（"可能要重录基线"正是 #353 当年挂起的理由，本轮证伪） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:31 +914 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=…` | `✓ Built build/web` |

计数对账：`+914 = 912 + 2`。912 是**本分支自己**第 67 轮门禁 5 的实测末行（上面那张旧表 `f7df38e` 那一列），
本轮新增 2 条用例、没动任何既有用例 ⇒ 本轮改动集用 `git diff --name-only f11cdb1~3..f11cdb1 -- test` 量，（**这里原先写的是 `~2`**：`~2` 的起点正好是 `04cc0ac`，把它自己的测试改动排除在外了。复核员两种区间都跑过，文件清单相同 ⇒ 结论不翻，但命令本身要写对）
只有 `sidebar_show_tags_test.dart` 一个文件（口径别搞混：整条分支对 `develop` 是 3 个测试文件，那是第 67 轮的账）。
`~26` 与第 67 轮一致（未新增 skip）。`pubspec.lock` 未进提交：`git log --stat origin/develop..HEAD -- pubspec.lock` 为空。

### 反向探针（口径 = **单文件** `test/features/shell/sidebar_show_tags_test.dart`，最终版 5 条；日志 `/tmp/r74/PROBES.log`）

| 探针 | 变异 | 读数 | 红掉的那条 |
| ---- | ---- | ---- | ---------- |
| QA | 三元式 else（loading 无值）翻 `true` | `+4 -1` | 首值未到达那条 ⇒ 用例有牙 |
| QB | `hasError` 兜底改成 `false`（读不到就清空） | `+4 -1` | 第 67 轮那条「读不到按默认显示」⇒ 老防线没被改坏 |
| QC | 有值也无视、恒按默认「显示」 | `+2 -3` | 首值 + 隐藏两向 + 出错保旧值那条 ⇒ 证明门控读的是值本身 |
| QD | 整段退回第 67 轮原字节（`valueOrNull ?? 默认`） | `+4 -1` | 只有首值那条红 ⇒ 新用例钉的就是本病灶，没有顺带依赖 |
| QE | 退回本轮**第一版** `.when(…)` | `+4 -1` | **只有**「出过一次值之后流失败」那条红 ⇒ 第二轮那次修改是承重墙，其余四条都测不到它 |

每条之后 `git checkout -- lib/…` 还原（HEAD 已是最终字节，FINAL 行 `+5: All tests passed!` 即还原自证）。

### 矩阵与跨仓

- **矩阵 #21 本轮不动**：那一行由未合并的 docs `!105` 重判为「部分 / BE/FL」，且基准写死
  `zh-cloud-todo-flutter origin/develop@9032005` —— #328 与 #353 都还没进 `develop`，
  按"矩阵翻转只引已合并 SHA"，本轮既不能翻状态、也不该去改 `!105` 已占的那一行。
- 只改 FL 一侧，无后端契约变化（`todo_view_preferences` 与 outbox 在第 67 轮就定了）。

### 复核

#### 第 1 轮（只读，基准 `dc61721`）⇒ `VERDICT: FAIL`；1 条 F-1 已修，2 条非阻塞已登记

行为侧**全部通过**（复核员独立跑绿、我给的六类反例逐条对到了具体断言），否的是**举证**。

| 编号 | 否的是什么 | 我回源复验 | 处置 |
| --- | --- | --- | --- |
| F-1 | **PR !351 正文与 head 不一致**：「第 74 轮追加」那段贴的实现是 `.when(data: …, loading: …, error: …)` —— 正是 `f11cdb1` 提交信息里写明"会把带旧值的 `AsyncError` 折进 error ⇒ 条目闪回来"而**被我自己否掉**的那一形；读数写 `+913 = 912 + 1`、探针写「QA–QD 四条」，而终态是 `valueOrNull ?? (hasError …)`、`+914 = 912 + 2`、QA–QE 五条。合并时 `Fixes #353` 以这段描述为凭据自动关单 ⇒ 审计轨迹自相矛盾 | 自己 GET 回来数标记：`'.when('` 在=True、`'+913'`=True、`'+914'`=False、`'QE'`=False ⇒ **成立**。它否的是举证不是行为，与我自己的判断一致 | 已 `PATCH` 重写该段：贴终态代码 + `sidebar.dart:81-86` 锚点 + `+914 = 912 + 2` + QA–QE 五条，并明写"本段原先贴的是第一轮实现，已被 `f11cdb1` 取代"。读回（判据按"旧实现代码块"而非任何 `.when` 字样，因为新正文要**提到**那个被否的形）：`sidebarShowTagsProvider).when(`=False、`+913`=False、`+914 = 912 + 2`=True、`QE`=True、`sidebar.dart:81-86`=True、`Closes #328` 仍在。脚本 `/tmp/r77/fix_pr351_body.py` |

**我点名要它答的两条**：

- **① 「带旧值的 `AsyncError` 走 `valueOrNull`」是实测还是想当然** ⇒ **成立，且两路证实**。
  QE 探针（退回 `.when` 那一版）只有「出过一次值之后流才失败」那条红；复核员另读 riverpod 2.6.1
  源码 `common.dart:572`（`valueOrNull => hasValue ? value : null`）、`:528`
  （`AsyncError.copyWithPrevious` 把 `hasValue: previous.hasValue` 带过去）、`:605`
  （`hasError => error != null`）独立对上。
- **② 同类折叠是否还在别处** ⇒ **它没按我的口径做完**。我要的是"全仓 17 处 `valueOrNull ??` 逐处判"，
  它判了 `sidebar.dart` 的门控读法、把"别处"落成两条建议，没给全仓逐处的表。
  这条我记下来：**下次派单要把"逐处列表"写成硬性交付物（表格 + 每处一行结论），否则会被降级成建议。**

非阻塞、本轮不改，**已立 FL #363**「设置面『显示标签』取值文字用 `.when(error:)` 折掉带旧值的失败（与 #353 同形）」：

- `settings_route.dart:149-155` 用 `.when(error: (_, _) => '读取失败')` 读值 ⇒ 出过一次值之后流失败时，
  已加载的取值显示被换成「读取失败」。写入侧不受影响（`:221` 的 `current` 走 `valueOrNull`，PG 钉住字面值）。
- `providers.dart:155-156` 那句注释「一个读不到的偏好不该把侧栏标签区清空」与本面定的三态口径不同调
  （首值失败才回兜底默认；加载中不回、不画）⇒ 归到 #363 的验收第 3 条一起改。

F-1 改的是 **PR 正文**，代码字节一字未动（head 仍是 `dc61721`，本节的文档提交不碰 `lib/`、不碰 `test/`）
⇒ **不重派第 2 轮复核**：它否的那条证据链已按读回校验闭合，再派一轮只会重跑同一批绿灯。
需要合并前再要一次独立 `VERDICT` 的话说一声即可（成本约一轮）。门禁读数不因本提交改变，
理由：本提交 `git diff --name-only` 只有 `specs/048-sidebar-show-tags/tasks.md` 一个文件。

## 第 98 轮：#363 落地（设置面「显示标签」取值改三态读法）（红→绿，三条反向探针全命中）

### 为什么接在 !351 这条分支上，而不是新开第 19 条 FL PR

动手前先枚举 open PR 的触达文件（`GET /repos/izhaong/zh-cloud-todo-flutter/pulls?state=open` 逐条再取
`/pulls/<N>/files` 的 `filename` —— **不要取 `patch` 字段，它会整段缺失**）：
`settings_route.dart` 被 !351（本分支）/ !360 / !370 三条未合并分支同时占着，`providers.dart` 同。
⇒ 另切分支就是再造一条同文件互撞 PR（docs 那边 7 月已经为此返工过一次，见 zh-cloud-docs #98）。
本笔落在 `feat/328-sidebar-show-tags`，提交 `032cc72`。

### 红测（实现前跑，日志 `/tmp/r98/red.log`）

新增三条用例，只有该否的那条红：

```
00:01 +7 -1: Some tests failed.
Expected: '隐藏'
  Actual: '读取失败'
reason: 错在有值之后 ⇒ 取值文字要留住上次读到的那个，退回「读取失败」等于把已加载数据丢掉
```

另两条（首值就失败 ⇒ `读取失败`；加载中 ⇒ `…`）当时就绿 —— 它们是**防我把修复写成"吞掉错误"**的那一半，
不是凑数用例：QB/QC 两条探针正是打在这两条上（见下）。

### 实现（只改两处读法 + 一句注释）

- `settings_route.dart` 的 `_showTagsLabel` / `_showTagsStale`：与 `lib/features/shell/sidebar.dart`
  的 `_showTags`（第 74 轮定的口径）同一套 —— 有值用值，没值才区分失败/加载中；
  并在"留住旧值 + 流已失败"这一格补一句可见提示 `读取偏好失败，显示的是上次读到的值`。
- `providers.dart` 的 `sidebarShowTagsProvider` 文档注释改到三态口径（原句「一个读不到的偏好不该把侧栏标签区清空」
  把"首值失败"与"加载中"混成一谈）。
- **没有**新增界面 ⇒ 四件套里只有「失败保留已加载数据」这条被本笔直接命中，其余三条沿用第 67/74 轮用例。

### 门禁（跑在最终字节上，日志 `/tmp/r98/h*.log`）

先说清"最终字节"是哪一笔：代码与测试是 `38c7aa0`，本节 markdown 是它的下一笔。
markdown 只动 `specs/`，不可能影响 dart 侧读数 ⇒ 复跑范围按第 74 轮定的规矩：**门禁 1 用 range 形态复跑**，其余五条
以 `38c7aa0` 之后的这轮为准（下表）。

| # | 门禁 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop...HEAD` | **第一遍 rc=2**，输出 `specs/048-sidebar-show-tags/tasks.md:335: new blank line at EOF.` ⇒ 是上一笔台账提交（`87ce575`）在文件末尾添的空行；本笔把它去掉后复跑 rc=0 |
| 2 | `dart format --output=none --set-exit-if-changed` 只列本轮 3 个 dart 文件 | rc=0，`Formatted 3 files (0 changed)` |
| 3 | `flutter analyze` | rc=0，`No issues found!` |
| 4 | `flutter test --tags golden` | rc=0，`+9: All tests passed!`；**基线未重录**判据：`git status --porcelain \| grep -ci png` = 0 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0，`+919 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0，`✓ Built build/web` |

**门禁 1 的一条硬教训（本笔抓到，不是复述别人的）**：`git diff --check`（不带范围，工作区对索引）在 md-only 提交之后
**恒 rc=0**，因为那时工作区已经干净；能抓到"文件末尾添空行"的只有 `git diff --check origin/develop...HEAD` 这个 range 形态。
⇒ 本轮起 markdown 提交后的复跑一律用 range 形态，plain 形态只算工作区卫生检查。
（第 74 轮那条注记说的"md-only 提交给文件末尾添空行"是同一件事，当时它写在正文里，这次是真被它咬到。）

**我自己的三处错，记下来别掩盖**：① 第一版门禁脚本把 `--dart-define` 打成 `TODO_TENID`，那条读数作废，
表里第 6 行是重跑正确命令后的读数；② 门禁 1 第一遍用的是 plain 形态（`git diff --check`，工作区对索引），
它对已提交的 md 改动恒绿 ⇒ 换 range 形态才抓到 EOF 空行；③ **上一笔提交的信息说过头**：
`a9150c2` 的正文说"补两条用例的读数"，但那次改动台账的 python 脚本因中文里用了 ASCII 双引号而 `SyntaxError` 整段没执行，
只有前一笔 Edit（门禁表）与去空行落进了那笔提交 —— 现跑证据：`git show --stat a9150c2` 只含 `specs/048-sidebar-show-tags/tasks.md`，
而该笔内容里 `+917` 仍在（未改成 `+919`）。本节数字以这一笔为准。
全量差值只引用先前读数（见下"计数对账"），能现算的只有本文件用例数
`git show 6e95236:test/features/settings/sidebar_show_tags_settings_test.dart \| grep -c 'testWidgets('` = **5**、
`grep -c 'testWidgets(' test/features/settings/sidebar_show_tags_settings_test.dart` = **10**（本笔 +5 条）。


### 反向探针（三条，各自只打红它该打的那条用例）

| 探针 | 改法 | 变红的用例 | 还原 |
| --- | --- | --- | --- |
| QA | 实现前那一版就是它（`.when(error: …)` 折态） | 「出过一次值之后流才失败：取值仍是上次读到的」 | 即红测原始状态，见上 |
| QB | `_showTagsLabel` 里 `return state.hasError ? '读取失败' : '…';` 改成 `return '…';` | 只有「首值就没读到就失败：取值显示『读取失败』」 | `QB_RESTORE_IDENTICAL` |
| QC | 整段删掉 `if (_showTagsStale(...))` 那个提示节点 | 只有「出过一次值之后流才失败…失败另有可见提示」 | `QC_RESTORE_IDENTICAL` |

`*_RESTORE_IDENTICAL` = 还原后 `cmp -s` 与探针前副本逐字节一致；再核 `git status --porcelain` 为空
（副本 `/tmp/r98/settings_route.pristine`，脚本 `/tmp/r98/after.sh`）。
QB/QC 各只打红一条 ⇒ 两条新用例不是互相抄实现的孪生断言。

### 本笔新增的提示节点也走四件套（另两条用例）

- **①「320px + 1.3 倍字号」要量它自己的那一态**：留住旧值 + 失败提示同现才是这行的最宽组合，
  沿用正常态那条测不到它。读数：`takeException()` 为 null、`隐藏` 与提示各 `findsOneWidget`。
- **② 读屏语义：实测是"并进本行的合并节点"，不是独立节点。**
  `tester.getSemantics(find.text('隐藏')).label` 打出的合并 label 依次是
  `标签` / 副标题 / `隐藏` / `读取偏好失败，显示的是上次读到的值`
  ⇒ 断言只写"念得到、且与留住的取值同现"（两个 `contains`），**不写成"独立语义节点"**，那会是假陈述。
- 探这条时查到的两个 harness 事实（写下来免得下轮再猜）：
  `find.bySemanticsLabel('…')` 比的是节点**整条**合并 label 而非子串 ⇒ 用完整句当参数恒 0 命中；
  `debugDumpSemanticsTreeInTraversalOrder()` 在 `flutter_test` 作用域里不可直接调用（编译期 `Method not found`）。
  ⇒ 判语义只能走 `getSemantics(finder).label` + `contains`。

门禁 5 的计数对账（**标注读数来源，不装作现跑过基线**）：`+919` = 第 74 轮那张表的 `+914` + 本笔 5 条新用例。
`+914` 来自本台账上一节（同分支 `f11cdb1`），其间只有 markdown 提交
（`git diff --name-only f11cdb1..032cc72~1` 现读 = `specs/048-sidebar-show-tags/spec.md`、`specs/048-sidebar-show-tags/tasks.md`；
`... | grep -c '^test/'` = 0）

⇒ 用例数不可能变；本笔**没有**回跑"实现前"的全量，所以这条是引用先前读数 + 结构推论，不是同批对照实测。
本文件用例数则是现跑对照：`git show HEAD~1:test/features/settings/sidebar_show_tags_settings_test.dart | grep -c 'testWidgets('` = 5，
`grep -c 'testWidgets(' test/features/settings/sidebar_show_tags_settings_test.dart` = 8。

### 成对判据（Issue #363 验收第 2 条，按它的口径给）

```bash
# ABSENT：设置面这一处不再用 .when( 读这个偏好（代码面 0 处，剩下的 1 处是我写的注释）
grep -n "\.when(" lib/features/settings/settings_route.dart | grep -vc '///'      # ⇒ 0
# PRESENT：正对照，证明上面那条 grep 不是恒 0
git grep -c "valueOrNull" -- lib | head    # ⇒ 含 settings_route.dart:4 等多处命中
```

### 限制（如实写，不当已通过）

**本分支没有 `tool/check_spec_selfscan.py`** ⇒ 「台账必须过仓内自扫判据」这一条本轮**跑不了**。
复算：`ls tool/check_spec_selfscan.py` ⇒ `No such file or directory`；
`git branch -a --contains <该文件的引入提交>` ⇒ 只在 `feat/361-calendar-list-timeline`（PR !364，**未合并**）。
本笔只用手工 grep 做了同类自查（行号自锚、活计数、引用不存在的报告这三类）：本节所有数字都带现跑命令，
不写"第几行"这类会被下一笔编辑作废的锚点。

### 矩阵与下一轮入口

- **矩阵 #21 仍不翻**：依据是未合并的 docs `!105`，且 #328/#353/#363 三条都还没进 `develop`
  ⇒ 按「矩阵翻转只引已合并 SHA」「未合并不得翻转状态」。
- 同形排查**没做完**：`git grep -l "\.when(" -- lib | wc -l` = **16** 个文件，其中**代码面**
  （`for f in $(git grep -l "\.when(" -- lib); do n=$(grep -n "\.when(" "$f" | grep -vc '///'); [ "$n" -gt 0 ] && echo "$f:$n"; done`）
  命中 **15 个文件、17 处**（`settings_route.dart` 只剩我写的那条注释，所以不在列）。
  **本笔没有逐处判过它们是不是同一个"折掉带旧值的失败"的形**，不声明"已排查完"；
  要判就得连读处（`git grep -c "valueOrNull" -- lib`）一起列成一张表，留作单独一轮，不塞进本 PR（不在 !351 里扩面）。
- 下轮入口：本 PR 的只读复核（第 2 轮，基准 `032cc72`）回来后回写本节；
  以及 FL #366（协作入口零用例，纯补测试）、#362（日历「下拉展开日历全景」）。
