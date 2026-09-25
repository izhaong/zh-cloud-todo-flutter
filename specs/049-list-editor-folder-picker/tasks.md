# 049 · 清单编辑器「所属文件夹」· 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/339-list-editor-folder-picker`。Issue **#339**（矩阵 **#19**）。
判据、范围与取舍见同目录 `spec.md`；落点与实现要点见 `plan.md`。

## 勾选（只勾真满足的）

- [x] FR-1 编辑器出现「所属文件夹」：「无」+ 每个已有文件夹，嵌套文件夹显示成 `父 / 子`
- [x] FR-2 新建：所选文件夹即新清单归属；没选 ⇒ 顶层（`folderLocalId` 为 null，服务端 `folderId` 也为 null）
- [x] FR-3 编辑：打开预选当前归属；改选后保存真的移入/移出，并留 `list/upsert` outbox（用例读库 + 数 outbox 行数）
- [x] FR-4 只改名不动文件夹 ⇒ 不多打一条移动记录（探针 PD 证：去掉闸门就红）
- [x] FR-5 从文件夹里点新建 ⇒ 预选那个文件夹（隐式行为，探针 PG 证）
- [x] FR-6 四件套（见下表；第 1 版的③是假绿，复核后补了「移入失败」才真锁住）
- [ ] #339 的另两子面：**颜色** 与 **Emoji 图标** 未做（要新增本地列 + 后端 `TodoListDO` 字段 ⇒ 属"先修契约再动前端"），Issue 保持 open
- [x] 只读复核第 1 版 `VERDICT: FAIL` → 已按发现补测并重跑门禁；**第 2 版复核待派**
- [ ] 矩阵 #19 回写 —— 8 条 open PR 一条都没合并（`/pulls?state=open` 实测 !351 !350 !347 !346 !322 !319 !314 !311 全 open），本轮只能写「已实现待合并」

## 四件套（新增可见界面 = 编辑器里那一格下拉）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 在弹层自己的 context 上 `textScaler: TextScaler.linear(1.3)` + 320×700，收起与**展开候选菜单**两种状态各测一次溢出 | `320px + 1.3 倍字号：名称、所属文件夹与按钮都排得下` |
| 独立读屏语义 | `MergeSemantics` 包住 `InputDecorator` ⇒ 一个节点念「所属文件夹 无」，且 `isButton`/`tap`/`focus` 一个没丢（实测对照见下节） | `读屏：一个节点同时念出「所属文件夹」与当前值，且仍是按钮` |
| 失败保留已加载数据 | 移动抛错：弹层不关、清单名与已选归属都还在、提示写在弹层可见区、库里既没改名也没移动。**两条**：移出（原归属→「无」）与移入（无归属→「项目」）——只测移出的版本放过过真 bug，见 PL | `移动失败…` + `移入失败（原来没有归属）…` |
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

**口径：全部跑单文件**（`flutter test test/features/list/list_editor_folder_picker_test.dart`），
13 条用例的最终版本。第一版这些数字是 10 条用例时测的，加了三条之后**全部重跑**（脚本 `/tmp/r68/probes.py`，
输出 `/tmp/r68/PROBES_final13.log`，每条完整日志 `/tmp/r68/probe_<码>.log`，跑完 `RESTORE cmp: SAME`）。

| 探针 | 抽掉什么 | 结果 | 红在哪条 |
| ---- | -------- | ---- | -------- |
| PA | develop 字节（整格都没有） | `+1 -12` | 12 条红；绿的仍是 `只改名不动文件夹`（它钉"不许顺手多同步一次"，develop 本来就没这能力 ⇒ 这条绿是对的） |
| PB | 新建时不把归属传给 `create` | `+11 -2` | 新建那条 + `serverId 为空`那条（都读库看 folderLocalId） |
| PC | 编辑时根本不发起移动 | `+10 -3` | 编辑移出 + 移出失败 + **移入失败**（新那条也抓住了，说明它不是只在"清空归属"这一个 bug 上有力） |
| PD | 去掉「值没变就不动」闸门 | `+12 -1` | `只改名不动文件夹 ⇒ 不额外打一条移动记录`（FR-4 正面判据） |
| PE | 失败只 `return`，不给可见提示 | `+11 -2` | 移出失败 + 移入失败 |
| PF | 失败也把弹层关掉 | `+11 -2` | 移出失败 + 移入失败 |
| PG | 打开时不预选 | `+8 -5` | 预选、编辑移出、只改名、晚到、已删除 共 5 条 |
| PH | 去掉 `MergeSemantics` | `+12 -1` | 读屏那条（四件套②唯一锚点） |
| PI | 去掉占位候选 | `+6 -7` | 上面「踩到的断言」那 7 条 |
| PJ | 显示值改回入参派生（非受控） | `+8 -5` | 晚到（四件套④）+ 新建 + 移出失败 + **移入失败** + 读屏 |
| PK | 先改名再移动 | `+12 -1` | 移出失败那条（断言 `after.name == '工作'`） |
| **PL** | **失败时顺手清空已选归属**（复核 P1 的那个 bug） | `+12 -1` | **只有新加的「移入失败」那条红** ⇒ 原来那 12 条一起放过了这个 bug，复核的判断被复现证实 |
| PM | 候选菜单永不展开（`onChanged: null`） | `+2 -11` | 11 条红，含 320 那条（`openMenu` 自带的"菜单真的开着"自检咬住了） |
| PN | 嵌套文件夹只显示自己的名字（丢父链） | `+12 -1` | 只有「嵌套父 / 子」那条红 ⇒ FR-1 的这半句以前是 0 覆盖（复核 P2） |

