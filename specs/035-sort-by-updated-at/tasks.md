# tasks：specs/035 工作区排序补「修改时间」档

分支 `feat/todo-sort-by-updated-at`，基线 `develop@a1d7733`。矩阵行：#20（可达性聚合行 `| 14 / 15 / 16 / 20 / 21 / 23 / 24 |` 的「仍缺」项之一）。
Gitea：Issue #285 / PR !286 / 服务端债 izhaong/zh-cloud-service#273 / 矩阵 `zh-cloud-docs@9409531`（PR !69）。

## 任务清单

- [x] **T001 缺口取证**：读嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》与矩阵 #20。
      本端 `enum TaskSort` 只有 `smart / priorityDesc / dueDate / title / createdAt` ⇒ 四种排序里缺「按修改时间」。
- [x] **T002 红测先行**：`test/task_sort_updated_at_test.dart` 4 例（复核修复后 5 例），失败信息精确指向缺失档位。
      `/tmp/r15-red.log` 里**实际留下的原文**（该文件是 tail，只有汇总段）：
      `00:00 +0 -4: Some tests failed.` 与四条失败名（档位与文案、按 updatedAt 从新到旧、能存能读、320px + 1.3 菜单）。
      **更正**：我原先在这里写的驱动消息 `Bad state: TaskSort 里没有「updatedAt」这一档` **不在这个日志文件里**
      （`grep -c "Bad state" /tmp/r15-red.log` = 0，第 1 轮复核抓到）—— 那是当时终端里更靠前的逐例输出，
      没被持久化。可复现路径是 `sortByName()`：`TaskSort.values.firstWhere(name == 'updatedAt', orElse: () => throw StateError(...))`。
      ⇒ 结论不变（红测指向缺失项），但**证据文件不支持那句引用**，故按实际内容重写。
- [x] **T003 最小实现（FR-1/2/3）**：只补穷尽 switch 需要的四处 + 一处 case，不新增抽象。
      `task_query_repository.dart:22`（枚举追加在末尾）、`:37`（比较器 `right.updatedAt.compareTo(left.updatedAt)`）、
      `task_workspace_header.dart:16`（同名命令值）、`:28`（映射）、`:41`（label `'修改时间'`）、
      `onSelected` 的穷尽 `switch (command)` 里把 `updatedAt` 并入 `break` 分组（复核实测：整个 `lib/` 只 +7 行）。
- [x] **T004 反向探针**（脚本 `/tmp/r15_probes_v2.py`，日志 `/tmp/r15-probes5.log`，每轮 `cmp -s` 复原三个 lib 文件）：

  | 探针 | 摘掉/改坏的生产代码 | 必须红的用例 | 结果 |
  | ---- | ------------------- | ------------ | ---- |
  | PA | 比较器 `TaskSort.updatedAt => 0` | 用例 2（按 updatedAt 从新到旧） | **首轮 GREEN ⇒ 测试自身缺陷**；改种子后 RED |
  | PB | label 换成同义词 `'更新时间'` | 用例 1（照嘀嗒措辞）+ 用例 5（菜单里可见） | RED |
  | PC | 命令映射 `=> null`（菜单项在但点了不改档） | 用例 5 的 tap 回调断言 | RED |
  | PD | 整条 `_TaskWorkspaceHeaderCommand.updatedAt`（三处协同删除） | 用例 5（`byName` 抛 `ArgumentError` ⇒ 菜单渲染不出来） | RED |
  | PE | `_decode` 丢掉 sync pull 的嵌套分支（`final value = raw['sort']`） | 用例 4 前半（嵌套包装读出 updatedAt） | RED |
  | PF | `firstWhere` 的精确匹配换成 `startsWith` 前缀匹配 | 用例 4 后半（未知名退回 smart） | RED |

  **PA 第一轮为什么是绿的**：用例 2 原本把兜底键 `sortOrder` 种成 touched=0 / created=1，与 `updatedAt` 的期望方向**同向**
  ⇒ 把比较器摘成 `=> 0` 后，兜底链（`sortOrder` → `id`）恰好排出同一个顺序，用例照绿。
  处置：种子改成 touched=1 / created=0（`id` 字典序也指向反向），并在测试里写明理由。
  ⇒ 「数据反着种」不止主键那一列，**所有接得住排序的兜底键都得反向**。
