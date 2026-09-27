# 第 112 轮台账 — FL #384 四象限「隐藏已完成」（specs/060，矩阵 #36 ⑩）

- 仓库 / 分支：`zh-cloud-todo-flutter` `feat/384-quadrant-hide-completed`，基线 `origin/develop@9032005`
- 提交：`a37c7b2`（4 个 lib + 1 个 test）、`67d077c`（按交叉验证删掉一条冗余用例）、本笔台账
- 上一批（第 111 轮 PR !383）状态：`open` ⇒ 本轮不引用它的任何 SHA 作为"已合并"证据；
  它和本单**改的是同一个文件** `eisenhower_view.dart`，所以合并顺序上 !383 先来（下面 §七 记了冲突面）。

## 一、落地的三面（判据 `:131`/`:132`，见 `spec.md` §一）

1. 入口：`todo-sort-menu` 里加「隐藏已完成」（`task_workspace_header.dart:208-236`），
   默认隐藏（`tasks_by_list_page.dart:96`），只在四象限视图出现（其余四个视图该项不存在）。
2. 取数：`quadrantShowsCompleted`（`eisenhower_view.dart:396-399`）——清单筛选钉过完成态时以筛选为准，
   四象限不叠第二道闸；两处 `completed` 丢弃（`:176` 本机分档、`:224` 远程分档）与宿主
   `_reportInvalidSelection`（`tasks_by_list_page.dart:1385-1388`）都读这一个尺。
3. 持久化：`getQuadrantDisplay` / `saveQuadrantDisplay`（`task_view_action_repository.dart:147-162`），
   sourceType `quadrant_view`，与 develop 上既有的 `calendar_view` 同类 ⇒ **没有新增后端契约**。

## 二、六道门禁（全部跑在最终字节 `67d077c` 上，日志 `/tmp/r112/`）

