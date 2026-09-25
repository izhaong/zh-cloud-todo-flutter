# 049 · 清单编辑器「所属文件夹」· 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/339-list-editor-folder-picker`。Issue **#339**（矩阵 **#19**）。
判据、范围与取舍见同目录 `spec.md`；落点与实现要点见 `plan.md`。

## 勾选（只勾真满足的）

- [x] FR-1 编辑器出现「所属文件夹」：「无」+ 每个已有文件夹，嵌套文件夹显示成 `父 / 子`
- [x] FR-2 新建：所选文件夹即新清单归属；没选 ⇒ 顶层（`folderLocalId` 为 null，服务端 `folderId` 也为 null）
- [x] FR-3 编辑：打开预选当前归属；改选后保存真的移入/移出，并留 `list/upsert` outbox（用例读库 + 数 outbox 行数）
- [x] FR-4 只改名不动文件夹 ⇒ 不多打一条移动记录（探针 PD 证：去掉闸门就红）
- [x] FR-5 从文件夹里点新建 ⇒ 预选那个文件夹（隐式行为，探针 PG 证）
- [x] FR-6 四件套（见下表）
- [ ] #339 的另两子面：**颜色** 与 **Emoji 图标** 未做（要新增本地列 + 后端 `TodoListDO` 字段 ⇒ 属"先修契约再动前端"），Issue 保持 open
- [ ] 只读复核 `VERDICT` —— 待派
- [ ] 矩阵 #19 回写 —— 8 条 open PR 一条都没合并（`/pulls?state=open` 实测 !351 !350 !347 !346 !322 !319 !314 !311 全 open），本轮只能写「已实现待合并」

## 四件套（新增可见界面 = 编辑器里那一格下拉）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 在弹层自己的 context 上 `textScaler: TextScaler.linear(1.3)` + 320×700，收起与**展开候选菜单**两种状态各测一次溢出 | `320px + 1.3 倍字号：名称、所属文件夹与按钮都排得下` |
| 独立读屏语义 | `MergeSemantics` 包住 `InputDecorator` ⇒ 一个节点念「所属文件夹 无」，且 `isButton`/`tap`/`focus` 一个没丢（实测对照见下节） | `读屏：一个节点同时念出「所属文件夹」与当前值，且仍是按钮` |
| 失败保留已加载数据 | 移动抛错：弹层不关、清单名与已选归属都还在、提示写在弹层可见区、库里既没改名也没移动 | `移动失败：弹层不关、清单名与已选归属都还在，且给可见提示` |
| 过期响应不覆盖新响应 | 归属是 State 里的**点中字面值**，文件夹 stream 只是补候选；stream 再发一次也不回退已选 | `文件夹列表晚到：占位换成真名，之后再来一次也不覆盖已选` |

### 读屏是实测出来的，不是推的

探针输出全文留在 `/tmp/r68/SEMANTICS_PROBE.txt`（探针脚本 `/tmp/r68/r68_semantics_probe.dart.txt`，
复制回 `test/` 可重跑）。同一棵树两版对照：

| | 字段节点的 label | `所属文件夹[\s\S]*无` 命中 | flags |
| -- | -------------- | ---------------------- | ----- |
| 不合并（InputDecorator 直接包 DropdownButton） | `"无"` | **0** | `isButton, isFocusable, hasExpandedState` |
| 包 `MergeSemantics`（本轮最终字节） | `"所属文件夹\n无"` | 1 | 同上，一个没丢 |

⇒ 不合并时读屏只会念"无 按钮"，用户不知道这个"无"是什么的无。这与我上一轮记的坑同形：
**标签与值分属两个节点时，`bySemanticsLabel` 的正则永远配不出"标签+值"**，
断言写宽一点就会假绿。

### 一个实现期真的踩到的断言

首帧 `foldersStreamProvider` 还没吐数据，而清单已有归属 ⇒ `DropdownButton` 断言
"There must be exactly one item with [DropdownButton]'s value"。
⇒ 候选里补一格占位（数据没到 = `加载中…`；到了但查不到 = `（已删除）`）。
这条不是"防御性代码"：探针 PI 把它抽掉后 **7 条用例同时红**（`+3 -7`）。

## 反向探针（每条先证探针本身打上了：目标串在 HEAD 字节里恰好命中 1 次）

脚本 `/tmp/r68/probes.py`，每条完整输出 `/tmp/r68/probe_<码>.log`，跑完 `RESTORE cmp: SAME`。

