# 实现计划：成就墙导航入口

## 落点

| 变更 | 文件 | 说明 |
| --- | --- | --- |
| 入口行 | `lib/`lib/features/settings/settings_route.dart`6`（「账号」分组内，账户安全之后、退出登录之前） | `_Tile(icon: emoji_events_outlined, title: '成就与勋章', subtitle: '成就值、等级与勋章墙；成就值每天凌晨更新')` + `Navigator.push(AchievementPage())`；沿用本页既有 `_Tile` 形状，不新增组件 |
| 用例 | `test/settings_achievement_entry_test.dart` | 4 条：直达真成就墙（含分组顺序）/ 失败可重试 / 320px+1.3 倍字体 / 读屏标签含名称与口径 |
| 既有用例加固 | `test/native_entry_page_test.dart:280-283` | 「账号」分组多一行后，默认 800x600 视口里「原生增强」贴到折线外，`tap` 不会自己滚动 ⇒ 补一行 `ensureVisible` |

本 PR 只 stage 上表三项 + 本 `specs/028-todo-achievement-entry/` 目录。

## 顺序（红 → 小 → 绿）

1. 先写用例并跑到失败，失败信息必须精确指向缺失项（实测：`Found 0 widgets with text "成就与勋章"`，
   同一批对照全红，天然通过的为 0（复算：`flutter test test/features/achievement/achievement_page_test.dart`，见 tasks.md 的门禁表））。
2. 只加入口行，不动 dock、不动 hub、不动任何子页 chrome。
3. 六项门禁在最终状态一次跑完并留日志（`/tmp/gate-028-final2.log` —— 含既有测试加固之后的那一次）。
   前两份日志都留着：`/tmp/gate-028.log` 第 2 项是真红（`Formatted 2 files (2 changed) / exit=1`），
   `/tmp/gate-028-final.log` 早于 `native_entry_page_test` 的加固 —— 不拿修好之后的那份冒充第一遍。
4. 只读复核拿 `VERDICT`；`FAIL` 就照结论改，不采纳的发现要在 `tasks.md` 写理由。
5. 回写 `tasks.md` 与矩阵 #76–78（落点端加 `FL`、证据引本切片文件行号）。

## 判别性自证（避免「绿但不验任何东西」）

- 「直达真成就墙」里额外断言 `find.byType(EfficiencyHubPage)` 为 `findsNothing`：
  入口被改成绕道 hub 时这条会红（复核实测：改推 hub ⇒ 3 条红）。
- 分组**顺序**断言 `containsAllInOrder(['账户安全','成就与勋章','退出登录'])`：
  在它之前把 `_Tile` 整块搬到「任务」分组，四条用例全绿 —— 复核实测搬组后只有这一条红。
- 字体用例不靠外部探针，而是在 push 出来的 `AchievementPage` 的 context 上自检
  `MediaQuery.textScalerOf(...).scale(10) ≈ 13`；档位没真传进路由时该断言必红
  （复核按 026 同款负对照复跑：把档位改回 1.0 ⇒ 该条红 `Actual: <10.0>`）。
- 读屏用例必须开 `ensureSemantics()`（否则 `bySemanticsLabel` 恒 0 命中），并按本仓既有写法
  `try/finally` 释放句柄（否则测试末尾报 `A SemanticsHandle was active`）。

## 实测纠偏（写下来，别按纸面论证）

- **复核的第一条判定被我自己推翻**：它说「`ListTile` 的 title 与 subtitle 是两个独立语义节点」。
  我按那句把断言锚成 `^成就与勋章$` + `findsOneWidget`，结果 0 命中；dump 出真实 label =
  `'成就与勋章<NL>成就值、等级与勋章墙；成就值每天凌晨更新'` ⇒ **同一张 `_Tile` 合成一个节点，名称在前、口径在后**
  （复核第二轮自己复跑后认了这个结论）。用例与 FR-005 措辞都按实测改写。
- **复核的 lock 结论我先否后肯，两边都记**：它说「34 个包真升了版本」。我第一次用自写解析器数出
  「只有 1 个（`jni`）」，据此回怼复核 —— **那是我的正则把包名锚错层级造成的假阴性**；
  换成 `-U12` 上下文里就近取 `name:` 再重测，复核的数字是对的：
  版本变化 **34 个包**（`dio 5.10.0→5.11.1`、`meta 1.17.0→1.18.0`、`built_value`、`url_launcher_*` 全套、
  以及 `xml 6.6.1→7.0.1` 大版本），另有 **69 行 sha256** 被改写、`url` 在 `pub.dev` ⇄ `pub.flutter-io.cn`
  之间被刷、`sdks` 底线从 `dart >=3.11.4 / flutter >=3.38.4` 抬到 `>=3.12.0 / >=3.44.0`。
  ⇒ 成因是「本机 SDK 高于 lock 记录的底线 ⇒ 整树重新解析」，镜像只解释 `url` 那部分。
  教训：**用自己写的脚本核别人的结论之前，先探针那个脚本本身**（数错一个数，就会把对的判成错的）。

## 提交纪律（关于 `pubspec.lock`）

- 本切片不 stage `pubspec.lock`（227+/219- 全是上面那种解析漂移，与成就入口无关）。
- 「不随功能 PR 提交 lock」是**本轮目标里给 human 的约定**，不是本仓文档条文：该文件被 git 跟踪，
  `git log -- pubspec.lock` 有 5 条功能提交动过它（最近 `94c3728`）。写清楚免得下一轮误当成仓库既有规范。
- 风险如实登记：本地按新 SDK 解析跑绿 ≠ CI 按仓库已提交的 lock 跑绿。本切片没有改依赖，
  所以不触发这条；一旦哪轮真改了依赖，必须连带提交 lock 并在 PR 里说明。
