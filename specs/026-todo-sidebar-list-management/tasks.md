# Todo 侧栏清单管理入口任务

- [x] T001 红测：侧栏清单行长按出「编辑 / 删除」动作表。
- [x] T002 抽出共用的「拦截 + 确认 + 删除」函数，`ListPage` 改调用它。
- [x] T003 接入 `_SidebarRow.onLongPress` 与 `_ListRow`，实现编辑与删除。
- [x] T004 补取消不写、确认后删、未完成拦截、收集箱不出入口、320px 与读屏语义用例。
- [ ] T005 全部门禁 + 只读复核 + 回写矩阵 #19。

## 执行证据

- 2026-09-23：RED 先行且失败信息精确指向缺失项。新用例首跑 `00:01 +1 -6: Some tests failed.`，
  报错统一是 `The finder "Found 0 widgets with key [<'sidebar-list-action-delete'>]: []"` ——
  即长按没有任何动作表存在；唯一通过的那条是「收集箱不出现清单动作入口」（当时它天然成立，见下文对该用例强度的说明）。
- 2026-09-23：实现。`lib/features/list/list_actions.dart` 承载删除语义（`countOpenTasksByList` → 有未完成时弹
  「清单有未完成任务 / "名称" 仍有 N 项未完成。确认删除？」、无未完成时弹「删除清单 / "名称" 确认删除？」，
  两条分支共用 `_dialogActions` 的「取消 / 删除」按钮），`list_page.dart` 的 28 行 `_deleteList` 整体换成
  `confirmAndDeleteList(context, ref, list)` 一行委托，`sidebar.dart` 的 `_ListRow` 由 `StatelessWidget` 改为
  `ConsumerWidget` 并自带 `onLongPress: () => showListActions(context, ref, list)`，
  `_SidebarRow` 增可选 `onLongPress`（默认 null ⇒ 其它行不注册手势）。
  **只留一份删除口径**：不新增第二套确认逻辑，也不给「编辑」开一个单调用方的公共函数（就地打开表单体）。
  （复核 I1/I2 判此句当时**不成立** —— `ListEditorSheet._delete` 里还留着逐字重复的第二套，且 `open == 0`
  时不确认直接删；本切片的「编辑」入口第一次把它变成侧栏可达。已按结论收敛，见「只读复核」段。）
- 2026-09-23：两处实测纠偏，不是猜的。① 首版用例对 `workListId` 长按报 `Bad state: No element`，
  原因是该清单挂在 `folderLocalId` 下、`_FolderGroup` 的 `ExpansionTile` 默认折叠，行根本不在可见树里 ——
  改用顶层的 `personalListId` 后成立；② 「取消不写库」用例期望标题「删除清单」却失败，
  因为 `personalListId` 在基线数据里**本来就有未完成任务**，走的是拦截分支。
  改为**用例自建空清单**（`listRepositoryProvider.create(name: '待删除空清单')`）来钉「无未完成」分支，
  拦截分支则改为先 `countOpenTasksByList` 读实际条数再断言 `仍有 $open 项未完成`，不再硬编码 1。
  最终本文件 `00:01 +7: All tests passed!`。
- 2026-09-23：门禁在最终状态跑（`/tmp/gate-026.log`）：`git diff --check` exit=0；
  `dart format --output=none --set-exit-if-changed` 对 `list_actions.dart` 与新测试文件 `Formatted 2 files (0 changed)` exit=0；
  `flutter analyze` `No issues found!`；`flutter test --tags golden` `00:05 +9: All tests passed!`
  （**9 张黄金图未变** —— 本轮只加手势，未改任何布局，无需申请重录基线）；
  全量 `02:15 +724 ~26: All tests passed!`（= 上一轮的 717 **+ 本切片 7**，数目自洽），
  `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。`sidebar.dart` / `list_page.dart` 另用「HEAD 版与工作树版各自格式化后 diff」核过，
  差异只有本轮的语义改动（1 行 import、`StatelessWidget`→`ConsumerWidget`、`build` 多一个 `WidgetRef ref`、
  一行 `onLongPress`、`_deleteList` 由 28 行缩为 2 行委托），无顺带重排。
- 2026-09-23：「置顶」判为后端契约缺口的依据已双侧核对：本地 Drift `TodoLists`（`core/db/app_database.dart:29-48`）
  只有 `sortOrder`，无 pinned 列；服务端建表脚本 `zh-cloud-service/sql/mysql/modules/todo-baseline-2026-09-18.sql:334`
  同样只有 `sort_order`。不用 `sortOrder` 冒充「置顶」（排序值会被下一次拖动覆盖，语义不同），
  须先在 Service 加字段与端点再回客户端。
- 2026-09-23：本切片用例强度自评（供复核优先看这里）。「收集箱不出现清单动作入口」这条**结构上就成立**：
  收集箱行是导航行 `_SidebarRow`，不是 `_ListRow`，`listRepositoryProvider.watchAll` 也按
  `name like 'smart:%'` 与 `id != 'inbox'` 排除它。因此这条不会因 `_ListRow` 内部改坏而失败，
  它锁的是「别把长按挂到所有侧栏行上」这一层；真正的清单级入口由前几条用例锁住。
- 2026-09-23：**B1 的负对照实测**（`/tmp/gate-026b.log` `### 0)`）：把该用例档位从 1.3 改回 1.0 后
  `00:00 +0 -1: 320px 与 1.3 倍字体下动作表两项都在且不溢出 [E]`，失败点正是新加的档位自检断言
  （日志报在该文件 line 231）；随后 `cp` 回原文件、`cmp -s` 判 `restored=identical`。
  ⇒ 那条断言确实在盯「档位有没有传到弹层」，不是空测。
