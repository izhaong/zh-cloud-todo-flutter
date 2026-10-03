# 任务清单：重复任务「法定工作日 / 法定节假日」两档接线

基准提交：分支 `feat/324-legal-repeat`，起点 `origin/develop@603038133d90`（FL schema v26）。
下列行号以该起点之上的本分支工作树为基准。

## 实现

- [x] 白名单两档：`lib/state/repositories/repeat_rule_repository.dart:246`、`:248`
- [x] 选择器档位（顺序照文档分组）：`lib/features/task/task_detail_pane.dart:2099` 法定工作日、
      `:2101` 法定节假日（分别紧跟在「工作日」「每周末」之后）
- [x] 详情面文案表 `_repeatRuleLabel`：`lib/features/task/task_detail_pane.dart:2434`、`:2436`
- [x] **故意不派生星期集**：`repeat_rule_repository.dart:304` 只有说明注释、没有 `if (frequency == 'LEGAL_*') return [...]`
- [x] wire 映射单一事实源：新增 `lib/core/sync/repeat_frequency_wire.dart`（`toWire` / `fromWire`），
      三个消费点各一处：`repeat_rule_repository.dart:341`（出库 payload）、
      `sync_coordinator.dart:1793`（入站归一）、`task_detail_pane.dart:2107`（chip key）
- [x] 测试：`test/state/repeat_rule_legal_repository_test.dart` 6 条（两档被接受、不派生星期集、
      老档位不倒退、出库 wire 值、未知档位仍被拒、`interval` 口径）、
      `test/features/task/task_repeat_legal_test.dart` 4 条（档位可选并出库、读回中文而非裸枚举、
      320px + 1.3 倍字号、读屏名字）、`test/core/sync/repeat_frequency_wire_test.dart` 4 条
      （两档连字符、老档位形状不变、入站归一与缺省、往返恒等）

## 四件套（新 UI 逐条量，不写"不适用"）

- [x] **320px 宽 + 1.3 倍字号**：`task_repeat_legal_test.dart` 的
      `320px 宽 + 1.3 倍字号：两档 chip 仍在同一张档位表里且可点`
      —— 在档位表所在的「任务详情 → 日期、提醒与重复 → 重复规则弹窗」这条真实路径上量，
      逐档 `ensureVisible` 后断 `findsOneWidget`、`RenderBox.size.width <= 320`、`takeException()` 为空
- [x] **读屏可念**：`两档都有能被读屏念出的中文名` 读带 key 节点自己的 `getSemantics(...).label`
      （不是全树 `bySemanticsLabel`），断含「法定工作日」「法定节假日」
- [x] **失败保留已加载数据**：本轮没有新增写路径——保存仍走 `RepeatRuleRepository.save` 的单个 Drift 事务
      （规则行 + outbox 同事务），失败时 `task_detail_pane.dart:1970` 的 `on ArgumentError` 只提示不动 `_repeatRule`。
      新增两档在本地一定通过白名单，不会把这条通路带进新失败态（反向证据：仓储用例
      `未知档位仍然被拒` 量的是白名单仍然拦未知值，两档不在此列）
- [x] **过期响应不覆盖**：档位写库与出库在同一事务内（既有实现，本轮未改），
      入站归一只在 `sync_coordinator` 的 upsert 分支里做形状转换，不引入"后到覆盖先到"的新路径

## 门禁（在最终字节上现跑现读）

见本文件末尾「门禁读数」；跑之前不构成任何通过声明。

## 本轮改动拉长出来的既有债（认账，不是"不适用"）

1. `dart format lib test` 顺手改了 10 个无关文件（`lib/features/home/sync_recovery_banner.dart`、
   `lib/state/repositories/task_section_repository.dart` 与 8 个测试文件），已逐个 `git checkout --` 还原，
   最终 `git status --porcelain` 只剩本轮 3 改 + 3 新增 + 台账。这是同一颗坑第 N 次踩（原地格式化必带旁路改动），
   以后只对本次触碰的文件跑 `dart format <paths>`。

## 欠账（如实登记）

1. 两档的**命中判定全在服务端**，客户端离线时选了也不会自己生成任务——这是既有架构（occurrence 由服务端物化），
   不是本轮引入；但用户离线时的观感是"选了没反应"，要改善得另有离线预告，未立单。
2. 入站映射的调用点已补行为级用例，走 `pull()` 那条路进来，条数复算 `grep -c "^  test(" test/sync_coordinator_repeat_legal_test.dart` ⇒ 3。
   这条是先实测到覆盖漏洞再补上的：补之前同一变异全绿（探针 q3），补之后才红（探针 q3b）。
   剩下的口子：假服务端只喂 `repeat_rule` 一种实体，没有与 `task` 变更同批下发的混合场景。
   这条是**先实测到覆盖漏洞再补上的**：补之前同一变异全绿（探针 q3），补之后才红（探针 q3b）。
   剩下的口子：假服务端只喂 `repeat_rule` 一种实体，没有和 `task` 变更同批下发的混合场景。
