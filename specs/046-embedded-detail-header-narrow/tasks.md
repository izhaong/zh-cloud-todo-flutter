# 046 任务清单 — 嵌入态操作头窄面板折叠（Issue #279）

分支 `fix/279-embedded-header-overflow`（基线 `origin/develop@9032005`，即 !303 已合并之后）。
**待开 PR**，未合并 ⇒ 本轮不翻任何矩阵状态。

## 已完成

- [x] 实测溢出条件（探针表在 `spec.md` 开头）：**面板 < 356dp 就溢，与字号无关** ⇒ Issue #279 标题里
      「+ 1.3 倍字体」这条归因是错的，已在 Issue 留言更正。
- [x] 红测先行：`test/features/task/embedded_detail_header_narrow_test.dart` 首跑 `+0 -3`
      （溢出 / 菜单两项 / 读屏语义三条红，宽屏不重复那条绿）⇒ 见 `/tmp/g61/`（红测在实现前跑的读数记录于本轮对话，
      文件级日志未单独留档，只有实现后的绿跑日志；不假装存了一份红日志）。
- [x] 最小实现：`lib/features/task/task_detail_pane.dart`
      —— `_embeddedActionRowMinWidth = 356` 常量 + `_buildEmbedded` 的 `LayoutBuilder` 折叠
      + `_embeddedMoreActions(task, {required foldedActions})` + `_onCompactMoreAction` 两条 case。
- [x] 撤掉测试里吞异常的 pin：`test/features/task/link_parent_task_test.dart:267-278`
      原来是 `expect(preExisting, contains('RenderFlex overflowed by 36 pixels'))`（"先吃掉这条既有异常"），
      现在换成 `expect(tester.takeException(), isNull, reason: '操作头溢出（Issue #279）应已修掉')`。
      ⇒ 这条文件 `+14` 全绿。
- [x] 六项门禁跑在**最终字节**上（日志 `/tmp/g61/`）。
- [ ] 只读复核（VERDICT 待回写）。
- [ ] 矩阵：本轮是治理修复，不动 89 行状态；`#8 任务详情与编辑` 那一行的"操作头折叠形状"要不要写进去，
      等复核结论后判（**不在没读原文前乱改**）。

## 六项门禁（最终字节）

| # | 门禁 | 读数 |
| - | ---- | ---- |
| 1 | `git diff --check` | rc=0（工作树范围；提交后再跑 `git diff --check origin/develop HEAD` 同 rc=0，见 PR 追加提交） |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 3 个显式文件>` | 第一跑 `Formatted 3 files (2 changed)` ⇒ 对**本轮文件**原地格式化后重跑：`Formatted 3 files (0 changed)` rc=0。**没有**跑过全仓格式化 |
| 3 | `flutter analyze` | `No issues found!` rc=0（中途报过 1 条 `unnecessary_brace_in_string_interps`，已改） |
| 4 | `flutter test --tags golden` | `00:04 +9: All tests passed!` ⇒ **9 张基线一张都没重录** |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:25 +903 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

**用例数可加减核**：`+903` = develop 基线 `+898`（第 55 轮 `/tmp/g58/baseline.txt`，同一 develop 时代）
+ 本文件 **5** 条 = 903。`git status --short` 只有 3 项改动（1 实现 + 1 测试改动 + 1 新测试），
**没有 `pubspec.lock`**；`test/visual/failures/` 是中途那次 golden 失败留下的临时 diff 图，已删（未跟踪）。

## 反向探针（全部跑在最终字节上，跑完 `md5` 校验实现文件与跑前逐字节相同）

| # | 改法 | 期望 | 实际 |
| - | ---- | ---- | ---- |
| PF | `_embeddedActionRowMinWidth = 0`（永不折叠 ⇒ 7 枚图标回到 320px） | 溢出那条必须红 | `+2 -3`（溢出 + 两条菜单相关全红） |
| PG | `= 99999`（永远折叠） | "宽面板不折叠"那条必须红 | `+4 -1`（正是 `嵌入态宽面板不折叠…`） |
| PH | 删掉菜单里的 `if (foldedActions) … delete` 一项 | 依赖它的两条红 | `+3 -2` |
| PI | `case delete:` 改成空 `return` | 第 2 条（点删除要给确认框）红 | `+4 -1` |
| PJ | `case moveToInbox:` 改成空 `return` | 第 2 条（listId 要变 inbox）红 | `+4 -1` |
| PK | 菜单文案换成自创的「移到收集箱」 | 术语断言红 | `+3 -2` |

⇒ 折叠阈值、两个动作分支、菜单文案三处都是**有断言在守**的，不是"看起来对"。

## 本轮踩到的两件事（记下来免得重演）

1. **harness 自己会造红。** 第一版"移动后面板要关掉"的断言红，根因不是实现，
   是我把面板挂在 `MaterialApp.home:` 上 —— 没有可 pop 的路由，`_close()` 自然什么也不做。
   改成"真路由 push"后又红一次：嵌入态正文里有 `TextField`（`task_detail_pane.dart:2406`），
   路由里不给 `Scaffold` 就没有 Material 祖先，报 `No Material widget found`。
   ⇒ 测"关闭/返回"这类语义，宿主拓扑必须和生产一致，否则会去改本来正确的实现。
2. **无条件折叠会撞 2 张黄金基线。** 先跑过一次无条件版本，`wide-selected` / `compact-selected` 直接红。
   ⇒ 在"必须停下来问重录基线"之前，先找有没有**按实际宽度分形状**这条更小的路 —— 这次有。

## 下一轮入口

1. 等只读复核的 `VERDICT`，按条处置后把结论回写本文件与 `spec.md`。
2. Issue #279 的收尾：本 PR 合并后，把矩阵里与"详情操作头"相关的行按新形状复核一遍（尤其 `#8`），
   然后再关单（合并前不关，避免"单子关了但 develop 上没有"）。
3. `spec.md` 仍缺第 1 条：整页态 `_buildPage` 的图标栏没有等价的"宽度不够就折"，需要它自己的溢出证据再动。
4. 嘀嗒《任务详情》`:399` 的「自定义任务详情操作菜单」（编辑 / +/- 置顶 / 拖拽排序）整面无 ⇒ 属未实现的一面，
   排轮次时按矩阵对应行判，别拿本轮的写死折叠冒充。