- 2026-09-23：按复核结论改完后**在最终状态重跑六项门禁**，共两遍：`/tmp/gate-026c.log`（B1/I1/I2/I3/M1/M2/M3 修完）、
  `/tmp/gate-026d.log`（闭环复核又提的 import 顺序收敛后，**以 d 为准**）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 对 `list_actions.dart` 与新测试文件
  `Formatted 2 files (0 changed)` exit=0；`flutter analyze` `No issues found!`；
  `flutter test --tags golden` `00:04 +9: All tests passed!`（**9 张黄金图基线仍未变**）；
  全量 `02:25 +724 ~26: All tests passed!`；`flutter build web --release --dart-define=…` `✓ Built build/web`。
  `sidebar.dart` 用「HEAD 版与工作树版各自格式化后 diff」核过，差异 9 行，全是本轮语义改动（import、`_ListRow` 转
  `ConsumerWidget`、`onLongPress` 三处接线），无顺带重排。
  中途真失败过一项、不掩盖：修复后第一遍 `### 2)` 报 `Formatted 2 files (1 changed)` exit=1
  —— 我把 `Align` 写成多行、不合本工具链排版；只对**本轮新增的那个文件**原地 `dart format` 收敛成一行后复跑才 0 changed，
  `diff` 确认那次改动仅是一处换行、无语义差异。存量欠债文件（`sidebar.dart` / `list_page.dart` / `list_editor_sheet.dart`）
  仍用「HEAD 版与工作树版各自格式化后 diff」核过，输出只有本轮语义改动。

## 只读复核（第 3 轮，2026-09-23）

- **复核工具替换并已记明**：约定的 `claude -p … --permission-mode plan`（仅 Read/Grep/Glob）本轮仍产不出结论 ——
  `/tmp/review-026.out` 0 字节，stderr `[claude-code:unrecognized_model] {"model":"Top1"}`，加 `--model sonnet` 无效
  （用户配置里把模型别名指向了未知模型）。按用户 2026-09-23 的选择，改用本会话只读子代理复核本轮 FR-001~FR-005。