3. VERDICT 复核通道取不到（0 字节），本轮记「未经独立复核」；`tool/check_spec_selfscan.py` 只接单个文件参数，
   两份台账要分别跑，结果记在「门禁读数」。

## 下一轮入口

- 矩阵回写（本轮 FL 合并后立刻做）：`zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 的 `#24` 行面 ⑥，
  按「service `641aa0768ba2` + FL 本轮合并 SHA」改判；主表行整行 8 段、说明格在下标 5。
- FL #329 拖拽半面（标签自定义排序）：`todo_tags` 缺 `sort_order` 列，服务端 `sortOrder` 已有 ⇒ 纯客户端轮。
- FL #325（农历 ⑦）/#326（艾宾浩斯 ⑧）：面 ⑦ 需要先定数据源（农历在服务端算还是客户端 `lunar` 包），
  别再顺手造第二套事实源（本轮 service 侧刚踩过一次，见 specs/027）。
- 父仓 `zh-cloud` submodule pin bump（FL develop 前进后另开 PR，走 plumbing 不碰工作树）。

## 门禁读数（最终字节上的一次性运行，日志名逐条给出）

- `dart format --output=none --set-exit-if-changed <本轮 8 个文件>` ⇒ `rc=0`、`Formatted 8 files (0 changed)`
  （先跑过一次带 `--output=none` 的检查：它只报不改，`test/core/sync/repeat_frequency_wire_test.dart`
  当时被报 `Changed` 而字节没动 ⇒ 必须先 `dart format <file>` 写盘，再拿 `--set-exit-if-changed` 当门禁）
- `flutter analyze` ⇒ `rc=0`，`No issues found!`（`/tmp/r215-analyze3.log`）
- `flutter test`（全量，含 golden 之外的全部）⇒ `rc=0`，`+1430 ~26: All tests passed!`（`/tmp/r215-fulltest3.log`）
  其中本轮新增 17 条 = 仓储 6 + UI 4 + helper 4 + 入站 3；补入站用例前同一条命令量到的是 `+1427 ~26`（差 3，正好是新用例数）
- `python3 tool/check_spec_selfscan.py specs/083-legal-repeat/spec.md` ⇒ `rc=0`、`失项 0 条`（`/tmp/r215-scan-spec.log`）
- `python3 tool/check_spec_selfscan.py specs/083-legal-repeat/tasks.md` ⇒ `rc=0`、`失项 0 条`
  （这条是本轮台账**改完之后**复跑的：先前它报过 2 条量词失项——「3 条」与「四条反向探针」旁边没有可复跑命令，补上命令并改成五条探针记录后才归零，日志 `/tmp/r215-scan-tasks.log`）
- `claude -p` 只读复核 VERDICT：未取到（本机该通道近期持续 0 字节）⇒ **本轮未经独立复核**，
  以「门禁 + 五条探针记录 + 全量绿」替代（复算 `grep -c '^| q' specs/083-legal-repeat/tasks.md` ⇒ 5）

## 反向探针（每条独立备份→变异→跑→还原→`cmp -s`）

| 探针 | 变异 | 结果 | 红在哪条 |
| ---- | ---- | ---- | -------- |
| q1 派生星期集 | 在 `WEEKEND` 那行后面补 `if (frequency == 'LEGAL_WORKDAY') return const [1, 2, 3, 4, 5];` | `rc=1`，`+8 -2` | `两档不派生星期集：byDay 必须为空（这是本轮的支点）`、`档位表里有「法定工作日」与「法定节假日」，选前者出库带 legal-workday` |
| q2 出库退回 `toLowerCase()` | `repeatFrequencyToWire(row.freq)` → `row.freq.toLowerCase()` | `rc=1`，`+8 -2` | `出库 payload 用小写连字符，与服务端枚举 wire 值一致`、`档位表里有「法定工作日」与「法定节假日」，选前者出库带 legal-workday` |
| q3 入站退回 `.toUpperCase()`（**补用例前**） | `repeatFrequencyFromWire(...)` → 基线的 `.toUpperCase()` 写法 | `rc=0`，`+14 ~13 All tests passed` | 无——量到的是覆盖漏洞，不是实现正确 |
| q3b 同一变异（**补用例后**） | 同上 | `rc=1` | `入站 legal-workday 归一成 LEGAL_WORKDAY，且不落星期集`，失败原文 `Expected: 'LEGAL_WORKDAY' / Actual: 'LEGAL-WORKDAY'` |
| q4 文案表漏一档 | 删掉 `'LEGAL_HOLIDAY': '法定节假日',` 这一行 | `rc=1`，`+3 -1` | `保存后详情面读回「法定节假日」而不是裸枚举` |

q3 这一条值得留着：helper 单测 + 出库用例 + `b1_live_sync_e2e_test.dart` 全绿，说明
**"映射函数有测试"不等于"调用点有测试"**。补了 `test/sync_coordinator_repeat_legal_test.dart` 之后同一变异才红。
