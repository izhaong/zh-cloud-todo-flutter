# 050 · 文件夹「解散」入口 · 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/312-folder-disband-entry`。Issue **#312**（矩阵 **#18**）。
判据、范围与取舍见同目录 `spec.md`；落点与实现要点见 `plan.md`。

## 勾选（只勾真满足的）

- [x] FR-1 侧栏**长按文件夹行** ⇒ 「解散文件夹」二次确认；确认后其下清单回顶层、直接子文件夹提升为顶层，两条都留 outbox
- [x] FR-2 取消 ⇒ 一个字都不写（读库 + 数 outbox 行数）
- [x] FR-3 单一口径：`FolderPage` 的那个按钮改调同一个函数，标题「解散文件夹」、按钮「解散」（探针 PF 证：让它退回自己那份就红）
- [x] FR-4 9 张黄金基线未重录（门禁 4 `+9`，`git status --short test/goldens` 为空；对话框是长按才出现的路由，不参与首帧）
- [x] FR-5 四件套（见下表；`_confirm()` 的两个失败出口各有用例，探针 PH/PI 证）
- [ ] #312 的另两子面：**`:18` 清单编辑器里的「添加文件夹」**（落点是 `list_editor_sheet.dart`，与本轮自己刚开的 !352 同文件同区域 ⇒ 排在它合并之后）、**`:12` 拖动清单建文件夹**（要改侧栏可见布局 ⇒ 先申请重录黄金基线）
- [ ] 「左滑解散」（`:30` 并列的另一种手势）**没做**，理由见 `spec.md`「本轮不做」第 3 条 ⇒ 这一面按"可达但少一种手势"记，不宣称一字不差
- [ ] 桌面端右键解散（`:30` 后半句）没做 —— 侧栏现在没有右键通道
- [ ] 只读复核 **待派**
- [ ] 矩阵 #18 回写 —— 本轮开工时 `state=open` 实测 9 条（!352 !351 !350 !347 !346 !322 !319 !314 !311），除 !352 外一条没合并 ⇒ 只能写「已实现待合并」，状态列不翻转

## 四件套（新增可见界面 = 那个确认对话框）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 字号打在 `tester.platformDispatcher.textScaleFactorTestValue`（弹层是 root Navigator 上的路由，包在 `home` 子树里的 `MediaQuery` 到不了它），视口 320×700，断 `takeException()` 为 null 且两个按钮 `hitTestable()` | `320px + 1.3 倍字号：确认框排得下且按钮可命中` |
| 独立读屏语义 | `AlertDialog` 的 title 与 content 实测是**两个**语义节点 ⇒ 分别用 `^解散文件夹$` 与 `确认解散"项目"` 断言，并加正向对照 `确认解散"生活"` ⇒ `findsNothing`（不写跨节点正则，那在本仓第 68 轮刚踩过） | `读屏念得出「解散文件夹」，且念的是被解散的那一个` |
| 失败保留已加载数据 | **三个**出口：`delete` 抛错 ⇒ 框不关 + 文件夹还在 + 错误写在框里 + 重试能成；`folderRepositoryProvider` 为 null ⇒ 同样不关框、给提示、库里不写；仓库后来就绪 ⇒ 提示清掉、重试真的解散 | `解散失败…` + `仓库在点确认时已不可用…` + `仓库后来就绪…` |
| 过期/重复响应不覆盖 | 连点两下只发一次 `delete`：假仓库用 `Completer` 门控（立即返回的 stub 会让第二次 tap 落在正在关闭的表面上 ⇒ 恒真绿），先断 `pending.length == 1` 再逐条回包 | `解散请求挂起时再点一次「解散」：只发一次` |

另有一条不属于四件套但同样关键的：**手势不串味**（`ExpansionTile` 外面包 `GestureDetector` 后，其下清单行的长按仍是清单动作）
⇒ `文件夹展开后，其下清单行长按还是清单动作（手势不串味）`。

## 反向探针（每条先证探针本身打上了：替换后字节必须与 HEAD 不同）

**口径：跑单文件** `test/features/folder/folder_disband_entry_test.dart`，12 条用例。
脚本 `/tmp/r69/probes.py`（崩溃也走 `finally` 还原），汇总 `/tmp/r69/PROBES_12.log`，跑完 `RESTORE cmp: SAME`。