- 结论 **`VERDICT: FAIL`**：1 Blocking + 3 Important + 6 Minor。逐条处置，无沉默丢弃：
  - **B1 采纳（空测）**。原 `_pump` 用 `MediaQuery.withClampedTextScaling` 包住侧栏，而侧栏在 `home:` 子树内；
    `showModalBottomSheet`/`showDialog` 默认挂 root Navigator，动作表与两个确认框是它的兄弟路由 ⇒
    继承不到 home 内的档位，「1.3 倍字体不溢出」实际一直在 1.0 倍排版上跑。
    改为 `tester.platformDispatcher.textScaleFactorTestValue`（`addTearDown` 清回），并加自检断言
    `MediaQuery.textScalerOf(弹层 context).scale(10) ≈ 13`；负对照（把档位改回 1.0 必须红）见 `/tmp/gate-026b.log` `### 0)`。
  - **I1 采纳（两套删除口径）**。`ListEditorSheet._delete` 与 `list_actions.dart` 逐字重复，且 `open == 0` 时
    不确认直接删；本切片的「编辑」入口第一次把它变成侧栏可达。现收敛为一行委托：
    `final deleted = await confirmAndDeleteList(context, ref, widget.existing!); if (deleted && mounted) Navigator.pop(context);`
    为此 `confirmAndDeleteList` 的返回类型由 `Future<void>` 改为 `Future<bool>`（调用方据此决定要不要收起自己）。
  - **I2 采纳**：「只留一份删除口径」在 I1 修掉前是不成立的自夸，已在上文执行证据里就地标注。
  - **I3 采纳**：FR-004 的「两个条目各自可读」原来只断言了「编辑」，补 `find.bySemanticsLabel('删除')`。
  - **M1 采纳**：拦截用例前置从 `rows.first`（顺序不确定，且 fixture 里 `personalListId` 本就挂着一条未完成任务 ⇒
    那行更新是惰性的）改为 `firstWhere((row) => row.id == 'visual-task-personal-list')`。
  - **M2 采纳**：「取消不写」原先只断言「没被删」，补 outbox 断言
    （`entity == 'list' && op == 'delete' && entityLocalId == created.id` 必须为空）。
  - **M3 采纳（一行）**：两次确认框之后、`repo.delete` 之前补 `if (!context.mounted) return false;`。
  - **M4 不采纳**：`db == null` / `repo == null` 静默 return 只在 `session == null` 时可读，而 `app.dart` 的 redirect
    此时已把界面换到 `/login`，侧栏不在屏上（复核方亦判「不可达」）；本轮不为此加提示 UI，FR 未要求。
  - **M5 记录、不再改**：清单页删除从「0 未完成直接删」变为先弹「删除清单」确认 —— 这是 I1 统一到一份口径的直接结果，
    方向与 FR-003 一致。`_deleteList` 现在是一行纯委托，同一个函数已由侧栏用例覆盖，再为清单页按钮写一条等价断言属于重复。
  - **M6 不采纳**：「收集箱不出现入口」是负向用例，删掉实现它当然仍绿 —— 正向对照由前两条用例承担，强度已在
    「用例强度自评」里如实写明；不为此虚构强度。

- **闭环复核（第二轮，同一工具）`VERDICT: PASS`**：B1/I1/I3/M1/M2/M3 逐条判 `CLOSED`，无新增缺陷。
  其给出的关键校验：`confirmAndDeleteList` 六条 `return` 路径中只有 `repo.delete` 成功后那条返 `true`
  （`list_actions.dart:50`），其余（db 空、未挂载、两处取消、repo 空）全返 `false` ⇒ 编辑器「删成才收起」
  与改前逐路径等价；抛异常时不 pop，亦与改前一致。`M2` 的谓词经 `sync_change_queue.dart:43` 与
  `sync_entities.dart:4/49` 核对确实能命中真实行（不是恒空）。
  该轮另提两点非阻塞：① `sidebar.dart` 的两行 import 顺序被我插反 —— **已采纳并收敛**（`gate-026d` 即收敛后重跑）；
  ② 「1.3 倍下两个确认框的排版」与「清单管理页那个删除按钮」仍无断言 —— **本轮不扩，记在下方仍缺**。
- 仍缺（不构成本切片完成的对立面，但下一轮要认账）：
  ① 1.3 倍字体下**两个 `AlertDialog`** 自身的溢出（FR-004 只要求动作表两项，弹层内文案未断言）；
  ② 清单管理页删除按钮的用例（它现在是一行委托，同函数已由侧栏用例覆盖，属重复断言成本）；
  ③ 键盘/桌面等价入口与「左滑」手势；④ 文件夹入口（#18，需先申请黄金图重录）。

## 未勾项与下一步

- T005 未勾，**唯一剩余条件**：矩阵 #19 的状态翻转要引**已合并** SHA，而本切片仍在 `zh-cloud-todo-flutter`
  工作树里 —— 未建分支、未开 PR、该仓 Issue 也未建（**全部待授权**）。复核已拿到 `PASS`、六项门禁已在最终状态全绿。
- 「左滑」这一嘀嗒主手势本轮未做：`Dismissible`/自绘滑动条会改动行的命中区与视觉，
  可能触发黄金图变化；按目标约定（重录基线先申请）留待申请后做，本轮只用不改变布局的长按先交付能力。
- 下一步（#18）：文件夹的新建/改名/解散入口。它需要一个可见的「管理」入口（侧栏分组标题加图标），
  先申请黄金图重录；`FolderPage` 与 `moveToFolder` 的实现与测试都已在仓内。
