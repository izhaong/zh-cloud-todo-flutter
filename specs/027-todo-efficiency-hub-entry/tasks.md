# 效率中枢入口任务

- [x] T001 红测：三个 dock 入口进入 `EfficiencyHubPage`，「成就勋章」页签一次点击可达 `AchievementPage`。
- [x] T002 `EfficiencyHubPage` 增 `initialIndex`，`home_shell` 三个回调改推 hub。
- [x] T003 320px + 1.3 倍字体下中枢页签仍在、无渲染异常。
- [x] T004 六项门禁（9 张黄金图未重录且仍全绿）。
- [ ] T005 **本切片已回滚**，不产出可合并改动（见下）。

## 结果：实现做完、门禁全绿，然后被只读复核判 FAIL 并回滚

- 2026-09-23：RED 先行 `00:03 +0 -5: Some tests failed.`（dock 仍推单页，中枢根本不在树里）。
- 实现后本切片 `00:01 +5: All tests passed!`；六项门禁 `/tmp/gate-027.log`：
  `git diff --check` exit=0、`Formatted 3 files (0 changed)` exit=0、`No issues found!`、
  golden `00:03 +9`（未重录）、全量 `02:16 +729 ~26`、`✓ Built build/web`。
- 只读复核（本会话子代理，`claude` CLI 配置坏）判 **`VERDICT: FAIL`**，两条 Blocking 都成立，已按结论**整体回滚**：
  - **B1 成立（真回归，比「可达」更重要）**：`EfficiencyHubPage` 自己有一个 `AppBar(效率工具 + TabBar)`，
    而它内嵌的四个页面各自还带一个 `Scaffold`+`AppBar`
    （`achievement_page.dart:16-17`、`countdown_page.dart:13-14`、`habit_page.dart:17-18`、
    `pomodoro_page.dart:1124-1125`）。hub 此前**零调用点**所以这条从没被看过一眼；
    一接 dock，三个已验收表面（番茄/习惯/倒数日）同时叠出双 bar、两个返回键，
    且沉浸专注（`pomodoro_page.dart:1068-1086` 返回无 chrome 的整屏）在外层 bar 之下失去全屏。
    **9 张黄金图全部只 pump `HomeShell()`**（`todo_workspace_golden_test.dart:112`），push 出来的路由零覆盖 ⇒
    我那句「门禁全绿」根本不构成视觉证据。
  - **B2 成立（我先前把话说错了，这里更正）**：我说过 tab→`AchievementPage` 的渲染断言「受 fixture 限制做不到」，
    复核推翻：`test/achievement_page_test.dart:66-71` **早就**在 pump hub 并 override
    `achievementWallProvider`/`myHabits`/`habitStats`/`countdowns`/`pomodoroApiProvider`；
    `TodoVisualFixture.create` 也支持 `overridesBuilder`（`todo_visual_fixture.dart:60/90`），
    只是 `pumpTodoVisualScenario:35` 没把它透出来。真实报错原因是 `AchievementApi` 走
    `apiClientProvider.raw` 的**真 Dio**（`efficiency_providers.dart:16-18`），绕开了 `_NoNetworkApiClient`
    而留下 pending timer。⇒ 那不是脚手架限制，是我没接线。
- 回滚动作与可逆性：`git diff HEAD` 的两个 lib 文件先存成 `/tmp/spec027-hub-entry.patch`（84 行），
  新测试文件移到 `/tmp/spec027-hub-entry_test.dart.bak`，再 `git checkout --` 这两个文件。
  回滚后复验 `/tmp/revert-027.log`：`No issues found!`、golden `00:03 +9`、全量 `02:05 +724 ~26`、
  `git diff --check` exit=0 —— 724 与 026 收尾时的数目一致，证明只退掉了本切片的 5 条用例，
  工作树里只剩 025/026 的改动。补丁在 `/tmp`，**不入仓、不入库**。

## B2 的脚手架缺口已补（2026-09-23，独立小切片）

