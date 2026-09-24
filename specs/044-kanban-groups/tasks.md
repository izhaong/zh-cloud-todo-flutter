# 044 任务清单

## 已证实
- [x] 「跨列拖动」这一面在 develop 上**有实现且有测试**：`kanban_view.dart:540`/`:398` + `tasks_by_list_page.dart:380`，测试 `task_workable_views_test.dart:14`/`:56` ⇒ 源页 `:64` 成立
- [x] 「管理分组」的实体与 CRUD 在 develop 上**已存在**：`tasks_by_list_page.dart:1829`-`:1862`（`todo-section-create`、rename/up/down/delete、tooltip `:1849`「管理分组 <名称>」）⇒ 源页 `:115` 的清单侧入口成立
- [x] 本文件旧注释「拖拽改 priority 暂不实现」与代码矛盾，已纠正；`git diff` 只落在 `///` 行（见下"改动面"）
- [x] 七处源页引文逐字命中（python 扫 `02-看板视图：分类管理任务.md`）：`:14/:64/:99/:100/:101/:108/:115` **全部 OK**，行号与 spec 表一致
- [x] 六项门禁（终态一次跑完，日志 `/tmp/r45_gates.log`；跑两遍的原因见「rc 口径」）
  | 门禁 | 结果 |
  | --- | --- |
  | 1 `git diff --check` | `rc=0`、无输出 |
  | 2 `dart format --output=none --set-exit-if-changed lib/features/task/views/kanban_view.dart` | `Formatted 1 file (0 changed)`、`rc=0` |
  | 3 `flutter analyze` | `No issues found! (ran in 3.7s)`、`rc=0` |
  | 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（9 张基线未重录） |
  | 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:14 +709 ~26: All tests passed!`、`rc=0`。计数 = develop 基线 709，本轮**没加用例**（无行为改动），所以数字不动是预期的，不是漏跑 |
  | 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |
  **rc 口径**：3/4/5/6 各跑两遍 —— 一遍 `\| tail -1` 留末行输出（退出码是 tail 的，不可信），一遍把输出丢弃单取 `$?`。

## 仍缺（不谎称完成）
- [ ] 看板**列定义未绑定 `TodoTaskSection`**：列写死在 `kanban_view.dart:33`，所以 `:99`-`:101` 的「按主题自定义分组」在看板上不成立（清单里能建分组，看板上看不见也选不了）。矩阵 #15 的判定因此**不因本轮而翻**。
- [ ] 看板列头无「···」管理入口（源页 `:108`/`:115` 的看板侧），分组改名/删除后列标题如何回显未定义
- [ ] 「拖到未分组」的落库语义未定（嘀嗒没写，不猜）
- [ ] 四件套本轮**不适用**（无新增界面）；做上面那条时必须补：320px+1.3 倍、读屏语义、失败保留已加载数据、过期响应不覆盖新响应

## 一处自我更正要写在台面上
初判「看板自定义分组缺后端契约」→ 立了 `zh-cloud-service` Issue #282，**错了**：
`TodoTaskSection` 就是那个实体，CRUD 在 develop 已通，我立的是重复契约。
错因是把「矩阵 #15 的证据里只提到 `todo_board_preference`」当成了「不存在分组实体」，
且第一次 `git grep 管理分组` 之前我就先写下了"0 命中"的判据 —— 实际是 1 命中，而那一处正是反证。
⇒ 已在 #282 里撤回并关闭。规则重申：**先跑判据，再写判据的结论。**
