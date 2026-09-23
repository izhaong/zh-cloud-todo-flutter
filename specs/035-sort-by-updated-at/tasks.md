# tasks：specs/035 工作区排序补「修改时间」档

分支 `feat/todo-sort-by-updated-at`，基线 `develop@a1d7733`。矩阵行：#20（可达性聚合行 `| 14 / 15 / 16 / 20 / 21 / 23 / 24 |` 的「仍缺」项之一）。

## 任务清单

- [x] **T001 缺口取证**：读嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》与矩阵 #20。
      本端 `enum TaskSort` 只有 `smart / priorityDesc / dueDate / title / createdAt` ⇒ 四种排序里缺「按修改时间」。
- [x] **T002 红测先行**：`test/task_sort_updated_at_test.dart` 4 例，失败信息精确指向缺失档位。
      原文（`/tmp/r15-red.log`）：`00:00 +0 -4: Some tests failed.`，四条失败名即 4 例，
      驱动消息为 `Bad state: TaskSort 里没有「updatedAt」这一档` 与 `find.text('修改时间')` 0 命中。
      用 `sortByName(...)`（运行时 `firstWhere`）而非编译期引用新档 ⇒ 缺档时报的是「缺哪一档」，不是整文件编译不过。
- [x] **T003 最小实现（FR-1/2/3）**：只补穷尽 switch 需要的四处 + 一处 case，不新增抽象。
      `task_query_repository.dart:22`（枚举追加在末尾）、`:37`（比较器 `right.updatedAt.compareTo(left.updatedAt)`）、
      `task_workspace_header.dart:16`（同名命令值）、`:28`（映射）、`:41`（label `'修改时间'`）、
      `onSelected` 的穷尽 `switch (command)` 里把 `updatedAt` 并入 `break` 分组。
- [x] **T004 反向探针**（脚本 `/tmp/r15_probes.py`，日志 `/tmp/r15-probes2.log`、最终字节复算 `/tmp/r15-probes3.log`）：

  | 探针 | 摘掉的生产代码 | 必须红的用例 | 结果 |
  | ---- | -------------- | ------------ | ---- |
  | PA | 比较器 `TaskSort.updatedAt => 0` | 用例 2（按 updatedAt 从新到旧） | **第一轮 GREEN ⇒ 是测试缺陷**；修种子后 RED |
  | PB | label 换成同义词 `'更新时间'` | 用例 1（照嘀嗒措辞）+ 用例 4（菜单里可见） | RED |
  | PC | 命令映射 `=> null`（菜单项在但点了不改档） | 用例 4 的 tap 回调断言 | RED |
  | PD | 整条 `_TaskWorkspaceHeaderCommand.updatedAt`（三处协同删除） | 用例 4（`byName` 抛错 ⇒ 菜单渲染不出来） | RED |

  每次探针结束都用 `cmp -s` 证明两个 lib 文件与 pristine 逐字节一致（日志里 4×2 行 `identical`）。

  **PA 第一轮为什么是绿的（本轮最大的收获）**：用例 2 原本把兜底键 `sortOrder` 种成
  touched=0 / created=1，与 `updatedAt` 的期望方向**同向** ⇒ 把比较器摘成 `=> 0` 之后，
  兜底链（`sortOrder` → `id`）恰好排出同一个 `[touched, created]`，用例照样绿。
  处置：把种子改成 touched=1 / created=0（`id` 字典序也是 created 在前 ⇒ 两条兜底键都反向），
  并在测试里把这条理由写成注释。改完 PA 才红。
  ⇒ 「数据反着种」不止指主键那一列，**所有会接住排序的兜底键都得反向**，否则探针绿等于用例不覆盖该机制。
- [x] **T005 四件套（FR-4）**：用例 4 在 320×720 + 1.3 倍字体下直接泵 `TaskWorkspaceHeader`，
      在 header 自己的 context（`Key('todo-task-workspace-header')`）上自检 `textScaler.scale(10) ≈ 13`
      （只包 `home:` 的档位传不进弹层/路由），断「修改时间」`findsOneWidget` + `bySemanticsLabel` 独立节点 +
      tap 后 `onSortChanged` 带出 `updatedAt` + `takeException()` 为 null；
      另含 `创建时间` 正对照，防「整张菜单没渲染出来」被判成通过。
      「失败保留已加载数据」「过期响应不覆盖新响应」在本切片无对应异步链路（排序是纯本地比较，
      偏好读写复用已验收链路）⇒ 按 spec 的声明不编造判据。
- [x] **T006 `dart format` 门禁抓到自家新文件不合规**：`/tmp/gate-035.log` 第 2 项
      `Changed test/task_sort_updated_at_test.dart` / `exit=1` —— 两个 lib 文件 exit=0（HEAD 版同检查也 exit=0，
      不是存量欠债），红的就是本轮新写的测试文件本身 ⇒ 本次引入的错误要真修：
      只对这一个文件跑 `dart format`（未整仓原地格式化），复跑 4 例仍 `All tests passed!`，
      并在新字节上重跑全部四个探针（`/tmp/r15-probes3.log` 仍四红）。