- 上一轮我说过「tab→`AchievementPage` 的渲染断言受 fixture 限制做不到」，复核 B2 判此说错误；
  真正的缺口是 `pumpTodoVisualScenario` 把 `TodoVisualFixture.create` 已有的 `overridesBuilder` 吞掉了。
- 已修：harness 增 `List<Override> Function(AppDatabase)? overridesBuilder` 并原样转发（HEAD 版与工作树版
  各自格式化后 diff 只有这 3 处：1 行 import、1 行形参、1 处调用点，见 `/tmp/gate-028.log` `### 7)`）。
- 新用例 `test/visual_harness_overrides_test.dart`（复核判 `test/support/` 只放辅助件，已挪到 `test/` 根）：
  走 harness 注入 `achievementWallProvider`，**数 provider 被问的次数** `consulted > 0` + 失败态与
  `achievement-wall-retry` 入口 + `takeException` 为 null。
  RED 先失败且指向缺失项：`The arguments don't match ... Found this candidate`（就是少那个形参）。
- 负对照（`/tmp/gate-028b.log`）：把 `overridesBuilder: overridesBuilder,` 这一行删掉 ⇒ 该用例
  `Failing tests: ...harness 的 overrides 真的被容器采用`；`cp` 还原后 `cmp -s` 判 `restored=identical`。
  这条计数断言是复核 I2 逼出来的：不覆盖时页面也走真 Dio（测试绑定给 400）落进同一句失败文案，
  只断言文案区分不了注入有没有生效。
- 六项门禁最终状态（`/tmp/gate-028c.log`）：`Formatted 2 files (0 changed)` exit=0、`No issues found!`、
  用例 `00:00 +1: All tests passed!`、golden `00:04 +9: All tests passed!`（**未重录基线**）、
  全量 `02:17 +725 ~26: All tests passed!`（= 026 收尾的 724 **+ 本条 1**）、`✓ Built build/web`、
  `git diff --check` exit=0。中途 `format` 真红过一次（我把 `expect` 写成多行），只对新增文件原地收敛后复跑。
- 只读复核 **`VERDICT: PASS`**，两条 Important 已采纳（非判别性断言 → 计数断言；引用行号写错 → 更正为
  `achievement_page_test.dart:57-88`，正文事实不变）；harness 处补了一句「调用方 overrides 拼在内置项之后、
  Riverpod last-wins，因此连 `appDatabaseProvider`/`apiClientProvider` 都能覆盖」的说明。
  唯一未采纳项：把这条用例改成 override 成真数据（`250 成就值`）——本切片只要证明透传生效，
  造 DTO 属于下一条成就切片的成本，放到那里一起付。

## 已证实 / 仍缺

- 已证实：dock 三入口 → hub 的接线在行为上成立（`initialIndex: 0/1/2` 三条用例各自锁住页签序号）；
  hub 第 4 页签确实是 `AchievementPage`（源码 + `achievement_page_test.dart` 的 hub pump 双证）。
- 仍缺（下一轮的真实入口）：
  ① **前置切片**：四个子页需要「嵌入态」——外层给 bar、内层收掉自己的 `AppBar`，并保住沉浸专注的全屏；
     这属于布局改动，要先量黄金图影响面（当前 9 张基线不含 push 路由，但改的是既有页面）。
  ② 或者**改走第 4 个 dock 按钮**：层级更贴近嘀嗒的一级导航，但会改侧栏可见区域 ⇒ 需要重录 9 张基线的授权。
  ③ 断言脚手架补一处：给 `pumpTodoVisualScenario` 透传 `overridesBuilder`，
     之后 tab→`AchievementPage` 的渲染与「失败保留可重试」才测得动（B2 的修复）。
- 矩阵 #76–78 状态不变（仍「部分」），只更新证据与失败原因；**不因为「代码写完 + 门禁绿」翻状态**，
  何况这次代码已回滚。
