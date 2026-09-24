# 效率中枢入口打通（成就墙可达）

对齐矩阵 #76–78「成就值与勋章（父）·成就值·勋章」。嘀嗒把成就值放在**效率/统计这一族**里
（`10-成就值与勋章/01-成就值.md`：「丰富了统计的内容，并引入成就值来展示结果」），
而不是一个与番茄/习惯平级的顶层导航项。

## 现状（实地证据，2026-09-23）

- 链路已齐：`core/api/efficiency_api.dart:941/945` `GET /achievement/wall` → DTO `:327-399`
  → `state/efficiency_providers.dart:16/63` → 页面 `features/achievement/achievement_page.dart:10`
  → 既有测试 `test/achievement_page_test.dart`。
- `features/efficiency/efficiency_hub_page.dart` 已是一张 4 页签的「效率工具」页
  （番茄专注 / 习惯打卡 / 倒数纪念日 / **成就勋章**），内部承载上述真页面。
- 但 `home_shell.dart:478-494` 的三个 dock 回调各自 `push` 了单页
  （`PomodoroPage` / `HabitPage` / `CountdownPage`），**`EfficiencyHubPage` 没有任何调用点**
  ⇒ 成就值、等级、勋章墙对用户不可达（矩阵原判「实现齐但无入口」）。

## 功能需求

- **FR-001** 三个 dock 入口（番茄 / 习惯 / 倒数日）改为打开 `EfficiencyHubPage` 的对应页签
  （`initialIndex: 0/1/2`），页签命名沿用 hub 现有文案（即既有的四个词，不自造同义词）。
- **FR-002** 「成就勋章」页签必须从上述任一入口一次点击可达，且内容是既有的 `AchievementPage`
  （不新建页面、不复制一份成就 UI）。
- **FR-003** dock 本身的视觉与文案**零改动**（仍是 3 个按钮、同样的标签与位置）
  ⇒ 不触碰 `specs/002-todo-visual-fidelity` 已批准的 9 张黄金图基线。
- **FR-004** 成就墙拉取失败时保留可重试入口（沿用 `AchievementPage` 既有 error 态），
  且路由内不出现渲染溢出；320px 宽 + 1.3 倍字体下四个页签仍可达（`TabBar.isScrollable` 已具备横向滚动）。

## 边界与非目标

- 「与嘀嗒同级导航的 4 个 dock 按钮」不在本轮：那会改动侧栏可见区域、需要重录 9 张基线（未获授权）。
- 嵌套 `Scaffold` 的双 AppBar 若实测存在，本轮只做**如实记录 + 用例锁住可达性**，
  页签化收尾（内层 AppBar 收敛）另开切片，不在本切片顺手改布局。
- 成就值的服务端计算规则、勋章发放（后端已实现）与「推荐任务」「持续提醒」不在本切片范围。
