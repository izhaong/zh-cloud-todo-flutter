# 044 任务清单

## 已证实
- [x] 「跨列拖动」这一面在 develop 上**有实现且有测试**：`kanban_view.dart:540`/`:398` + `tasks_by_list_page.dart:380`，测试 `task_workable_views_test.dart:14`/`:56` ⇒ 源页 `:64` 成立
- [x] 「管理分组」的实体与 CRUD 在 develop 上**已存在**：`tasks_by_list_page.dart:1829`-`:1862`（`todo-section-create`、rename/up/down/delete、tooltip `:1849`「管理分组 <名称>」）⇒ 源页 `:115` 的清单侧入口成立
- [x] 本文件旧注释「拖拽改 priority 暂不实现」与代码矛盾，已纠正；`kanban_view.dart` 的 diff 只落在 `///` 行
      （`git diff origin/develop...HEAD -- lib/features/task/views/kanban_view.dart` 全为 `+///`/`-///`）。
      **注意口径**：这一条只说那一个文件；第 1 轮复核抓到整个 commit 还混进了 `pubspec.lock`，见下方处置。
- [x] 七处源页引文逐字命中（python 扫 `02-看板视图：分类管理任务.md`）：`:14/:64/:99/:100/:101/:108/:115` **全部 OK**，行号与 spec 表一致
- [x] 六项门禁（**终态日志 `/tmp/r45_gates_final.log`**，首行 `head=37528da`、`status_before_gates=[]` ⇒ 跑在已提交的干净树上；下表数字即该日志原文）
  | 门禁 | 结果 |
  | --- | --- |
  | 1 `git diff --check` | `rc=0`、无输出 |
  | 2 `dart format --output=none --set-exit-if-changed lib/features/task/views/kanban_view.dart` | `Formatted 1 file (0 changed) in 0.01 seconds.`、`rc=0` |
  | 3 `flutter analyze` | `No issues found! (ran in 2.1s)`、`rc=0` |
  | 4 `flutter test --tags golden` | `00:03 +9: All tests passed!`、`rc=0`（9 张基线未重录） |
  | 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:11 +709 ~26: All tests passed!`、`rc=0`。计数 = develop 基线 709，本轮**没加用例**（无行为改动），所以数字不动是预期的，不是漏跑 |
  | 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |
  **rc 口径**：3/4/5/6 各跑两遍 —— 一遍 `\| tail -1` 留末行输出（退出码是 tail 的，不可信），一遍把输出丢弃单取 `$?`。
  **两份日志的关系**：`/tmp/r45_gates.log` 是修复前那一次，首行只记 `head=a1d7733` 而树上还挂着未提交编辑 ⇒
  正是它让 `pubspec.lock` 漏进提交（复核 finding 1）。上表数字已全部换成终态那一次；
  旧日志的 `00:04 +9` / `ran in 3.7s` / `02:14` 只是同一棵树的计时抖动，测试计数一致。
  本次六个 `rc=` 全为 0，且门禁跑完后 `lock_pubdev=149 lock_mirror=0`（本机镜像没有覆盖回来）。

## 仍缺（不谎称完成）
- [ ] 看板**列定义未绑定 `TodoTaskSection`**：列只认 `orderedColumnIds` 那一套固定列 id（四列顺序可由
      `boardPreference` 重排，但 id 词汇被 `board_preference_repository.dart:58`/`:226` 锁死），
      所以 `:99`「当然，你还可以根据需求创建不同类别的分组：」与 `:100`「- 按主题：英语、政治、专业课…」讲的按主题建分组，在看板上不成立（清单里能建分组，看板上看不见也选不了）。矩阵 #15 的判定因此**不因本轮而翻**。
- [ ] 看板列头无「···」管理入口（源页 `:108`/`:115` 的看板侧），分组改名/删除后列标题如何回显未定义
- [ ] 「拖到未分组」的落库语义未定（嘀嗒没写，不猜）
- [ ] 四件套本轮**不适用**（无新增界面）；做上面那条时必须补：320px+1.3 倍、读屏语义、失败保留已加载数据、过期响应不覆盖新响应

## 一处自我更正要写在台面上
初判「看板自定义分组缺后端契约」→ 立了 `zh-cloud-service` Issue #282，**错了**：
`TodoTaskSection` 就是那个实体，CRUD 在 develop 已通，我立的是重复契约。
错因是把「矩阵 #15 的证据里只提到 `todo_board_preference`」当成了「不存在分组实体」，
且第一次 `git grep 管理分组` 之前我就先写下了"0 命中"的判据 —— 实际是 1 命中，而那一处正是反证。
⇒ 已在 #282 里撤回并关闭。规则重申：**先跑判据，再写判据的结论。**

## 第 1 轮只读复核处置（`VERDICT: FAIL`，5 条 findings）
复核手段替换：本机 `claude` CLI 不可用（`unrecognized_model`），改由本会话的只读子代理审本轮 FR。
5 条 findings 我逐条回源复验（`git diff --name-only`、`git show HEAD:` 配 `grep -n`、`git grep origin/develop`），
**全部成立并已全部修**，无一条拒绝：

| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | `pubspec.lock` 混进了 `eca4224`（227+/219-），把 149 处 `url: "https://pub.dev"` 全改成 `pub.flutter-io.cn` | `git diff --stat origin/develop...HEAD -- pubspec.lock` 与两侧 `grep -c` 逐一吻合 | 已把 `pubspec.lock` 还原到 merge-base 内容并单独提交；PR 文件表恢复为本轮应有的 4 个文件。错因见下「门禁跑在提交前的树」 |
| 2 | BLOCKING | 新注释自指 `:33`，但注释自己把那一行推到 `:44`；`spec.md:17` 的「本文件自己的 `:398`/`:540`」在 PR 分支上是 `:409`/`:551` | `git show HEAD:…kanban_view.dart \| grep -n` → `44` / `409` / `551`；`origin/develop` → `33` / `398` / `540` | 文件头注释**删掉对本文件行号的引用**，改指符号名 `KanbanView.orderedColumnIds`（自身注释必然随自己漂移，行号在这里永远不可靠）；`spec.md` 保留 develop 行号但显式标 `a1d7733`，并把漂移 +11 写在正文里 |
| 3 | NIT | `orderedColumnIds` 不是「写死」 | `tasks_by_list_page.dart:338` 传 `boardPreference.orderedColumnIds`；`board_preference_repository.dart:16` 有 `defaultColumnIds`、`:58`/`:226` 用它过滤 | 措辞改准：**四列顺序可重排，列 id 词汇锁死** ⇒ 建不出新列。结论（`:99`-`:101` 在看板上不成立）不变 |
| 4 | NIT | `spec.md:25` 把 widget Key 当端点说 | `todo-section-create` 是 `tasks_by_list_page.dart:1840` 的 `Key` | 改引真正的实体与同步通道：`app_database.dart:51`/`:1048` 的 `TodoTaskSection` + `sync_entities.dart:5`/`:31` 的 `task_section`（我自己 `grep` 复验过，非照抄复核员），并加一句措辞提醒 |
| 5 | NIT | 门禁日志首行 `### head=a1d7733 工作树`，即跑在**未提交**的编辑上；且日志里有 `flutter_lints` 解析告警 | 日志首行与 mtime（18:36）早于 commit（18:37:13）吻合 ⇒ 这正是 #1 漏进来的机制 | 接受第 1 半：新日志首行标 `head=` **与工作树 diff 状态**，且门禁跑在已提交终态之后。第 2 半**不成立**：`Failed to resolve package URI` 只出现在日志第 6 行、即 `### gate2`（`dart format`）段内，`dart format` 不需要 lint 规则集，不影响 `Formatted 1 file (0 changed)`；`### gate3`（`flutter analyze`）段无任何告警，`No issues found!` 未被削弱。此条按「定位错段」记录，不改结论 |

## 门禁跑在提交前的树 —— 机制要写清，不然下次还犯
objective 第 2 条早就点名 `pubspec.lock` 会被本机镜像整树重解析改脏、不随功能 PR 提交。
这次仍漏进 commit，原因不是「忘了规则」而是**顺序**：我是「改完 → 跑六项门禁 → commit」，
而 `flutter test`/`build web` 内部会 `pub get` 重写 `pubspec.lock`，于是 `git add` 时它已是脏的。
⇒ 正确顺序：**改完 → commit → 在已提交的终态上跑门禁 → 若门禁把 `pubspec.lock` 改脏则 `git checkout HEAD -- pubspec.lock` 还原**。
本轮按此重跑，日志见 `/tmp/r45_gates_final.log`。

