# Todo 成就墙导航入口任务

- [x] T001 红测：设置页缺「成就与勋章」入口（4 条用例首跑全红，失败信息精确指向缺失项）。
- [x] T002 实现：`settings_route.dart`「账号」分组加一行，直达既有 `AchievementPage`（不新建页、不复制 UI、不接 hub）。
- [x] T003 用例强度补强：分组顺序断言 + 读屏标签按实测改写 + 1.3 倍档位路由内自检 + hub 绕道负断言。
- [x] T004 复核 FAIL 的必须改全部落地（格式 / lock 说明 / 顺序断言 / tasks.md / 既有 `native_entry_page_test` 补 `ensureVisible`）。
- [ ] T005 矩阵 #76–78 回写与状态翻转（翻转须引**已合并** SHA）。

## 执行证据

- 2026-09-23：RED 先行。`flutter test test/settings_achievement_entry_test.dart` 首跑
  `00:00 +0 -4: Some tests failed.`，四条失败信息分别是指向缺失项本身：
  `Found 0 widgets with text "成就与勋章"`（3 条）与
  `Found 0 widgets with a semantics label matching the pattern "成就与勋章"`（读屏那条）。
  复核第二轮按 develop 版 `settings_route.dart` 逐字复现了这个红。
- 2026-09-23：实现只有 12 行（`lib/`lib/features/settings/settings_route.dart`6`）+ 1 行 import + 1 行文档注释。
  走 `SettingsRoute`「账号」分组而不是 hub：理由与实测代价写在 `spec.md` 的
  「为什么不采用 specs/027 的 hub 接线路线」一节（四个已验收子页各自带 `AppBar` 与动作，
  嵌入态等于同时重写它们，还要让 hub 在沉浸专注时收掉自己的 bar）。
- 2026-09-23：两轮只读复核（`claude` CLI 坏掉的替代方案：本会话只读子代理，理由见 specs/027 的同类记录）。
  **第一轮 `VERDICT: FAIL`**，三项必须改：① `pubspec.lock` 不得进 PR；② `dart format` 两处真红
  （我的门禁第 2 项当时 `exit=1`，日志留着）；③ 缺分组/顺序断言（把 `_Tile` 搬到「任务」分组四条全绿）。
  三项都改；另采纳的登记项逐条列在下面。**第二轮 `VERDICT: FAIL`**，必须改是文档层：
  「已在矩阵侧另行更正」当时是空的、lock 成因归错、门禁日志留的是修格式前那份、缺 `tasks.md`、
  stage 清单数不上 —— 五项逐条改；它顺带指出的既有测试余量问题（800x600 下「原生增强」只剩 9.3px）
  也补了 `ensureVisible`。**没有跑第三轮，也没有 `VERDICT: PASS`**：按本仓「长耗时复核不得循环」的约定，
  两轮已给结论，第二轮的必须改全在文档层 + 一行测试加固、逐条可直读核验 ⇒ 本轮能主张的只是
  「两轮 FAIL 的必须改全部落地」，不是「复核通过」。
  其中「已在矩阵侧另行更正」这句当时是空的，现在已真落在
  `zh-cloud-docs` 的 `dida-parity-matrix.md` #76–78 行（含 8/9 黄金图覆盖更正）。
- 2026-09-23：**两处「复核说错、我说对」与「我说错、复核对」的实测记录**（不靠纸面论证）。
  ① 复核说 `ListTile` 的 title/subtitle 是两个独立语义节点 —— 我用锚定正则 `^成就与勋章$` 试出 0 命中，
  dump 出真实 label `'成就与勋章<NL>成就值、等级与勋章墙；成就值每天凌晨更新'`，是**合成一个节点**；
  FR-005 与用例照实测改写。② 复核说 lock 漂移里有 34 个包升了版本 —— 我第一次数成 1 个并回怼，
  实际是我自写正则把包名锚错层级的假阴性；重测按包名逐个数，样本含 `dio`、`meta`、`xml 6.6.1→7.0.1`
  + 69 行 sha256 + `sdks` 底线抬高。⇒ 反向探针同样适用于「我写的核对方的脚本」。
- 2026-09-23：门禁在最终状态跑（`/tmp/gate-028-final2.log` —— 这一份才是含 `native_entry_page_test` 加固之后的状态；
  首跑 `/tmp/gate-028.log` 的格式项真红、第二跑 `/tmp/gate-028-final.log` 早于该加固，三份都留着）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 对三个 dart 文件
  `Formatted 3 files (0 changed)` exit=0；`flutter analyze` `No issues found!`；
  `flutter test --tags golden` `00:03 +9: All tests passed!`（**9 张基线未变**，`git status --short test/goldens test/visual` 为空）；
  全量 `02:11 +713 ~26: All tests passed!`（= develop 基线 709 + 本切片 4，数目自洽）；
  `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。

## 未勾项与下一步

- T005 未勾：#76–78 的行状态要等本 PR 合并后引**已合并** SHA 才翻；本轮在矩阵里只把
  「没有任何导航入口」这一结论替换为「入口已实现待合并」，并顺手更正该行两处不实（详见 docs 仓同一批提交）：
  ① 原句「9 张黄金图只 pump `HomeShell()`，push 路由零视觉覆盖」只对 **8/9** 成立 ——
  `test/visual/todo_workspace_golden_test.dart:112-114` 后 `mobile-detail` 经 `:130-140` tap 进
  `TaskDetailPage`，`:263-268` 就是拍它；② 该行引的四个 `AppBar` 行号各差 1（实际 17/14/18/1125）。
- 与 `specs/001-todo-dida-core-parity/spec.md:66` 的措辞冲突**已收口**：那条验收场景原写「打开效率中心的成就勋章页签」，
  本分支上已改成「打开设置页「账号」分组的「成就与勋章」」，与实装入口和已交付页面标题一致；
  `specs/028/spec.md` 的登记段同步改掉。hub 路线（四个子页 chrome 重写，或批准重录 9 张基线的 dock 第 4 按钮）仍不采纳。
- `lib/features/efficiency/efficiency_hub_page.dart` 仍是**无调用点的死页**（本轮不接线也不删，归属留给 specs/027）。
  本切片的用例还 import 它做负断言，将来按 027 结论删 hub 时要同步改 `test/settings_achievement_entry_test.dart:24-28`。
- 下一轮候选（都不需要外部条件）：#18 文件夹管理入口（要先申请黄金图重录）、
  #89 剩余面（摘要/模板接进 `features/note/note_page.dart` + 附件挂载入口，
  并补取证 `core/api/attachment_upload_api.dart` 的调用方）、矩阵 A 段 43 行逐行复校。
