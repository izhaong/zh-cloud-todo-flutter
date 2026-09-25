# 任务清单：清单动作表补「共享协作」入口（specs/053 / FL Issue #359 / 矩阵 #52）

分支 `feat/359-list-share-entry`，基线 `origin/develop@9032005`，PR !365。
提交 `727b646`（实现 + 用例 + 规格）。

## 完成情况

- [x] `spec.md` 来源表：《07-共享与协作/01-如何共享清单》`:6`/`:8` 逐字引用（基准 docs `origin/develop`）
- [x] 现状取证：`showListActions` 定义 `list_actions.dart:63` 唯一调用点 `sidebar.dart:626`；
      `ListMemberPage` 唯一调用点 `task_detail_pane.dart:1332`；`共享协作` 在 develop 的 `lib` **0 命中**
- [x] FR-1/FR-2 动作表补第三项 + `openListCollaboration`（`serverId` 前置校验、提示语、开成员页一份口径）
- [x] FR-2 的去重**真的做了**：任务详情面板的 `members` 分支改为调用同一函数，
      不再就地 `push` `ListMemberPage`（成对 grep 判据见下）
- [x] FR-3 未同步的可见原因，措辞两处统一成「清单尚未同步，无法打开共享协作」
- [x] FR-4 可达性边界钉住（且按**实测机制**写：`_SmartRow` 根本没有 `onLongPress`，
      是结构性拿不到，不是我们显式判了 `:6`）
- [x] 四件套：①320×568 + 1.3 在 sheet 自己的 context 上量（档位自检 + 遍历 `RenderFlex` 量越界）；
      ②读屏 label 全等 + `isButton` + `bySemanticsLabel` 成对；③失败提示出现时侧栏仍在；
      ④「过期响应不覆盖新响应」**不适用**（零异步新增，理由见 `spec.md` 五-4）
- [x] 反向探针六条 X1–X6 + 成对 grep 判据，`/tmp/r79/probes-all.log` 末行「异常计数 = 0」
- [ ] **六道门禁读数未填** ⇒ 跑在终态字节上的那张表还欠着，本节不得当作已通过
- [ ] 只读复核未派 ⇒ 同上，欠着
- [ ] 矩阵 #52 回写（形态偏差 + 「添加新成员」无对应控件这两条要落进说明格；未合并只写「已实现、未进 develop」）

## 红测 → 绿测

```
$ flutter test test/features/list/list_share_entry_test.dart
00:01 +6: All tests passed!          # 首版是 3 绿 / 3 红，见下"本轮我自己造成的缺陷"
$ flutter test test/collaboration_widget_test.dart test/features/list/list_share_entry_test.dart
00:01 +16: All tests passed!         # 既有协作套件 10 条不回归
```

## 反向探针（六条，`/tmp/r79/probes-all.log`）

每条都：起跑前 `lib` + `pubspec.lock` 干净 → 对照组先绿 → 锚点干跑（`check` 模式 6/6 命中 1）
→ 打补丁跑 → `cmp -s` 逐字节还原。判据面 = 本面新套件；参考面 = 既有 `collaboration_widget_test.dart`。

| 编号 | 摘掉的是什么 | 读数 | 红在哪 |
| --- | --- | --- | --- |
| X1 | `serverId` 缺失时兜一个假 id（未同步也硬推成员页） | `+5 -1` | 判据面 1/1 命中「清单还没同步时不跳转…」；参考面 `+10` 绿 |
| X2 | 动作表里根本没有「共享协作」这一项 | `+1 -5` | 判据面 4/5 命中；**第 5 条红是 320px 那条**（它的 `find.text('共享协作')` 守卫也咬得住）—— 不在预期名单里，如实记为"额外的覆盖面"而不是异常 |
| X3 | 顺序反了：「共享协作」压在「编辑」之前 | `+5 -1` | 1/1 命中排序那条 |
| X4 | 未同步时静默 `return`，不给原因 | `+5 -1` | 1/1 命中「给得出原因」 |
| X5 | 开成员页不带清单名 | `+5 -1` | 1/1 命中「带的是这条清单」（顶栏整串 '协作成员 · 清单名' 那条判据） |
| X6 | 只把共享协作的 key 改名（键消失、文案仍在） | `+1 -5` | 5/5 命中：证明四条判据钉的是**键**，不是只钉文案 |

成对 grep 判据（同一日志末尾）：

```
ABSENT  详情面板就地 push 成员页（ListMemberPage）        命中 0（期望 0）
PRESENT openListCollaboration（1 定义 + 2 调用点）        命中 3（期望 3）
PRESENT 正对照：动作表仍是 showModalBottomSheet 起的       命中 2
PRESENT 正对照：侧栏仍把长按接到 showListActions           命中 1
```

## 本轮我自己造成的缺陷（逐条登记，不藏）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| 首版 6 条里 3 条红：`Found 0 widgets with type "ListMemberPage"` | 我以为是跳转坏了，其实是**顶栏文案形状猜错**：成员页 AppBar 打的是 `'协作成员 · 清单名'`（`list_member_page.dart:183`），不是单独一个 `Text(清单名)`；断 `find.text(标题本身)` 是越界要求 | 改成断整串（由 `pushed.title` 现拼，不硬编码清单名）。**同一文件 138 行的 `listServerId` 早已绿** ⇒ 跳转本身没坏，红的是我的断言口径 |
| `Found 0 widgets with key [<'todo-sidebar'>]` | 我引了一个** develop 上不存在的键**（侧栏那些行是一组 `todo-sidebar-row-*`） | 改 `find.byType(Sidebar)`；`spec.md` 五-3 的口径同步改掉 |
| `pageBack()` 之后弹层仍在 | 动作表是 `showModalBottomSheet`，`pageBack()` 找路由返回按钮（实测 `Found 0 widgets with type "CupertinoNavigationBarBackButton"`）⇒ 它关不掉 sheet，于是"收集箱没有这一项"是在**旧弹层之上**测的 ⇒ 假绿通道 | 先用 `ModalBarrier` 关，实测关掉后 `scrollUntilVisible` 又抛 `Bad state: No element`（那棵树的滚动容器不可依赖）⇒ **最终改成反例另起一条用例、正对照留在第 1 条**，不在同一棵用过的树上断负结论 |
| 一条用例里 `_pump` 两次，drift 打 `WARNING … AppDatabase multiple times` | 为了在同一条里做"正对照 + 反例"而复用了场景 | 拆成两条用例各自一棵树；正对照的引用写进注释。负向断言不建立在"上一棵树的残留状态"上 |
| 未使用的 `providers.dart` import | 改版过程中留下的 | 删（门 3 `flutter analyze` 会报 `unused_import`，不是可忽略项） |

## 遗留与下一轮

- **门禁与复核未做**（见上两格）⇒ 本 PR 不谈合并。
- 形态偏差两条（入口在侧栏长按而非清单详情右上角「···」；「添加新成员」在本仓是内联提交流程、无对应控件）
  要写进矩阵 #52 说明格，**不能算"已与嘀嗒一致"**。
- 下一轮候选（不撞本单也不撞 !364）：docs #104 里剩下 5 条**非第三方凭据**的弱证据行
  #7/#11/#19/#21/#24（`check_parity_matrix.py` 现算：13 条告警里 8 条属 #55–64/#66 那族，
  按口径不排进自主轮次）。