- [x] **T005 四件套（FR-4）**：320×720 + 1.3 倍字体直接泵 `TaskWorkspaceHeader`，在 header 自己的 context
      （`Key('todo-task-workspace-header')`）上自检 `textScaler.scale(10) ≈ 13`；断「修改时间」`findsOneWidget`、
      `bySemanticsLabel` 命中独立节点、tap 后 `onSortChanged` 带出 `updatedAt`、`takeException()` 为 null；
      含 `创建时间` 正对照。「失败保留已加载数据」「过期响应不覆盖新响应」按 spec 声明：本切片 diff 全同步、无对应异步链路，不编造判据。
- [x] **T006 `dart format` 门禁抓到自家新文件不合规**：`/tmp/gate-035.log` 第 2 项
      `Changed test/task_sort_updated_at_test.dart` / `exit=1`（两个 lib 文件 `exit=0`，HEAD 版同检查也 `exit=0`
      ⇒ 不是存量欠债）。只对这一个文件跑 `dart format`（未整仓原地格式化），复跑用例仍绿，并在新字节上重跑全部探针。
- [x] **T007 只读复核拿到 VERDICT 并逐条处置**：见下面「第 1 轮复核处置」。
- [x] **T008 回写矩阵行**：`zh-cloud-docs@9409531`（分支 `docs/dida-parity-matrix-round0`，即 PR !69）
      把 #20 的 ② 改记「已实现待合并 izhaong/zh-cloud-todo-flutter!286」，并更正第 14 轮的假锚点
      （`updatedAt` 非空列在 `app_database.dart:98` 的 `TodoTasks`，原写 `:43` 属 `TodoLists`）。
      改后该行未转义/转义 `|` 总数仍为 13。
- [x] **T009 另开 Issue 记 Service 债（FR-5）**：izhaong/zh-cloud-service#273。
      **正文已就地更正**（原写「未支持字段会被静默忽略，不是报错」是错的）：`TodoFilterServiceImpl.java:343-346`
      与 `:452-455` 两处都对 `column == null` `throw exception(TODO_FILTER_INVALID_SORT)` ⇒ 是**硬业务报错**，
      客户端单方面发 `update_time` 会让已保存过滤器保存/套用直接失败。这更强化「先改契约」的必要性。
- [x] **T010 六项门禁跑在最终字节**：见下表（日志 `/tmp/gate-035c.log`）。

## 第 1 轮复核处置（`VERDICT: FAIL`：B1/B2/B3 + 若干 NIT）

| 结论 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **B1** FR-5 记的服务端行为写错（不是静默忽略而是硬报错） | `sed -n '336,350p;450,460p'` 实读到两处 `throw exception(TODO_FILTER_INVALID_SORT)` ⇒ 复核员对 | 采纳：改 Issue #273 正文 + 发更正评论 + 本文件 T009 重写 |
| **B2** `spec.md:11` 仍写着 `app_database.dart:43`（我在 T008 只修了 docs，漏了作为唯一事实源的 spec） | `grep -n app_database spec.md` 命中 `:11` ⇒ 复核员对 | 采纳：改为 `:98` 并注明 `:43` 属 `TodoLists` |
| **B3** FR-3 后半句（未知名退回 smart）与嵌套线格式无任何用例覆盖 | `_decode` 确有嵌套分支；仓内唯一 fallback 断言是 `get(null)`（无行那一支） ⇒ 复核员对 | 采纳：新增第 4 例，直接写库喂两种真实形状；探针 PE/PF 各咬住一半 |
| NIT1 溢出判据测的是比生产短两行的菜单 | `tasks_by_list_page.dart:191-204` 生产确实常驻 `onBatchPressed`、条件给 `onCreateSection` | 采纳：用例 5 两个回调都传，判据落在最长菜单上 |
| NIT2 FR-1「紧跟创建时间」无测试钉住 | 菜单顺序=`TaskSort.values` 声明顺序，此前无断言 | 采纳：用例 1 整表比对六档顺序（重排即红） |
| NIT3 `byName` 抛的是 `ArgumentError` 不是 `StateError` | 复核员给了 `$DART_SDK/lib/core/enum.dart` 出处 | 采纳：改 `plan.md`；PD 的红是菜单渲染不出来，异常类型不影响判据 |
| NIT4 用例 3 不重开库 ⇒ 跨重启持久化未由本切片证明 | 属实；既有 `task_sort_preference_repository_test.dart:79` 那支会重开但用的是别的档 | **不补**，写进「仍缺」：`updatedAt` 档的跨重启持久化依赖既有链路，未单独重开验证 |
| NIT5 `probes2.log` 与 `probes3.log` 逐字节相同 | 属实（格式化只动空白 ⇒ 输出一致）⇒ 单看文件无法区分「重跑」与「拷贝」 | 已消解：本轮探针重跑到**新文件名** `/tmp/r15-probes5.log`，且用例数从 4 变 5，与旧日志不可能同字节 |
| NIT6 `r15-red.log` 里没有我引用的那行 | `grep -c "Bad state"` = 0 ⇒ 复核员对 | 采纳：T002 按文件实际内容重写，并明写哪句没有证据文件支撑 |
| NIT7 `pubspec.lock` 脏（改 url + 35 个 version） | `git diff --name-status a1d7733..HEAD` 不含 lock ⇒ 未入库，与本机口径一致 | **记录为限制**：六项门禁跑在本机解析出的依赖集上，CI 解析的是入库 lock ⇒ 本地绿不覆盖远端解析差异 |
| 「9 张黄金图没变」信息量 | 黄金用例不点 `todo-sort-menu`、默认档是 `smart` ⇒ 只证明既有五档无回归 | 采纳为解释，不夸大：新档不在黄金图覆盖面上 |

