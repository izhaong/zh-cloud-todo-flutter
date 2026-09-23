# 任务清单：快速添加弹窗的「从模板添加」

分支 `feat/todo-quick-add-from-template`，基线 `develop@a1d7733`，Issue izhaong/zh-cloud-todo-flutter#287。
矩阵行：#6「添加任务」的模板面（同时消掉 #89 行「模板仍无笔记页/添加流程入口」那一格的前半）。

## 已做

- [x] **T001 取证到 SHA**：嘀嗒原文 `02-任务详情.md:346`（移动端 tab）「点击任务输入弹窗**下方**的「...」按钮，选择「**模板**」即可从模板添加任务」；
      本端 `task_quick_add_sheet.dart` 全文 173 行只有标题 + 优先级 + 取消/保存，零模板入口；
      模板的保存/应用只在详情页 `task_detail_pane.dart:2339/3559/3566-3586/3628-3651`。
- [x] **T002 红测先行**：`test/features/task/quick_add_from_template_test.dart` 8 例，基线一条都不过，
      失败信息精确指向缺失项 —— `Found 0 widgets with key [<'todo-quick-add-more'>] / means none were found but one was expected`
      （日志 `/tmp/r19-red.log`，原文 `00:01 +0 -8: Some tests failed.`）。
      写用例时自己制造过两处假阳性并已修：① 按标题查新建任务会连**模板的来源任务**一起数到（2 条），改为 `exceptId: source.id`；
      ② 「未登录」例原本 seed 了模板，而 `saveTask` 本身写一条 outbox ⇒ 「outbox 为空」是假断言，该例改为不 seed。
- [x] **T003 最小实现**：`task_quick_add_sheet.dart` 下方行首加 `PopupMenuButton`（key `todo-quick-add-more`，菜单项文案「模板」），
      选后 `showModalBottomSheet` 打开 `_QuickAddTemplatePicker`（root key `todo-quick-add-template-sheet`），
      行内 `添加` 走 `templates.taskSeed(t)` → `taskRepository.create(listId/parentTaskId/title/description/priority)`，
      提示沿用详情页既有「已应用模板“X”」；空态「暂无本地模板」；仓储 `null` ⇒「请先登录」。
      未新增创建路径、未改 `pubspec.yaml`（`file_picker: ^11.0.2` 已在 `:41`，本切片不需要它）。
- [x] **T004 反向探针 6 条**（脚本 `/tmp/r19_probes.py`，每轮摘完立即还原并 `cmp -s`）：

      | 探针 | 摘掉什么 | 实测红用例 | 归因 |
      | ---- | -------- | ---------- | ---- |
      | PA | 整个 `PopupMenuButton` | **8 条全红** | 入口不存在 ⇒ 全部判据失效，符合预期 |
      | PB | `parentTaskId: widget.parentTaskId,` | 2 条（第 3、第 6 例） | 第 6 例也红 = 失败路径本身就经由 parent 归属校验，不是巧合 |
      | PC | `description: seed.description,` | 1 条（第 2 例） | 丢模板说明被咬住 |
      | PD | `if (_applyingTemplate) return;` | 1 条（第 7 例） | 守卫确被同帧双 tap  exercised |
      | PE | 未登录分支的 `_toast('请先登录')` | 1 条（第 5 例） | 「点了没反应」会被抓到 |
      | PF | `on StateError catch` 那一支 | 1 条（第 6 例） | 只剩通用文案 ⇒ 断言原因的用例红 |

      六条 `restore cmp=identical` 全部成立。
- [x] **T005 `dart format` 门禁抓到自家新文件不合规**：`--output=none --set-exit-if-changed` 首轮
      `Changed test/features/task/quick_add_from_template_test.dart` / `exit=1`（lib 文件 `exit=0`）⇒ 本轮新写的文件真修过，
      不是存量欠债。只 format 这一个文件（未整仓原地格式化），复跑 8 例仍绿，并在新字节上重跑全部探针。
      注：这次红只存在于终端输出，**没有单独落日志文件**（最终态绿的那次才在 `/tmp/gate-036.log`）。
