# 任务台账：提醒侧时间模式三档（FL Issue #373）

基准：本分支 `feat/373-reminder-time-mode-ui`，起点为 FL `origin/develop`。
矩阵行：zh-cloud-docs `todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 第 12 行「时间模式」的提醒这一面。

## 已完成

- [x] 提醒表加 `time_mode` 列，取值与服务端一致。复算命令
  `grep -n "IntColumn get timeMode" lib/core/db/app_database.dart` 现读 2 命中（94 行任务表、232 行提醒表）
- [x] `schemaVersion` 进到 24，迁移分支只在列不存在时加列并回填。复算命令
  `grep -n "if (from < 24)" lib/core/db/app_database.dart` 现读 1 命中（685 行），回填语句在 `lib/core/db/app_database.dart:691`
- [x] 仓储 `create` / `update` 收 `timeMode` 入参并按旧布尔位推导。锚点
  `lib/state/repositories/reminder_repository.dart:33`、`lib/state/repositories/reminder_repository.dart:91`
- [x] 同步出站 payload 带档位。锚点 `lib/state/repositories/reminder_repository.dart:201`
- [x] 提醒编辑器把布尔开关换成按档位编号的单选组，副标题照抄嘀嗒措辞。锚点
  `lib/features/task/task_detail_pane.dart:451`（控件）与 `lib/features/task/task_detail_pane.dart:108`（文案函数）
- [x] 草稿档位真正传给写库调用。锚点 `lib/features/task/task_detail_pane.dart:278`
  这一笔是本轮的红测抓出来的：控件选了档、写库仍按旧布尔位反推，「固定时区」会被落成「固定时间」
- [x] 新增用例落在 `test/features/task/reminder_time_mode_test.dart`，档位入库存取在
  `test/features/task/reminder_time_mode_test.dart:91`，旧布尔位推导在
  `test/features/task/reminder_time_mode_test.dart:103`，选档写库在
  `test/features/task/reminder_time_mode_test.dart:117`，档位 1 不被反推在
  `test/features/task/reminder_time_mode_test.dart:150`，窄屏与 1.3 倍字号在
  `test/features/task/reminder_time_mode_test.dart:169`，失败可见与不半写在
  `test/features/task/reminder_time_mode_test.dart:192`
- [x] 迁移回填用例 `test/app_database_migration_test.dart:745`，复算命令
  `flutter test test/app_database_migration_test.dart --concurrency=1` 现读 `+13: All tests passed!`

## 反向对照（证明判据在Binding）

把 `lib/features/task/task_detail_pane.dart:278` 那一行删掉后现跑
`flutter test test/features/task/reminder_time_mode_test.dart --concurrency=1`
读回 `+5 -1`，失败原因正是「界面选了「固定时区」，写库却按旧布尔位反推成「固定时间」= 档位丢了」；
还原该行的同一条命令读回 `+6: All tests passed!`（`test/features/task/reminder_time_mode_test.dart:150` 这条用例负责量它）。

## 四件套

- 窄屏与字号：320×640 加 1.3 倍字号下两个档位节点都完整在视口内且点得动，
  判据在 `test/features/task/reminder_time_mode_test.dart:169`
- 失败可见：更新抛错时给出可见原因且库里没有半写档位，判据在
  `test/features/task/reminder_time_mode_test.dart:192`
- 独立读屏语义：**已补判据（第 187 轮）**。带 key 的那个语义节点要同时带这一档自己的「标题 + 嘀嗒副标题」label 与选中态，判据在 `test/features/task/reminder_time_mode_test.dart:172`；实现形状是 `Semantics(key:…, selected:…, label:…)` 包住 `RadioListTile`，锚点 `lib/features/task/task_detail_pane.dart:469` 与 `lib/features/task/task_detail_pane.dart:391`
- 过期响应不覆盖新响应：本面写的是本地 Drift、不存在异步回包覆盖，未立判据

## 六道门禁（最终字节上各跑一次）

| 序 | 命令 | 现读 |
| --- | --- | --- |
| 1 | `git diff --check` | rc=0、无输出 |
| 2 | `dart format --output=none --set-exit-if-changed` 后接本轮 9 个显式文件 | rc=0、`Formatted 9 files (0 changed)` |
| 3 | `flutter analyze` | rc=0、`No issues found!` |
| 4 | `flutter test --tags golden` | rc=0、`+9: All tests passed!`，`test/goldens` 无改动（基线未重录） |
| 5 | `flutter test --exclude-tags 'golden   performance' --concurrency=1` | rc=0、`+1337 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | 见下节 |

第 5 道那条命令里的 `||` 在表格里会被当成单元格分隔符，读的时候请按 shell 原文
`flutter test --exclude-tags 'golden || performance' --concurrency=1` 复算。

## 复核与合并前置

- 只读复核（`claude -p` 通道）本轮未取到结论：派单输出 0 字节，属通道故障而非「无意见」⇒
  不声称复核通过，只报六道门禁实测与上面的反向对照。
- 合并试算见 PR 正文。

## 遗留

- 服务端触发时刻换算调用方仍缺（zh-cloud-service Issue #302 的算法面），矩阵第 12 行因此保持「部分」。
- 「独立读屏语义」这条判据已由第 187 轮补上（见上一节），矩阵该行仍差的只剩后端算法面调用方。

## 第 187 轮：形状实验与反向对照（FL Issue #444）

形状实验（同一份 `RadioGroup` 里并排三种写法，读 `getSemantics(find.byKey(…))`）现读：
key 放包壳且不写 label ⇒ 该节点 `label` 为空、选中态也没进来；key 留在 `RadioListTile` 上、包壳不带 key ⇒ 节点有 label 但 `isSelected` 恒 `Tristate.isFalse`；
key 与 label 都在包壳上（本轮采用的形状）⇒ 同一个节点读到 `flags: [isSelected, hasSelectedState]` 与 `label: "固定时间\n不论所处时区如何变化，任务的时间都会保持一致"`。
实验还否掉两条旧候选：`RadioListTile.selected` 这条 SDK 属性不顶用，「改判 `Radio` 的 `isChecked`」也无面可读（`CHK` 恒 `CheckedState.none`）。

反向对照：删掉 `lib/features/task/task_detail_pane.dart:469` 这一行后现跑
`flutter test test/features/task/reminder_time_mode_test.dart --concurrency=1` 读回 `+6 -1`，
失败的那条正是「选中态要落在带 key 的那个读屏节点上，屏幕阅读器念得出当前档」；还原后同一条命令 `+7`（含显隐那两条一起跑为 `+9`）。

六道门禁在补判据后的最终字节各跑一次：`git diff --check` 无输出；`dart format --output=none --set-exit-if-changed` 两个显式文件 `0 changed`；
`flutter analyze` `No issues found!`；`flutter test --tags golden` `+9: All tests passed!`（`test/goldens` 无改动、基线未重录）；
非 golden 全量 `+1342 ~26: All tests passed!`；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。
只读复核通道 `claude -p` 仍输出 0 字节 ⇒ 未取到 VERDICT，本节与 PR 正文都不声称复核通过。
