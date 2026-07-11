# Research: Todo 多端视觉高保真垂直切片

## Decision 1: 采用参考驱动的垂直切片

**Decision**: 先重建今天/收集箱的 Web/PC `1440×900` 主工作区，再扩展到其它视口和页面。

**Rationale**: 当前功能范围已经很大，但视觉问题集中在主壳、任务密度和详情联动。先批准一张母版可以约束后续所有功能页，避免每个页面独立“像一点”。

**Alternatives considered**:

- 只修改颜色、间距和圆角：无法消除重复控件、卡片化任务行和虚假详情占位。
- 全量重写所有页面：会把数据、同步和多视图能力一并置于高风险范围，违背最小改动原则。

## Decision 2: 公开参考只做结构分析

**Decision**: 参考滴答清单官网公开桌面图的四区结构、扁平任务行、分组、选中态和详情比例；不保存或提交该图片，不复制其 Logo、图标、插画和品牌文案。

**Rationale**: 用户目标是产品体验和信息密度高保真，不是复制第三方品牌资产。结构分析可以指导布局，同时保持产品独立性。

**Reference**: `https://cncdn.dida365.com/sites/res/newHome/dida/header1.jpg`（公开网页参考，仅供人工分析）

**Alternatives considered**:

- 把第三方截图直接作为像素 diff 基线：会把第三方资产带入仓库，也会因品牌差异制造无意义失败。
- 完全不使用参考：会回到凭感觉设计，无法回答“是否像成熟任务工具”。

## Decision 3: 保留现有业务架构

**Decision**: 继续使用现有 Riverpod Provider、Drift、Repository、同步协调器和任务实体，只调整表现层和选择状态传递。

**Rationale**: 代码审计显示核心差距来自 `ticktick_workspace.dart`、`tasks_by_list_page.dart`、`task_row.dart`、`sidebar.dart` 和静态 `_DetailPanel`，不是数据层缺失。

**Alternatives considered**:

- 新建第二套 UI 状态库：会产生重复状态源和同步问题。
- 为视觉 fixture 复刻一套假 Repository：优先使用 Provider override + 内存 Drift，保持数据行为一致。

## Decision 4: 使用自有中性视觉 Token

**Decision**: 浅色主内容使用白色表面和中性灰层级，强调色沿用产品现有 accent；任务行使用扁平布局，只有 hover/selected 状态出现弱背景。

**Rationale**: 当前暖灰全局背景、圆角卡片、边框和阴影把高频列表变成“卡片展示页”。任务工具需要稳定密度和低装饰噪声。

**Initial geometry**:

| Token | Initial value |
| --- | --- |
| Rail width | 56 logical px |
| Sidebar width | 272 logical px |
| Wide detail width | 432 logical px |
| Workspace header height | 56 logical px |
| QuickAdd height | 44 logical px |
| Sidebar row height | 40 logical px |
| Single-line task row | 44 logical px |
| Task row with metadata | 58 logical px |
| Task content horizontal inset | 24 logical px |
| Hover/selected motion | 120–160 ms |

这些值是第一轮实现输入；若 `1440×900` 人工审计发现主区不足或比例失衡，只能在 `todo_layout_tokens.dart` 集中调整，不能分散硬编码。

## Decision 5: 多端采用布局档位

**Decision**: 使用 wide desktop、compact desktop、tablet 和 mobile 四种明确布局档位。

**Rationale**: 同一套业务流需要跨端一致，但导航和详情容器必须符合可用空间。机械压缩四区会让手机端不可用。

**Alternatives considered**:

- 所有宽度保持四区并缩放：任务标题和操作空间不足。
- 每个平台维护独立页面：长期会产生交互和功能漂移。

## Decision 6: 固定 fixture 与原生 golden tests

**Decision**: 使用固定时钟、稳定 ID、内存数据库和 Provider override 构建视觉场景；使用 Flutter 原生 golden matcher，不新增 golden 框架依赖。

**Rationale**: 当前仓库已有 `flutter_test` 和内存 Drift 测试模式，原生能力足够；固定数据可以避免日期、排序和网络导致截图漂移。

**Alternatives considered**:

- 连接测试环境截图：数据、账号和网络不可重复，且违反测试无真实副作用约束。
- 引入 Widgetbook/golden_toolkit：本切片不需要额外框架即可完成目标。

## Decision 7: 详情保留现有保存语义

**Decision**: 本轮重排详情的视觉结构并复用真实任务数据，但不新增自动保存协议；保存行为继续沿用现有明确提交语义。

**Rationale**: 自动保存涉及错误恢复、并发同步和用户反馈，不应被视觉重构顺带引入。

**Alternatives considered**:

- 输入即自动保存：更接近部分成熟产品，但超出本切片行为边界。
- 详情仅只读：无法验证现有编辑能力在新布局中的可用性。