## 门禁（最终字节，日志 `/tmp/gate-035c.log`）

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 三个显式文件 | 三个都 `Formatted 1 file (0 changed)` / `exit=0`（含新测试文件；第一版在 `/tmp/gate-035.log` 里 `exit=1`，T006 已真修） |
| 2b 同检查跑在 `git show HEAD:` 版 | 三个文件 `exit=0` ⇒ HEAD 里已是格式化后的字节，本轮没有新增排版欠债 |
| 3 `flutter analyze` | `No issues found! (ran in 1.5s)` |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:50 +714 ~26: All tests passed!` |
| 6 `flutter build web --release …` | `✓ Built build/web`（`Compiling lib/main.dart for the Web... 18.1s`） |
| 7 `test/goldens` 改动数 | `0` |
| 8 sha256 | `f9fa39e5` `task_query_repository.dart` / `539443f4` `task_workspace_header.dart` / `8eaadeda` `task_sort_updated_at_test.dart`（复核修复轮：`5df86b95` → `8eaadeda`） |
| 9 工作区脏文件 | ` M pubspec.lock`（按口径不入库，见 NIT7 限制）+ 本轮 test 与 specs/035 三件套 |

**同基线复算**：`develop@a1d7733` 的非 golden 用例数 = **709**（`/tmp/base-034.log`）；specs/034 的 5 例在未合并的 !284 上、不在本分支。
本轮用例 5 条 ⇒ 期望 `709 + 5 = 714`，与第 5 项原文一致；跳过 26 未变 ⇒ 没有别的路数被顺手改动。

## 限制（不算通过证据的部分）

- **依赖集**：六项门禁跑在本机 `pubspec.lock`（本机新 SDK 重解析：url 改镜像 + 35 个 version 变化，按口径不入库）之上，
  CI 解析的是仓库里的 lock ⇒ **本地绿不覆盖远端解析差异**。
- **平台面**：本地 Dart 门禁不替代原生编译（iOS/Android 构建）、真机行为、双设备同步与系统通知投递；
  Gitea runner（`cgroup is not mounted`）与 Jenkins `zh-cloud-todo-flutter` Job 两条硬阻塞未解。
- 9 张黄金图未点 `todo-sort-menu`、默认档是 `smart` ⇒ 只证明既有五档无回归，**不证明新档可见**。

## 仍缺（诚实清单）

- 方向切换（嘀嗒创建/修改时间各有「从旧到新 / 从新到旧」）未做 —— 嘀嗒页面没写方向在界面上怎么选，
  本端菜单是单层 `PopupMenuButton` ⇒ 加方向控件就是自创交互，需先在嘀嗒 App 上人工核一眼交互。
- `updatedAt` 档的**跨重启持久化**未单独验证（NIT4）：新用例 3 不重开库，重开验证只在既有链路的别的档上做过。
- 已保存过滤器（矩阵 #22）里的「按修改时间」未接：Service 白名单缺 `update_time`（service#273，未接前客户端发过去会硬报错）。
- 矩阵行状态翻转要等合并；未合并前只写「已实现待合并」。

## 下轮入口

1. 本轮第 2 轮复核（若派）只针对「B1/B2/B3 + NIT1/2/3 的修复字节」；两轮封顶，无新结论即请示。
2. 队列回到 #89 附件挂载入口（已取证：`attachment_upload_api.dart` 在生产侧只被 `core/sync/sync_coordinator.dart:35-43` 消费，
   UI 侧零入口），或做 #86 暴露的 ⌘K 指令菜单（注意 ⌘K/Ctrl+K 已被打开搜索占用）。
3. 轨道 A：A 段去 WEB 化已收口（复扫判据见提交记录），剩 B33/C9 候选清单需人工判定。