**PA 第一次跑出来的不是"红"，是 8 分钟不退出 —— 根因在我自己的用例里**：
`晚到` 那条用了单订阅 `StreamController`，`addTearDown(controller.close)` 的 `done` future 要等"有订阅者收完"才完成；
develop 字节的弹层根本不 watch `foldersStreamProvider` ⇒ 没人订阅 ⇒ tearDown 永久挂起，
探针把"红"伪装成"没结论"。改成 `broadcast()` 后同一份字节一秒收口 `+1 -12`。
教训：**探针跑不完先怀疑夹具**，别把"runner 不退出"读成"实现没问题"。

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

计数对账：`+911 = 898 + 13`。
**基线 898 是本轮自己实测的**：`git worktree add --detach /tmp/r68-baseline origin/develop` 后在该副本里跑
`flutter test --exclude-tags 'golden || performance' --concurrency=1` ⇒ `02:53 +898 ~26: All tests passed!`
（日志 `/tmp/r68/baseline_develop.log`）。13 = 本轮新增用例数；`~26` 与基线一致，未新增 skip。
（第一版这里写的是"沿用第 64 轮实跑值，见 `specs/045-sort-direction/tasks.md`"——复核指出
**那个目录在本分支与 `origin/develop` 上都不存在**（`git ls-tree origin/develop specs/` 最大 044），
引用不可达 ⇒ 已换成本轮可复现的量法，而不是继续 hedge。）
`pubspec.lock` 未进提交：`git log --stat origin/develop..HEAD -- pubspec.lock` 为空。
**门禁必须带镜像 env**（`source ~/development/env-flutter.sh`）：不带时 `flutter analyze`/`test` 的隐式 `pub get`
会把 `pubspec.lock` 的 150 行 `url:` 从 `pub.flutter-io.cn` 翻成 `pub.dev`（复核在副本上实测）
⇒ 本表这些"`git status` 为空"只在带镜像时成立；CI（`Jenkinsfile:205-207`）不设镜像，这条也解释了为什么 lock 不能随手提交。

## 复核（第 1 版 `VERDICT: FAIL`：1 条 P1 + 5 条 P2 + 1 条 nit，全部采纳）

复核员在 `/tmp/rev68-copy` 副本上做变异，`/tmp/wt-flutter-339` 未被改动（跑完 `status --porcelain` 为空）。
逐条回源复验后的处置：

| 发现 | 我的复验 | 处置 |
| ---- | -------- | ---- |
| **P1** ③「失败保留已加载数据」假绿：原用例从「项目」点「无」，与"失败时顺手清空归属"这个 bug 完全同形；catch 里加 `_folderLocalId = null` 后 10 条全绿 | 我独立跑同一变异（PL）⇒ 同样 `+10` 全绿。判断成立 | **采纳**。新增「移入失败（原来没有归属）」一条：从无归属清单进入、选「项目」、失败后断言界面仍是「项目」且库里没写。补完后同一变异 `+12 -1` 只红在新那条 |
| **P2** 320px 那条没证"候选菜单真的展开了"（`find.text('项目')` 对开/关都成立；删掉那次 tap 仍全绿） | 复现：PM（`onChanged: null` ⇒ 菜单永不展开）改前也是 12 条里只红 11 条不含此断言 | **采纳**。改用带自检的 `openMenu`（内部 `expect(menuItems, isNotEmpty)`）⇒ PM 现在红在它 |
| **P2** 计数出处指向不存在的目录（`specs/045-sort-direction/` 本分支与 develop 都没有） | `git ls-tree --name-only origin/develop specs/` 最大 `044-kanban-groups` ⇒ 复核对 | **采纳**。基线改成**本轮实测**：`/tmp/r68-baseline`（develop 副本）跑出 `+898 ~26` |
| **P2** FR-1 的「嵌套文件夹显示成 `父 / 子`」0 覆盖（夹具只有一个顶层文件夹），但 `[x]` 已勾 | 夹具确实只 seed 一个无 parentId 的文件夹 ⇒ 主张超出证据 | **采纳**。新增「嵌套父 / 子」用例（PN 抽掉父链只红它）；这也是本轮第二次犯"勾了但没测"（同形于第 66 轮 PJ） |
| **P2** `created.folderId` 的 reason「否则同步会丢归属」被实现证伪：`sync_coordinator` 回放时按 `folderLocalId` 重算 `folderId` | 读 `sync_coordinator.dart:577-590` 与 `list_repository.dart:76/:134` ⇒ 复核对 | **采纳**。reason 改成"钉反范式缓存列"；并新增 `serverId=null` 的降级用例（这条路径原先全仓 0 覆盖） |
| **P2** 门禁 3 在无镜像环境不可复现（analyze 会把 lock 的 150 行 url 翻成 pub.dev） | 与第 67 轮同源，已在门禁段写明前置 | **采纳** |
| **nit** 注释里引的框架断言原文不准 | 本机 3.44.8 实际抛 `There should be exactly one item with [DropdownButton]'s value: …` | **采纳**，注释改成原文 |

复核也独立复现了 PA–PK 全部 11 条（数字与表一致）并确认：9 张黄金基线逐字节未变（`diff -rq` 副本 vs 原 worktree）、
本分支没碰 docs、矩阵 #19 在 develop 上仍是旧判未翻转。

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