- [x] **T006 六项门禁跑在最终字节**：见下表，日志 `/tmp/gate-036.log`。
- [ ] **T007 只读复核拿到 VERDICT 并逐条处置**：复核在跑（手段见「限制」），结果与处置回填本节。
- [ ] **T008 回写矩阵行**：#6 与 #89 两行的「仍缺」要划掉「快速添加无模板入口」，状态按合并情况写；未合并前只写「已实现待合并」。**待做**。

## 门禁（最终字节，日志 `/tmp/gate-036.log`）

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 两个显式文件 | `Formatted 2 files (0 changed)` / `exit=0`（首轮 `exit=1`，T005 已真修） |
| 2b 同检查跑在 `git show HEAD:` 版 | `Formatted 1 file (0 changed)` ⇒ HEAD 里的 lib 文件本就合规，本轮没新增排版欠债（test 文件是新增，无 HEAD 版） |
| 3 `flutter analyze` | `No issues found! (ran in 1.7s)` |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:53 +717 ~26: All tests passed!` |
| 6 `flutter build web --release …` | `✓ Built build/web`（`Compiling lib/main.dart for the Web... 19.6s`） |
| 7 `test/goldens` 改动数 | `0` |
| 8 sha256 | `7f12bc08` `task_quick_add_sheet.dart` / `8e46ebba` `quick_add_from_template_test.dart` |
| 9 工作区脏文件 | ` M pubspec.lock`（本机新 SDK 重解析，按口径不入库）+ 本轮 lib/test 与 specs/036 三件套 |

**同基线复算**：`develop@a1d7733` 非 golden = **709**（`/tmp/base-034.log`）；本轮 8 例 ⇒ 期望 `709 + 8 = 717`，与第 5 项原文一致；
跳过 26 未变；golden 9 张 0 改动、`test/goldens` 无 diff ⇒ 没有顺手改基线，也没有重录。

## 限制（不算通过证据的部分）

- **复核手段替换**：`claude` CLI 本机不可用（`unrecognized_model`），改用本会话只读子代理审本轮 FR（要求它反向攻击 FR 符合度、
  用例假阳性、静默丢数据、失败路径、不可追溯的数字）。
- **依赖集**：门禁跑在本机 `pubspec.lock`（本机重解析，不入库）之上，CI 解析的是仓库 lock ⇒ 本地绿不覆盖远端解析差异。
- **平台面**：本地 Dart 门禁不替代 iOS/Android 编译、真机行为、双设备同步；`build web` 只证明 Dart 侧可编译到 web。
- **黄金覆盖面**：9 张黄金不泵 `TaskQuickAddSheet` ⇒ 只证明既有画面无回归，**不证明本入口在真实视觉基线里长什么样**。

## 仍缺（诚实清单）

- 桌面端两条 IA 未做：「输入框下拉按钮 → 从模板添加」（`02-任务详情.md:354`）与「输入 `/` 打开斜杠菜单 → 从模板添加」（`:358`）。
  斜杠菜单全仓 0 命中，是 #6 的独立一面，不属本切片。
- 模板只带 `title/description/priority`（`template_repository.dart:44-48` 的 `contentJson` 就这三个键）⇒
  嘀嗒模板里可能承载的截止时间/提醒/检查事项/标签**在保存侧就没入档**，本切片不去扩内容格式（会改同步 payload 与既有已验收的保存路径）。
- 模板弹层只提供「添加」，没有嘀嗒模板管理面（列表页改名/删除/模板库）⇒ 属矩阵 #89 的另一格缺口。
- 已选模板后无法二次确认或撤销（即刻建任务），与详情页「应用」一致；若人工在嘀嗒上核到「选择后是预填」，本行结论要改。
- 矩阵行状态翻转要等合并；未合并前只写「已实现待合并」。

## 下轮入口

1. 等只读复核 `VERDICT`（两轮封顶）；`FAIL` 就照结论改，不采纳的在本文件写理由。
2. 回写矩阵 #6 / #89 两行（划掉「快速添加无模板入口」，补 `文件:行号` 与本切片计数），并在 `zh-cloud-docs` 上提交。
3. 合并是人的动作：!286（specs/035）与本 PR 待合并；合并后再 bump 父仓 submodule 指针。
