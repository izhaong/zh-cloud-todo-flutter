# 067 · 拖动到清单或标签上（矩阵 #32 面 ③）— 执行台账

基线 `zh-cloud-todo-flutter origin/develop@b0649a4c9f`；Issue `zh-cloud-todo-flutter#399`。
本轮**不**堆叠在 PR !406（面 ②）之上：那份字节正在只读复核中，改它会打断 PASS 与字节的绑定。

## 一、前置核对（现读）

- 面 ①（`92f7d66`）与面 ②（!406，head `3768985`）分别是什么，见 specs/065 与本仓 PR !406；本面只吃 `:57`/`:59`。
- 侧栏清单行与标签行在 develop 上的形态：`_ListRow`、`_TagRow`（`lib/features/shell/sidebar.dart`），
  标签数据来自 `tagsStreamProvider`，拖出源载荷是 `TodoTask`。
- 打标签能力早已存在（`TagRepository.tagIdsOf` / `setTaskTags`），本轮不动契约。

## 二、六道门禁读数

| 门 | 命令 | 读数 |
| -- | ---- | ---- |
| 1 | `git diff --check HEAD~1 HEAD`（本轮提交进来的字节） | rc=0 |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/shell/sidebar_task_drop.dart lib/features/shell/sidebar.dart test/features/shell/sidebar_task_drop_test.dart` | rc=0，`Formatted 3 files (0 changed)` |
| 3 | `flutter analyze` | rc=0，`No issues found!` |
| 4 | `flutter test --tags golden` | rc=0，`+9 All tests passed!`，`goldens_dirty=0`（基线未重录） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0，`03:30 +1143 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0，`✓ Built build/web` |

日志目录 `/tmp/r136/g67c/`（六门跑在代码字节 `aee25a9ba08b` 上，六门之后本文件只追加 markdown 提交）。真实合并试算 `git merge-tree --write-tree --name-only origin/develop HEAD` ⇒ 干净，结果树 `01f7722f5e1e`，rc=0。⚠️ 自曝一处流程错：前两遍门禁我把日志写进了同一个 `/tmp/r136/g67/` 且第二遍启动时第一遍的 `flutter build web` 还没结束，两遍互相 `rm` 掉对方的文件 ⇒ 那批日志不可信，本表只取第三遍（新目录 `g67c`、单进程、无并发）。另一处顺序错：我曾在 `flutter analyze` 之后又跑原地 `dart format`，长单行 `if` 被折行触发 `curly_braces_in_flow_control_structures`，门 3 直到门禁才红 ⇒ 修在 `aee25a9` 的前一笔 `14ac8c9`→`aee25a9` 里，教训是**门禁必须跑在最终字节上**。

## 三、用例与变异探针（`python3 /tmp/r136/probe399b.py`，逐个摘实现后只跑本文件）

本文件用例 `flutter test test/features/shell/sidebar_task_drop_test.dart --concurrency=1` ⇒ `+9 All tests passed`
（`/tmp/r136/t399-5.log`）。探针跑在加第 9 条用例之前，故下面 6 发的名单是当时的读数。

| 摘掉的实现 | 变红的用例 |
| ---------- | ---------- |
| 换清单时不清 `clearSectionId` | 拖到别的清单行 ⇒ 换清单、清掉属于原清单的分组、时间安排一毫秒不动 |
| 连 `dueAt` 一起清掉 | 拖到别的清单行 ⇒ 换清单、清掉属于原清单的分组、时间安排一毫秒不动 |
| `acceptsList` 恒真（同清单也发写） | 落回自己所在的清单 ⇒ skipped，一次写都不发 |
| 标签去重条件失效 | 拖到它已有的那个标签上 ⇒ 标签集合不变，也不多登记一次同步变更 |
| 候选态不给读屏文案 | 候选态才有「移入清单」读屏文案：静止没有、悬停有、落定收走 |
| 串行链存的是带错误的 future | 同一任务连落两刀 ⇒ 第二刀必须等第一刀写完，不能插队；第一刀写失败 ⇒ 报 failed，第二刀照样执行（链条没被旧错误吃掉） |

探针脚本末尾断言还原后与被审字节逐字节一致（`/tmp/r136/probe399-run.log` 末行「还原核对」）。

## 四、四件套逐面

- **320px + 1.3 倍字号**：用例「320px 窄侧栏 + 1.3 倍字号：悬停边框不把行挤出可视区」把视口设成 `320×720`、
  `textScaleFactorTestValue=1.3`，在侧栏自己的 context 里悬停后 `takeException()` 必须为 null。
  字号档位打在 `platformDispatcher` 上：包在子树里的 `MediaQuery` 到不了侧栏的这条路径，那样测出来永远是 1.0 倍。
- **独立读屏语义**：候选态才挂 `Semantics(label:)`，静止态不给每行都挂「移入清单」（用例正反都钉）。
  读屏断言用 `Semantics.properties.label` 直接量落点自己那个节点 ——
  `find.bySemanticsLabel` 会被侧栏行自带的按钮语义合并掉，实测 0 命中，不是判据。
