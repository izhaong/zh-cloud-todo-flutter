# 050 · 计划（Issue #312 两子面：解散入口可达 + 用词照抄）

基准 `origin/develop@9032005`；分支 `feat/312-folder-disband-entry`。判据与取舍见同目录 `spec.md`。

## 落点

| 文件 | 动什么 |
| ---- | ------ |
| `lib/features/folder/folder_actions.dart`（新） | `confirmAndDisbandFolder(context, folder)`：`AlertDialog` 标题「解散文件夹」、按钮「解散」；内部 `_DisbandFolderDialog` 是 `ConsumerStatefulWidget`，自己取 `folderRepositoryProvider` 并调 `delete`；失败 ⇒ 框不关 + `_error` 写在框里；`_busy` 同步闸门挡同帧连点 |
| `lib/features/shell/sidebar.dart` | `_FolderGroup.build` 的返回值包一层 `GestureDetector(onLongPress: …, behavior: deferToChild)`；新增一行 import |
| `lib/features/folder/folder_page.dart` | `_delete` 里那份自写的确认框删掉，改调同一个函数（用词随之变成「解散」） |
| `test/features/folder/folder_disband_entry_test.dart`（新） | 12 条：可达性 2（侧栏 + 真 HomeShell）、语义 4（解散生效 / 取消不写 / 连点一次 / 失败可重试）、**失败出口 2（仓库为 null 给提示、仓库后来就绪能重试）**、四件套 3（读屏、320px+1.3、手势不串味）、口径 1（FolderPage 走同一份） |

**不改**：数据模型、`FolderRepository`（解散语义本来就在）、路由表、后端契约、9 张黄金基线。

## 三个必须先想清楚的点

1. **`ExpansionTile` 没有 `onLongPress`** ⇒ 只能外面包 `GestureDetector`。
   `behavior: deferToChild` 是让"命中区"仍然归子节点：其下清单行自己有长按动作（specs/026），
   用 `opaque` 会让文件夹行在清单行的空白留白处也声称命中。命中仲裁是"最深的先赢"，
   所以子行的长按不会被父行抢走 —— 这条不靠推理，用例「手势不串味」钉着。
2. **失败不能靠 SnackBar**：解散是从确认框里发起的，框若先关再报错 ⇒ 用户看到的是一闪而过的条，
   且"框还开着"本身就是"没做成"的最直接证据。所以错误进框内 `Text`。
3. **`_busy` 必须是同步标志**：`FilledButton(onPressed: _confirm)` 的禁用态要下一次 build 才生效，
   同一帧连点两下会真的进 `_confirm` 两次。（我原先写"第二次会多打一条 outbox"——**复核 X5 实测不成立**：
   第二次走的是 `row == null` 的空分支，0 行可清、0 条新记录。闸门仍然要留，但它钉的是
   "只发一次解散"这条判据，不是防数据损坏。）

## 验证计划

- 红测：把 `sidebar.dart`/`folder_page.dart` 换成 develop 字节跑这个测试文件 ⇒ 实测 **12 条全红**（`+0 -12`）。
  注意 PA 只换这两个文件 ⇒ 说明「解散」这件事在 develop 上从任何入口都点不到，
  与 `spec.md` 现状判据（`FolderPage` 的唯一引用者 `ListPage` 无人挂）互相印证。
- 反向探针 PA–PI：见上（PA/PE 整批退回）+ 抽掉长按接线（PB）+ 抽掉 `_busy` 闸门（PC）+
  失败改成关框（PD）+ 标题改回「删除文件夹」（PE）+ FolderPage 回到自己那份框（PF）+
  仓库为 null 静默 return（PH）+ null 分支不复位 `_busy`（PI）。
  **PG 预期不红**（`deferToChild` 换成 `opaque` 没有可观测差异），结论如实记在 `tasks.md`，不声称覆盖。
- 四件套：320px + 1.3 打在对话框自己的路由上（`platformDispatcher.textScaleFactorTestValue`，
  包在 `home` 里的 `MediaQuery` 到不了 root Navigator 的弹层）；读屏按**实测的两个节点**分别断言。
- 六门禁跑在最终字节上，日志原文抄进 `tasks.md`。

## 相撞面（已实测）

`sidebar.dart` 与未合并的 **!351** 同文件：两边都只在 import 区加一行（各自的新第 9 行）⇒
`git merge-tree --write-tree` 报 `CONFLICT (content)`。**是真冲突但极小**，谁后合谁手动并两行；
`folder_page.dart`、`folder_actions.dart`、`test/features/folder/` 与各 open PR 的 `/pulls/N/files` 比对命中 0。
`list_editor_sheet.dart` **本轮故意不碰**（那是 !352 的地盘，「添加文件夹」排在它合并之后）。