- [ ] **T007 只读复核拿 VERDICT**：见下面「复核轮次」。**未完成**。
- [x] **T008 回写矩阵行**：`zh-cloud-docs` 提交 `9409531`（分支 `docs/dida-parity-matrix-round0`，即 PR !69）
      把 #20 的 ② 由「没有」改记为「已实现待合并 izhaong/zh-cloud-todo-flutter!286」，
      并顺手更正第 14 轮留下的假锚点：`updatedAt` 非空列在 `app_database.dart:98` 的 `TodoTasks`（原写 `:43` 属 `TodoLists`）。
      改后该行未转义/转义 `|` 总数仍为 13（改前后各数一遍，防整行替换吃掉末列）。
- [x] **T009 另开 Issue 记 Service 债（FR-5）**：izhaong/zh-cloud-service#273
      「已保存过滤器的排序白名单缺『修改时间』列」，正文含 `TodoFilterServiceImpl.java:487-500` 实测白名单六项与
      `default -> null`（即客户端硬发未支持字段会被静默忽略，不是报错），并按规则 5 写明「先改契约再改客户端」。
      本仓 Issue #285 / PR !286 与它互链。
- [x] **T010 六项门禁跑在最终字节**：见下表。

## 门禁（最终字节，日志 `/tmp/gate-035b.log`）

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 三个显式文件 | 三个文件均 `exit=0`（第 2 项在 `/tmp/gate-035.log` 曾对测试文件 `exit=1`，T006 已修真错误） |
| 2b 同检查跑在 `git show HEAD:` 版 | 两个 lib 文件 `exit=0` ⇒ 本轮没引入排版欠债；测试文件 HEAD 无此文件（空文件产物判据无意义，不作证据） |
| 3 `flutter analyze` | `No issues found! (ran in 1.4s)` |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:09 +713 ~26: All tests passed!`（同基线复算见下表） |
| 6 `flutter build web --release …` | `✓ Built build/web` |
| 7 `test/goldens` 改动数 | `0` |
| 8 本轮文件 sha256 | `f9fa39e5` `task_query_repository.dart` / `539443f4` `task_workspace_header.dart` / `5df86b95` `task_sort_updated_at_test.dart`（该文件格式化前为 `594b26e4`，见 T006） |
| 9 工作区脏文件 | ` M pubspec.lock`（本机新 SDK 重解析，按口径不入库）+ 本轮两个 lib、`specs/035-sort-by-updated-at/`、新测试文件 |

同基线复算：本分支基线 `develop@a1d7733` 的非 golden 用例数是 **709**（`/tmp/base-034.log`，第 13 轮实测），
specs/034 那 5 例在未合并的 !284 上、不在本分支 ⇒ 本轮应为 `709 + 4 = 713`。
`/tmp/gate-035.log` 第 5 项原文：`01:50 +713 ~26: All tests passed!` —— 与算术一致，
没有别的路数被顺手改动，跳过数 26 未变。
最终字节复算值以 `/tmp/gate-035b.log` 为准，回填在 T010 下。

## 复核轮次

- 复核手段：`claude` CLI 本机不可用（`unrecognized_model`），按口径替换为本会话只读子代理审本轮 FR-1..FR-5。
- 已明令复核员不得跑 `flutter`/`dart`（门禁与它并行），并交给它 5 条「不要照信、需独立复验」的断言：
  PA 的根因解释、排序是否在 Dart 侧（有无 SQL `ORDER BY` 通道）、两枚枚举靠 `byName` 名字耦合、
  1.3 倍档位是否自检于自身 context、用例 3 是否真走编码路径。
- 第 1 轮 `VERDICT` 回写位置：本小节。两轮无新结论即停下请示，不派第 3 轮。

## 仍缺（诚实清单）

- 方向切换（嘀嗒创建/修改时间各有「从旧到新 / 从新到旧」）未做 —— 嘀嗒页面没写方向在界面上怎么选，
  本端菜单是单层 `PopupMenuButton`，加方向控件就是自创交互 ⇒ 需先在嘀嗒 App 上人工核一眼交互。
  ⇒ 本切片验收边界只到「档位存在且排序正确」。
- 已保存过滤器（矩阵 #22）里的「按修改时间」未接：Service 白名单缺 `update_time`（T009 的 Issue）。
- 矩阵行状态翻转要等合并；未合并前只写「已实现待合并」。
- 真机/远端 CI 未跑：本地 Dart 门禁不替代原生编译与真机行为；Gitea runner 与 Jenkins Job 两条硬阻塞未解。

## 下轮入口

1. 回填 T007 复核结论（照结论改，不采纳的在 T007 写理由）。
2. 回填 T008 矩阵行 + T009 Service Issue。
3. 队列回到 #89 笔记摘要/模板与附件挂载入口（队列 1），或继续轨道 A 的 A 段逐行复校。