| 探针 | 抽掉什么 | 结果 | 红在哪条 |
| ---- | -------- | ---- | -------- |
| PA | develop 字节（侧栏无长按 + FolderPage 仍是「删除文件夹」） | `+0 -12` | 12 条全红 ⇒ 这批用例整体就是红测 |
| PB | 侧栏不接长按（摘掉 `onLongPress`） | `+1 -11` | 11 条红；绿的仍是「FolderPage 走同一个框」那条（它不经侧栏） |
| PC | 去掉 `_busy` 同步闸门 | `+11 -1` | 「连点只发一次」那条 |
| PD | 失败也把框关掉 | `+11 -1` | 「解散失败：框不关…」那条 |
| PE | 用词退回「删除文件夹」/「删除」 | `+2 -10` | 10 条红（用词是判据，不是审美）；绿的 2 条是「取消 ⇒ 一个字都不写」与「手势不串味」，它们本来就不看文案 |
| PF | `FolderPage` 不委托、留自己那份（两份口径） | `+11 -1` | 「FolderPage 的那个按钮走同一个确认框」那条 |
| **PH** | **仓库为 null 时静默 return**（摘掉整段 `setState`） | `+10 -2` | 「仓库在点确认时已不可用」+「仓库后来就绪」两条 ⇒ 补测前这两支是 0 覆盖 |
| **PI** | null 分支给了提示但**不复位 `_busy`**（框会卡死） | `+11 -1` | 只红「仓库后来就绪：重试真的解散」⇒ 这条用例钉的不只是提示 |
| PG | `deferToChild` 换成 `opaque` | `+12`（**不红**） | 结论如实记：**这条用例不覆盖 `deferToChild` 这个选择**。长按点的仲裁是"最深先赢"，父行 `opaque` 也抢不走子行的长按 ⇒ 换掉它没有可观测差异。留着 `deferToChild` 是按语义（父行只在自身像素上接管手势），不声称有用例钉 |

## 门禁原文记录（跑在 tip `8273c56` 的字节上，日志 `/tmp/r69/gates_12.log`）

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 4 个显式文件>` | `Formatted 4 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 1.6s)`，`rc=0` |
| `flutter test --tags golden` | `00:06 +9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:42 +910 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

计数对账：`+910 = 898 + 12`。898 是第 68 轮在 develop 副本 `/tmp/r68-baseline` 实测的基线
（日志 `/tmp/r68/baseline_develop.log`，`02:53 +898 ~26`）；12 = `git diff --name-status origin/develop...HEAD -- test`
里唯一的 `A`（本轮新增的那个测试文件）的用例数。`~26` 未新增 skip。
`pubspec.lock` 未进提交（前提：门禁与 `source ~/development/env-flutter.sh` 同 shell）。

## 相撞面（实测）

`lib/features/shell/sidebar.dart` 与未合并的 **!351**（侧栏「显示标签」）**同文件**：
两边都在 import 区新增一行（各自的新第 9 行）⇒ `git merge-tree --write-tree` 报
`CONFLICT (content): Merge … sidebar.dart`。这是**真冲突但极小**（两行 import 并列，合并时都保留即可），
已在 PR 正文写明；其余 `folder_actions.dart`、`folder_page.dart`、`test/features/folder/`、`specs/050-*` 与各 open PR 命中 0。
`list_editor_sheet.dart` **故意没碰** —— 那是 !352 的地盘，`:18` 的「添加文件夹」排在它合并之后。

## 下一轮入口

1. #312 剩余：`:18` 清单编辑器「添加文件夹」（等 !352 合并后在同一个 sheet 里做）。
2. `:12` 拖动清单到另一清单上方建文件夹 ⇒ 要改侧栏可见布局，按约定先申请重录 9 张黄金基线。
3. `FolderPage` 与它的宿主 `ListPage` 在 develop 上仍**不可达**（`ListPage` 全仓无人 push）：
   新建/重命名这两件事还没有入口。`spec.md` 取舍 1 已记，本轮不顺手删；单独立项。
4. 矩阵 #18 的「已实现待合并」注记走 docs !105 留言，不再新开第 12 条同文件 PR。