| 探针 | 抽掉什么 | 结果 | 红在哪条 |
| ---- | -------- | ---- | -------- |
| PA | develop 字节（整格都没有） | `00:01 +1 -9` | 9 条全红；绿的那条是 `只改名不动文件夹` —— 它钉的是"不许顺手多同步一次"，develop 本来就没这个能力，**这条绿是对的**，不是漏网 |
| PB | 新建时不把归属传给 `create` | `+9 -1` | 新建那条（读库看 `folderLocalId`） |
| PC | 编辑时根本不发起移动 | `+8 -2` | 编辑移出那条 + 移动失败那条（不发起移动 ⇒ 失败提示无从出现） |
| PD | 去掉「值没变就不动」闸门 | `+9 -1` | `只改名不动文件夹 ⇒ 不额外打一条移动记录`（FR-4 的正面判据） |
| PE | 失败只 `return`，不给可见提示 | `+9 -1` | 移动失败那条 |
| PF | 失败也把弹层关掉 | `+9 -1` | 移动失败那条 |
| PG | 打开时不预选 | `+5 -5` | 预选、编辑移出、只改名、晚到、已删除共 5 条 |
| PH | 去掉 `MergeSemantics` | `+9 -1` | 读屏那条（四件套第 2 条唯一锚点） |
| PI | 去掉占位候选 | `+3 -7` | 上面「踩到的断言」那 7 条 |
| PJ | 显示值改回从入参派生（非受控） | `+6 -4` | 晚到那条（四件套第 4 条）+ 新建 + 移动失败 + 读屏 |
| PK | 先改名再移动 | `+9 -1` | 移动失败那条（断言 `after.name == '工作'` ⇒ 半改状态被抓到） |

**PA 第一次跑出来的不是"红"，是 8 分钟不退出 —— 根因在我自己的用例里，记下来防重犯**

第一版 PA：`00:01 +1 -8` 后卡住，8 分 42 秒才由 runner 记一个文件级 `[E]`（`/tmp/r68/CONTROL_dev_bytes.log`）。
逐条单跑第 10 条 ⇒ develop 字节下 0 秒就红（`+0 -1`）⇒ 卡住的不是断言，是 **tearDown**：
`晚到` 那条用了单订阅 `StreamController`，`addTearDown(controller.close)` 的 `done` future
要等"有订阅者收完"才完成 —— 而 develop 字节的弹层**根本不 watch** `foldersStreamProvider`，
没人订阅 ⇒ close 永久挂起 ⇒ 整个文件不再往下跑。
⇒ 改成 `StreamController.broadcast()`（多订阅的 `close()` 立刻完成），PA 重跑 `00:01 +1 -9` 一秒收口。
教训：**探针跑不完 ≠ 实现没问题**，先怀疑自己的夹具；"没人订阅就挂住"这种 teardown 依赖
一旦进了对照组就会把"红"伪装成"没结论"。

## 门禁原文记录（跑在最终字节 `840af71`，日志 `/tmp/r68/gates/final.log`）

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 2 个 dart 文件>` | `Formatted 2 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 1.8s)`，`rc=0` |
| `flutter test --tags golden` | `00:09 +9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:56 +908 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

**第一遍是 5/6**：`e231bf4` 上门禁 3 报 `1 issue found`（测试文件那条
`import 'package:drift/drift.dart' hide isNull;` 是 unused_import，`app_database.dart` 已经把符号导出了）
⇒ 单提 `style(test)` 提交 `840af71` 后**六条全部重跑**，本表就是重跑后的字节（第一遍日志留在 `/tmp/r68/gates/attempt1.log`）。

计数对账（诚实记法）：`+908 = 898 + 10`。其中 **898 不是本轮实测的**——它来自第 64 轮在同一基线
`origin/develop@9032005` 上实跑干净 worktree 记下的 `+898 ~26`（见 `specs/045-sort-direction/tasks.md`），
本轮没有重跑基线；10 = 本轮新增用例数。`~26` 与基线一致，未新增 skip。`pubspec.lock` 未进提交
（门禁跑完后 `git status --short` 为空）。

## 相撞面

`lib/features/list/list_editor_sheet.dart`、`test/features/list/`、`specs/049-*` 与
**8 条 open PR 的改动文件表逐条比对（`/pulls/N/files`）命中 0** ⇒ 不同文件，无需 merge-tree 复测。

## 下一轮入口

1. #339 剩下两格：清单 **颜色** 与 **Emoji 图标**（`spec.md` 已记为何不在本轮）。
   顺序建议：先在 `zh-cloud-service` 给 `TodoListDO` + `AppTodoListSaveReqVO` 加 `color`/`emoji`，
   bump 增量 SQL，再回来动 Flutter（本地 `schemaVersion` 也要 22→23）。
2. 弹层里 `Row + Spacer` 的操作行：`#320px + 1.3` 本轮没溢出（按钮文案短），
   但同形状的 `quick_add_bar` 在第 66 轮实测溢出过 ⇒ 真加字段（颜色/图标按钮）时要按 `Wrap` 重测。
3. 矩阵 #19 的「已实现待合并」注记走 docs !105 留言，不再新开第 12 条同文件 PR（第 67 轮的判断照用）。
