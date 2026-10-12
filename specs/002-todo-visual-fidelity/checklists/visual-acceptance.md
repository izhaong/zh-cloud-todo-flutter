# Visual Acceptance Checklist: Todo 桌面高保真母版

**Purpose**: 对 `1440×900` 桌面母版进行可计分人工验收，并约束多端映射不得破坏核心体验
**Created**: 2026-07-11
**Feature**: [spec.md](../spec.md)
**UI Contract**: [workspace-ui-contract.md](../contracts/workspace-ui-contract.md)

## Scoring Rules

- 每项完全通过计 10 分；未完全通过计 0 分，不使用主观部分分。
- 总分必须达到 90/100。
- 标记为 **CRITICAL** 的 V01、V03、V04、V07 必须全部通过，即使总分达到 90 也不得豁免。
- 每项必须附对应 golden 文件名、实际截图或可复现测试证据后才能勾选。

## Desktop Mother Page

- [x] **V01 — CRITICAL — 四区结构**：`1440×900` 同时存在 rail、sidebar、task content、detail，边界清晰且主任务区仍是视觉焦点。（10 分）— 证据：`wide-populated.png`、`wide-selected.png`；`todo_workspace_layout_test.dart` 21/21。
- [x] **V02 — 比例与中性层级**：四区宽度符合 contract，主表面为白色/中性灰，分隔克制，无暖色大底或无关卡片装饰。（10 分）— 证据：`wide-populated.png`、`wide-empty.png`；`todo_layout_tokens_test.dart`。
- [x] **V03 — CRITICAL — 单一快速添加**：桌面仅有一个 QuickAdd；不存在第二套 ListPicker、智能 chips、常驻五视图 tabs 或 FAB 竞争主操作。（10 分）— 证据：`wide-populated.png`；`quick_add_bar_test.dart` 4/4。
- [x] **V04 — CRITICAL — 扁平任务行与密度**：未选中任务无独立卡片边框/阴影；标准状态一屏至少可见 10 条单行任务。（10 分）— 证据：`wide-populated.png` 一屏显示 13 条任务；`task_row_test.dart` 与 `task_row_hover_test.dart`。
- [x] **V05 — 分组与交互状态**：分组标题和数量清晰；hover、selected、completed、pinned、drag、keyboard focus 可区分，且快捷操作只在相关状态出现。（10 分）— 证据：`wide-selected.png`；`task_grouping_test.dart`、`task_row_hover_test.dart`、`theme_mode_test.dart`。
- [x] **V06 — 信息优先级与长内容**：完成框和标题优先；日期、清单、标签、优先级不会挤压标题；中英文长标题、Emoji、多标签无水平溢出。（10 分）— 证据：`wide-long-content.png`、`mobile-min-long.png`；移动端长内容与 1.3 倍字号测试。
- [x] **V07 — CRITICAL — 真实详情联动**：选择任务后固定右栏显示真实任务；A→B 切换同步；无选择和任务失效时无虚假字段或开发占位文案。（10 分）— 证据：`wide-selected.png`、`wide-empty.png`；选择/详情 Quickstart 20/20。
- [x] **V08 — 核心任务流效率**：打开今天、添加任务、选择任务、完成任务各自不超过一次目标点击或一次输入提交，且不离开当前工作区。（10 分）— 证据：`quick_add_bar_test.dart` 的完整 today → add → select → complete 单动作流程，以及当前清单创建和完成失效断言。
- [x] **V09 — 多端映射与稳定性**：1280、1024、390、360 视口符合各自布局档位，无压缩四区、重复 drawer、断点抖动、不可关闭详情或不可达操作；9 个 golden 全部批准。（10 分）— 证据：`compact-selected.png`、`tablet-list.png`、`mobile-list.png`、`mobile-detail.png`、`mobile-min-long.png`；五视口布局/韧性 21/21、移动端 9/9、golden 9/9。
- [x] **V10 — 自有品牌、主题与无副作用**：无第三方 Logo/截图/插画/营销文案；浅色基准通过、深色状态可读；fixture 无真实账号、网络或持久化副作用。（10 分）— 证据：排除 `research.md` 后外部品牌扫描零命中；`theme_mode_test.dart`；内存数据库与 `_NoNetworkApiClient` fixture。

## Result

- **Score**: `100/100`
- **Critical gates**: V01 `[x]` · V03 `[x]` · V04 `[x]` · V07 `[x]`
- **Decision**: `[x] APPROVED` / `[ ] REJECTED`
- **Evidence**: `test/goldens/todo_workspace/` 九张经逐图检查的 PNG；Quickstart 全部目标命令通过（21/21、20/20、25/25、9/9）；完整 `flutter test` 166/166；`flutter analyze` 无问题。
- **Failed items and follow-up**: 无。