- **失败保留已加载数据**：落点失败只弹提示，不动侧栏的清单/标签 stream，也不清空已渲染的行；
  用例「写失败必须在侧栏所在脚手架上看得见（提示不被吞）」钉提示可见性（这条同时证明 `ScaffoldMessenger` 真在壳层）。
- **过期响应不覆盖新响应**：`context.mounted` 挡住「写完侧栏已卸载再弹提示」；
  同任务两次落点由 `_chain` 串行（用例「不能插队」钉顺序）。
  ⚠️ 诚实登记：`context.mounted` 这一支**没有**用例咬住 —— 要构造「发起写之后卸载侧栏」的时序才测得到，
  本轮没做，留给下轮（见 §六）。

## 五、覆盖面缺口（不粉饰）

- 拖出源用普通 `Draggable<TodoTask>` 作替身。落点侧只认载荷类型，所以「从看板/时间线/并列视图真的拖到侧栏」
  这条端到端路径没有专门用例；它的另一半（拖出源存在且载荷是 `TodoTask`）已由 specs/065 与看板、时间线的既有用例钉住。
- 探针跑在补第 9 条用例之前 ⇒ 「失败提示可见」这条没有对应的变异探针。

## 六、下轮入口

1. 补 `context.mounted` 的用例：发起写 → 挂起 → 卸载侧栏 → 断言不弹提示也不崩。
2. 矩阵 #32 面 ③ 的回写：本轮字节进 develop 后，把 `:57`/`:59` 这一面从缺口清单里划掉，
   剩余面 ④（`zh-cloud-todo-flutter#400`，「拖动到智能清单上」）继续。
3. 与 !406 的 `TaskListMoveController` 收口重复的串行链（两处编排同形），
   等 !406 合并后单独开单做，不在本轮顺手重构。

## 七、只读复核

第 1 轮已派单：`claude -p --permission-mode plan --add-dir /private/tmp`，提示词 `/tmp/r136/review-407-r1-prompt.md`，被审字节 = 分支最终 head（本文件所在提交；其代码字节与 §二 的 `aee25a9ba08b` 相同，本笔只改 markdown）。输出流 `/tmp/r136/review-407-r1.jsonl`，判据只看末行 `VERDICT`。等结论回来再回填 PASS/FAIL 与逐条读数——**没拿到 VERDICT 前本单不满足合并前置**。

## 八、第 1 轮只读复核 `VERDICT: FAIL` 的处置与并主干后的门禁重跑（2026-09-28）

被审字节：head `3bcfc36`、代码字节 `aee25a9ba08b`。FAIL 只有一条（B 段），三条 NIT 见下。

- **FAIL-1 成立并已修**：`test/features/shell/sidebar_task_drop_test.dart` 的「时间安排一毫秒不动」里 `after.startAt == before.startAt`、`after.endAt == before.endAt` 在旧种子下两侧恒为 `null` ⇒ 恒真。修法：该用例先把 `sectionId` + `startAt` + `endAt` 一起种进库（`DateTime` 非常量，故两个种子值做成顶层 `final`），并加三条「种子没写进去就是空断言」的前置断言。
  反向探针 `/tmp/r136/p399c/probe.txt`：给 provider 的 `update` 加 `clearStartAt: true, clearEndAt: true` ⇒ 该用例转红（`probe rc=1`，期望非 0），还原后 `RESTORED-OK` 且 `git status --porcelain` 对该文件计数 0 ⇒ 断言现在真能咬住实现被误清空。
- **NIT-1/2/3（未修，登记为下轮入口）**：探针跑在 15:30 快照而非 `aee25a9` 定格之后（6 处 needle 在 `aee25a9` 均 `count=1`，结论不受影响）；`/tmp/r136/g67c/merge.txt` 当时没记调用时刻的 `origin/develop` SHA；320px/1.3 字号用例没有专属变异探针。
- **并主干**：分支原基 `b0649a4`，develop 已到 `af62a8bfa2da`（specs/047 与 specs/064 进线）⇒ merge 冲突 0 处（`git status --short | grep -c "^UU"` = 0），代码字节定为 `f4d7e78`。

六道门禁重跑在 `f4d7e78` 上（日志 `/tmp/r136/g67e/`）：
`g1 rc=0`（`git diff --check $(git merge-base origin/develop HEAD) HEAD`）、`g2 rc=0` + `Formatted 3 files (0 changed)`、`g3 rc=0` + `No issues found! (ran in 1.7s)`、`g4 rc=0` + `goldens_dirty=0 png=9`（9 张基线未重录）、`g5 rc=0` + `03:30 +1180 ~26: All tests passed!`、`g6 rc=0` + `✓ Built build/web` 且收尾 `status=0`。
真实合并试算：`git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0、干净树 `37ca4c53e5fc8f9f7d2d73e5b2ef03cf4c46a15a`，调用时刻 `develop_at_call=af62a8bfa2da`。