| # | 命令 | 读数 | 日志锚 |
| --- | --- | --- | --- |
| 1 | `git diff --check` | rc=0 | `/tmp/r112/g1-check.log:2` |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 5 个文件>` | `Formatted 5 files (0 changed)` ⇒ rc=0 | `/tmp/r112/g2-format-rerun.log:2-3` |
| 3 | `flutter analyze --no-pub` | `No issues found!` rc=0 | `/tmp/r112/g3-analyze-final.log:3-4` |
| 4 | `flutter test --tags golden` | `+9: All tests passed!`；基线 png `9` 张、`git status --short test/goldens` 0 行 ⇒ 没重录 | `/tmp/r112/g4-golden-final.log:76-79` |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `+914 ~26: All tests passed!` rc=0 | `/tmp/r112/g5-full-final.log:1173-1174` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0，跑完 `git status --short pubspec.lock` 空行 ⇒ 没把本机镜像扫进 PR | `/tmp/r112/g6-build-final.log:80-81`、`:83` |

⚠️ 门禁跑了两遍这件事要按事实记：第一遍（`g3-analyze.log` / `g4-golden.log` / `g5-full.log` / `g6-build.log`）
跑在"删掉那条冗余用例但还没 `dart format`"的字节上，格式化确实改了字节（`cmp` 判不等），
所以 g3-g6 在 `67d077c` 上**重跑**了一遍，上表引的是 `*-final.log`。
复算：`git rev-parse --short HEAD` ⇒ `67d077c`。

本面用例计数与两条独立互证：`flutter test test/features/task/eisenhower_hide_completed_test.dart` ⇒
`+16: All tests passed!`（`/tmp/r112/g-test-6.log:65`）。全量 `+914` = develop 基线 `898` + 本面 `16`；
第 111 轮同一 develop 基线上报的是 `+913` = `898 + 15` ⇒ 两个分支的差值互相咬住基线，不是各抄各的数。

## 三、反向探针（脚本 `/tmp/r112/probes.py`，只改**实现**字节，跑完还原并 `filecmp` 逐字节核对）

| 探针 | 改坏的地方 | 实际红掉的用例 | 日志 |
| --- | --- | --- | --- |
| P1 | `quadrantShowsCompleted` 去掉"以筛选为准"那一支 | 2 条：纯函数那条 + 页面「清单已按完成态筛过」 | `/tmp/r112/probes.log:1-3` |
| P2 | 菜单项 `enabled` 写死 `true` | 2 条：页面置灰那条 + 组件层正反对照那条 | `/tmp/r112/probes.log:4-6` |
| P3 | 视图两处 `completed` 丢弃条件摘掉（永远显示） | 4 条：含「默认已完成不出现在任何象限」这条回归防线 | `/tmp/r112/probes.log:7-11` |
| P4 | 宿主 `_reportInvalidSelection` 退回"四象限一律丢已完成" | 1 条：新增的选中态失效那条 | `/tmp/r112/probes.log:12-13` |

哨兵：`/tmp/r112/probes.log:14` ⇒ `PROBE-BAD=0`；`/tmp/r112/porcelain-after-probes.log:1` ⇒ 探针跑完工作树只剩本单自己的两处改动
（测试文件 + specs 目录），没有探针残留。

## 四、交叉验证（`cursor-agent --trust`，日志 `/tmp/r112/crosscheck-384b.out`，6005 字节，末行 `CROSSCHECK: DONE`）

| 它的判断 | 我的处置 |
| --- | --- |
| D.1「反向对照：判据不是恒真」那条用例与上一条同输入、只把 `isTrue` 换成 `isNot(isFalse)`，不提供独立失败信号 | **采纳**：删掉（`67d077c`），本面 17 → 16 条；该支的真判据本来就由 P1 提供（改坏实际红 2 条，`/tmp/r112/probes.log:1-3`） |
| D.2 两条 320px 用例里 `pumpAndSettle` 之后的 `expect(tester.takeException(), isNull)` "基本恒真" | **驳回**：溢出是布局期抛给 flutter_test 的错误记录，不会在 `pumpAndSettle` 处抛出；这条断言正是把它转成失败信号的口子。P3 改坏实现时「默认隐藏已完成」那条真红（`/tmp/r112/probes.log:8`），说明这条用例不是死重 |
| E 附注：`saveQuadrantDisplay` 不交 `viewType` ⇒ 行内 `viewType` 兜底成 `'list'` | **记为已知偏差**（§六 第 3 条），不改代码：四象限这一面没有"视图模式"这个轴，硬塞一个模式名反而是在造一个不存在的状态 |
| A 置灰 + 原因文案"相对原文是加码，相对本仓 spec 不算越界"；B「用户看得见开关却点不动」的风险成立但已被副文案 + 读屏同句缓解 | 采纳其判据顺序：置灰比"直接隐藏菜单项"更贴近 `:132`「右上角『...』里**有**这一项」的形态（`spec.md` §三 2 方案 A 不变） |

## 五、本轮自己抓到、并修掉的错（不写"顺手改好了"，逐条给现象）

1. **两条断言我写错了对象**，不是实现缺陷：`expect(queued.length, 1)` 与 `expect(rows, isEmpty)`
   都被"切到四象限"那一下既有行为污染（宿主 `_changeMode` 自己会写一行 `task_view` 偏好并入队一次）。
   复算出来的实际值是 outbox `2` 行、偏好表 1 行 `sourceType: task_view` ⇒
   改成只数量含 `quadrant_view` 的那一条。**先证明判据写错，再动实现**这条顺序守住了，两处都没去"顺手改实现"。
2. `Duration.zero` 写成 `const Duration.zero` ⇒ 解析失败（它是静态字段不是 const 构造器）。
3. `excludeSemantics` 挂到 `Text` 上 ⇒ 编译错；它是 `Semantics` 的属性（放在后代那一侧）。
4. 测试辅助函数把 `tester` 写成位置参数、调用处写 `tester:` ⇒ 报的是"Too few positional arguments"，
   看着像实现问题，其实是自己的签名不一致。
5. Drift 伴随类名记错：`TodoTaskCompanion` ⇒ 真实是表名复数 `TodoTasksCompanion`
   （复算 `grep -n "class TodoTasksCompanion" lib/core/db/app_database.g.dart` ⇒ 命中，数据类才是单数 `TodoTask`）。
6. 页面级用例少了仓内既有的收尾排水步骤（`pumpWidget(SizedBox.shrink())` → `pump()` →
   `container.dispose()` → `pump(Duration.zero)` → `db.close()`，同 `task_section_workspace_test.dart:87-90`）⇒
   9 条页面用例全红在 `A Timer is still pending`，报错长得像"页面有动画没停"，
   栈里第 6 帧 `StreamQueryStore.markAsClosed` 才说明是 Drift 关流的零延时定时器。
7. 探针脚本自己先崩过一次：用了不存在的 `shutil.cmp`；第二版 P4 的锚点又是按格式化**之前**的字节写的
   ⇒ `assert 命中 0` 挡住没跑出红（脚本在写盘前 assert，所以没留下改坏的树）。这两条都是"探针没跑成"，
   不能当"实现没问题"的证据 —— 第三版才拿到 §三 那 4 行读数。

## 六、仍缺 / 已知偏差（不藏）

1. **`!383` 未合并**：两单都改 `eisenhower_view.dart`（!383 在 `_QuadrantTile` 外层包 `DragTarget`/`LongPressDraggable`，
   本单改同文件的分类函数与构造参数）。本轮测试跑在未含 !383 的 develop 基线上，
   合并 !383 之后本单的字节需要在它之上重跑一遍门禁。
2. 四象限的完成态显隐**只有这一条路径**（菜单项）：源页本节没写键盘/右键的替代入口，
   与 !383 那条"只有拖动"的可达性缺口是同一族问题，留给下一个 Issue，不在本轮偷偷补。
3. 偏好行的 `viewType` 兜底值 `'list'`（§四 E 附注）：四象限没有模式轴，这列对本面无语义。
4. 菜单项**没有**"当前已隐藏/已显示"的勾选图形，只有文字 + 读屏语义里的档位（`隐藏已完成，当前已隐藏`）；
   图形勾选要做成什么样，源页本节没给 ⇒ 不自创。

## 七、只读复核（VERDICT）

- 状态：**未达成**。派单在 PR 开出来之后，审的是 `git diff origin/develop..HEAD` 的最终 ref；
  判据只认结果块里以 `VERDICT:` 开头的行（不整份 grep，避免命中提示词回显造出假 PASS）。
  结论回来前，本节与矩阵行的"复核"格都算欠账。

## 八、下轮入口

1. 本轮 PR 的 VERDICT 回来后回写 §七；矩阵 #36 ⑩ 在合并前只写"已实现、未合并"。
2. 合并顺序：!383（拖动）在前，本单在后 —— 同文件，`git merge-tree` 的试算结果要在 !383 落地后重跑。
3. specs/061：年视图「点击日期 → 周视图并高亮」（矩阵 #28 剩的一格，判据 `:64`）。
4. 队列项 ①（service !291）本轮已把第 3 轮续的 `VERDICT: PASS` 与两条 NIT 回写台账并推上去，
   剩下的仍是等「合并」二字。
