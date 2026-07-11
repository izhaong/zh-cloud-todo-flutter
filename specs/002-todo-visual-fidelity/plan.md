# Implementation Plan: Todo 多端视觉高保真垂直切片

> 实施者必须按 [tasks.md](./tasks.md) 的依赖顺序执行，并以测试先行、截图验收和小步评审为门槛。除非用户明确要求，不得提交、推送或创建 PR。

**Branch**: `feat/85-todo-visual-fidelity` | **Spec Kit ID**: `002-todo-visual-fidelity` | **Date**: 2026-07-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-todo-visual-fidelity/spec.md`

## Summary

在不改账号、Drift 数据、Repository、同步协议和后端契约的前提下，重构 Todo 唯一客户端的核心任务表现层。先交付 Web/PC `1440×900` 的今天/收集箱高保真垂直切片：自有品牌四区工作台、紧凑导航、单一 QuickAdd、扁平分组任务行、真实任务详情联动；随后把同一任务流映射到 `1280×800`、`1024×768`、`390×844` 和 `360×800`，并用确定性 fixture 与 Flutter golden tests 固化批准状态。

## Global Constraints

- 唯一实现仓库是 `zh-cloud-todo-flutter`；不得修改或恢复已删除的 `zh-cloud-client/apps/todo`。
- 本切片不得修改后端接口、数据库表、同步语义、账号流程或权限规则。
- 不新增生产 UI 框架或大型依赖；优先复用现有 Flutter、Riverpod、Drift 与 Material 能力。
- 视觉测试和演示 fixture 不得连接真实后端、写入真实任务或包含真实账号信息。
- 不得复制第三方 Logo、图标、插画、截图资产或营销文案；公开参考只用于比例、密度与交互分析。
- 浅色主题是首轮高保真门槛；深色主题必须保持可读和可操作，但不阻塞浅色基准落地。
- 未执行对应测试和视觉验收前，不得将任务或规格状态标记为完成。
- Agent 默认不 commit、push 或开 PR，除非用户明确要求。

## Technical Context

**Language/Version**: Dart 3.11.4；Flutter 3.41.6 stable

**Primary Dependencies**: Flutter Material 3、`flutter_riverpod`、`go_router`、`drift`、现有 Todo Repository/Provider；不新增生产依赖

**Storage**: 生产继续使用现有 Drift 数据库；视觉测试使用 `NativeDatabase.memory()` 和固定种子数据，不新增迁移

**Testing**: `flutter_test` widget tests、interaction tests、`matchesGoldenFile` golden tests；测试中使用 Provider override、内存数据库和固定时钟

**Target Platform**: Web/H5、macOS、Windows、Linux、iOS、Android；第一基准为 Web/PC `1440×900`

**Project Type**: 单一 Flutter 多端客户端

**Performance Goals**: 本地选择、完成和列表切换必须立即更新对应视觉状态；widget tests 必须证明每个宽度只产生一个布局档位、跨断点只发生一次结构切换，且选择/缩放不会重复打开 drawer 或重建无关导航状态

**Constraints**: 不访问真实服务；不改变领域行为；不提交第三方视觉资产；宽度临界点必须稳定；golden 数据与时间必须确定

**Scale/Scope**: 一个核心任务垂直切片，覆盖四区工作台、Sidebar、QuickAdd、列表分组、TaskRow、详情面板和 5 个验收视口，共 9 个视觉基准

## Constitution Check

仓库 `.specify/memory/constitution.md` 仍是未填写模板，没有可执行的项目宪法条款。本计划改用 `AGENTS.md`、`CLAUDE.md` 与父仓核心规则作为门禁。

| Gate | Result | Evidence |
| --- | --- | --- |
| 非平凡改动先规格与 Plan | PASS | `specs/002-todo-visual-fidelity/` 独立承载 spec/plan/tasks |
| 单仓规格单一事实源 | PASS | 不在父仓 Plan 或旧 client spec 复制正文 |
| 最小外科式范围 | PASS | 只重构表现层，保留认证、数据、Repository 与同步 |
| 测试无真实副作用 | PASS | 内存数据库、Provider override、固定 fixture、无网络 |
| 品牌与版权边界 | PASS | 只分析公开参考，不保存第三方图片资产 |
| Git 权限边界 | PASS | 本轮只写规划文档，不 commit/push/PR |

Phase 1 设计后复核：UI contract、fixture model 和 quickstart 均未引入后端或数据迁移，所有 gate 继续通过。

## Research Decisions

研究结论和替代方案见 [research.md](./research.md)。关键决策：

1. 采用“参考驱动的桌面垂直切片”，拒绝只换色和全量 UI 重写。
2. 保留现有业务栈，仅替换核心工作区表现与选择联动。
3. 使用自有中性 Token、扁平任务行和真实详情，不在代码或文案中继续使用第三方品牌名。
4. 使用固定 fixture + 原生 golden tests 固化批准状态，不提交第三方参考截图。
5. 多端采用分档布局映射，而不是按比例压缩桌面四区。

## Project Structure

### Documentation (this feature)

```text
specs/002-todo-visual-fidelity/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── workspace-ui-contract.md
├── checklists/
│   ├── requirements.md
│   └── visual-acceptance.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── todo_layout_tokens.dart          # 新增：工作区几何、密度、状态与动效 Token
│   └── widgets/app_widgets.dart             # AppCheckbox 增加非破坏性尺寸参数
├── features/
│   ├── home/
│   │   ├── home_shell.dart                  # 当前清单 + 当前任务选择状态与跨端详情调度
│   │   └── todo_workspace.dart              # 产品自有四区与响应式工作区
│   ├── shell/
│   │   ├── quick_add_bar.dart               # 单行低干扰 QuickAdd
│   │   └── sidebar.dart                     # 紧凑自有品牌导航
│   └── task/
│       ├── tasks_by_list_page.dart           # 工作区标题、视图/排序菜单、分组列表
│       ├── task_detail_page.dart             # 移动/独立页面容器，复用详情内容
│       ├── task_detail_pane.dart             # 新增：真实任务详情与无选择状态
│       └── widgets/
│           ├── task_group_header.dart        # 新增：日期/业务分组标题
│           ├── task_row.dart                 # 扁平任务行与状态呈现
│           ├── task_row_host.dart            # 数据组装、选择回调、hover/drag
│           └── task_workspace_header.dart    # 新增：标题、计数、视图/排序/更多菜单
test/
├── support/todo_visual_fixture.dart          # 固定时钟、内存 DB 与确定性种子
├── visual/todo_workspace_golden_test.dart    # 多状态、多视口视觉回归
├── goldens/todo_workspace/                   # 仅保存本产品批准后的 golden PNG
├── features/home/todo_workspace_layout_test.dart
├── features/task/task_selection_test.dart
├── features/task/task_detail_pane_test.dart
├── features/task/task_row_test.dart
├── features/task/task_row_hover_test.dart
├── features/task/task_mobile_workspace_test.dart
├── features/shell/sidebar_test.dart
├── features/shell/quick_add_bar_test.dart
└── theme_mode_test.dart
```

**Structure Decision**: 保持现有 `lib/core` + `lib/features` 分层。工作区布局、任务列表、详情内容和视觉 fixture 各自有单一职责；`TaskDetailPage` 只负责平台容器，`TaskDetailPane` 负责可复用内容；不新建第二套领域模型或 Repository。

## File Responsibility Map

| File | Responsibility | Must Not Do |
| --- | --- | --- |
| `todo_layout_tokens.dart` | 提供宽度、行高、间距、状态背景与动效时长 | 读取业务数据或保存用户偏好 |
| `todo_workspace.dart` | 根据视口组织 rail/sidebar/content/detail | 查询任务、执行 CRUD |
| `home_shell.dart` | 管理当前模块、清单和任务选择；选择失效时清理 | 绘制任务详情表单 |
| `tasks_by_list_page.dart` | 组合标题、QuickAdd、紧凑菜单、分组与各视图 | 再次渲染 Sidebar 或独立 Scaffold |
| `task_row.dart` | 纯展示行状态 | 自行导航或读取 Provider |
| `task_row_host.dart` | 组装 Repository 数据并上报用户动作 | 决定桌面/移动详情容器 |
| `task_detail_pane.dart` | 加载并编辑当前真实任务；报告任务失效 | 创建新的导航栈或复制完整页面壳 |
| `todo_visual_fixture.dart` | 构造无网络、固定时间的可重复场景 | 使用生产账号、Token 或远端 API |

## Interface Boundaries

详细组件输入、状态迁移和断点行为见 [contracts/workspace-ui-contract.md](./contracts/workspace-ui-contract.md)。实施时必须保持以下方向：

```text
HomeShell selection state
  ├─> TodoWorkspace layout
  ├─> TasksByListPage(selectedTaskId, onTaskSelected)
  │     └─> TaskRowHost(selected, onTap)
  │            └─> TaskRow (pure presentation)
  └─> TaskDetailPane(taskId, onUnavailable, onClose)
```

任务列表不得重新直接打开详情 Sheet；由 `HomeShell` 按当前布局档位决定固定右栏、end drawer 或移动全屏详情。

## Verification Strategy

1. 每个行为切片先写失败的 widget test，再做最小实现。
2. `1440×900` 的结构、未选择、已选择、空列表和长内容先完成，并按 `checklists/visual-acceptance.md` 计分批准。
3. 批准后生成本产品 golden；默认逐像素精确匹配、容差为 `0`，禁止把第三方参考图作为测试基线提交。
4. 再完成 `1280×800`、`1024×768`、`390×844`、`360×800` 的响应式测试与 golden。
5. 最后运行 `flutter analyze`、定向测试和完整 `flutter test`；验证命令与预期见 [quickstart.md](./quickstart.md)。

## Complexity Tracking

无需要豁免的复杂度。新增文件均用于隔离已有超长 UI 文件中的明确职责，不引入新架构层或第二套状态管理。
