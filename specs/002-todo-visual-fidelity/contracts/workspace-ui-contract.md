# UI Contract: Todo Workspace

本契约定义核心任务工作区的组件边界、布局档位、状态反馈和视觉验收矩阵。实现可以调整内部结构，但不得改变这些外部行为。

## 1. Layout Profiles

| Profile | Logical width | Navigation | Detail | Primary add entry |
| --- | --- | --- | --- | --- |
| `wide` | `>= 1366` | 56px rail + 272px sidebar 固定 | 432px 固定右栏 | 主区单行 QuickAdd |
| `compact` | `1100–1365` | 56px rail + 256px sidebar 固定 | end drawer，最大 432px | 主区单行 QuickAdd |
| `tablet` | `600–1099` | 56px rail 固定，sidebar 为 drawer | end drawer 或覆盖层 | 主区单行 QuickAdd |
| `mobile` | `< 600` | 顶栏 + bottom navigation + drawer | 独立全屏详情 | 唯一移动快速添加入口 |

### Wide invariants

- `1440×900` 必须同时显示 rail、sidebar、task content 和 detail region。
- detail region 在没有选中任务时仍保留稳定宽度，避免主区横向跳动，但内容必须为中性空状态。
- 主区逻辑宽度不得小于 520px；若无法满足，必须进入 `compact`。

### Boundary behavior

- 宽度跨越档位时只允许发生一次结构切换，不允许在临界点来回抖动。
- 当前 `taskId` 在档位变化时保持不变；只改变详情的容器形式。
- drawer/full-screen 关闭只清除当前详情呈现，不改变当前清单。

## 2. Component Interfaces

### `TodoWorkspace`

```text
Consumes:
- logical width
- selected section / smart list / list ID
- selected task ID
- task content widget
- detail content widget
- navigation callbacks

Produces:
- exactly one layout profile
- stable semantic keys: todo-rail, todo-sidebar, todo-content, todo-detail
- fixed/detail drawer/full-screen routing request through callbacks
```

`TodoWorkspace` 只负责布局，禁止读取任务 Repository 或执行 CRUD。

### `TasksByListPage`

```text
Consumes:
- title
- list ID / due range / completed filter
- selected task ID
- onTaskSelected(taskId)
- onQuickAdd(title)

Produces:
- one workspace header
- one QuickAdd entry on desktop/tablet
- current view body
- grouped flat task rows in list mode
```

工作区模式不得再次渲染 Sidebar、独立 Scaffold、ListPicker、智能清单 chips、常驻五视图 tabs 或桌面 FAB。视图、排序和过滤能力进入标题栏紧凑菜单，不能删除既有能力。

### `TaskRowHost`

```text
Consumes:
- TodoTask
- selected boolean
- desktopMode boolean
- onTap(taskId)
- existing toggle/pin/reorder capabilities

Produces:
- TaskRowData
- hover state
- contextual drag/more actions
- no direct navigation
```

### `TaskRow`

纯展示组件。不得读取 Provider、导航或决定列表排序。

### `TaskDetailPane`

```text
Consumes:
- taskId
- embedded boolean
- onClose()
- onUnavailable(taskId)

Produces:
- real task fields and existing edit actions
- neutral no-selection state when taskId is null
- unavailable callback when task no longer exists
```

`TaskDetailPage` 和桌面固定右栏必须复用同一个 `TaskDetailPane` 内容，禁止复制两套详情表单。

## 3. Visual Tokens

所有数值集中在 `lib/core/theme/todo_layout_tokens.dart`，不得在 shell/sidebar/task row/detail 分散硬编码。

| Token | Value |
| --- | --- |
| Rail width | 56 |
| Wide sidebar width | 272 |
| Compact sidebar width | 256 |
| Wide detail width | 432 |
| Workspace header height | 56 |
| QuickAdd height | 44 |
| Sidebar row height | 40 |
| Task row single-line height | 44 |
| Task row metadata height | 58 |
| Main horizontal inset | 24 |
| Group header minimum height | 36 |
| Selected row radius | 8 |
| Hover/selection animation | 120–160ms |

### Light semantic colors

| Role | Initial value |
| --- | --- |
| Rail/canvas | `#F7F7F7` |
| Surface | `#FFFFFF` |
| Primary text | `#242424` |
| Muted text | `#8A8A8A` |
| Divider | `#ECECEC` |
| Hover row | `#F7F7F7` |
| Selected row | `#F2F2F2` |
| Accent | existing product accent (`#2B7EFD`) |

暗色映射继续由 `AppColors.dark` 提供，必须达到可读和可区分状态，不在本契约复制第三方暗色样式。

## 4. Task List Contract

- 标准单行任务高度 44px；存在元信息时使用 58px，不允许因标签数量任意增长。
- checkbox 视觉尺寸 18px，触控命中区不得小于 36px。
- 未选中任务无卡片边框、阴影和独立白色卡面。
- hover 只显示弱背景；selected 使用更明确但仍中性的背景。
- pin、drag、more 等快捷操作仅在 hover、selected 或键盘焦点时出现。
- 时间右对齐；标题获得剩余宽度；标签和清单信息空间不足时先折叠。
- 日期/业务分组标题必须显示标题和数量，并保持排序稳定。
- 空列表只显示一个最短新建入口。

## 5. Detail Contract

- 宽桌面选择任务后，详情在固定右栏原位更新，不创建新的 Navigator route。
- compact/tablet 选择任务后打开 end drawer/覆盖层。
- mobile 选择任务后打开全屏详情。
- 没有选择时不得展示假标题、假属性或开发说明。
- 标题是详情的首要内容；属性使用低干扰行式布局；正文和检查事项保持可编辑。
- 保存继续使用现有明确提交语义；本切片不引入自动保存。
- 任务删除、移动或过滤失效后，详情必须关闭或回到 no-selection。

## 6. Visual Scenario Matrix

| Scenario ID | Viewport | State | Required assertions |
| --- | --- | --- | --- |
| `wide-populated` | 1440×900 | 有数据、未选择 | 四区稳定、10+ 行可见、detail 中性空态 |
| `wide-selected` | 1440×900 | 有数据、已选择 | 单行选中、真实详情、无布局跳动 |
| `wide-empty` | 1440×900 | 空列表 | 单一空态入口、无重复 FAB |
| `wide-long-content` | 1440×900 | 长标题/多标签 | 无溢出、标题优先 |
| `compact-selected` | 1280×800 | 已选择 | 三栏 + end drawer，主区可用 |
| `tablet-list` | 1024×768 | 列表 | rail 固定、sidebar drawer、无压缩四区 |
| `mobile-list` | 390×844 | 列表 | 单列、bottom nav、唯一添加入口 |
| `mobile-detail` | 390×844 | 详情 | 全屏详情、可关闭返回列表 |
| `mobile-min-long` | 360×800 | 长内容 | 无水平溢出、主要操作可达 |

最终桌面批准必须同时完成 [visual-acceptance.md](../checklists/visual-acceptance.md) 的 10 项计分；golden 一致不能替代人工结构与交互审计。

### Golden comparison policy

- 仓库默认使用 Flutter `matchesGoldenFile` 的逐像素精确比较，允许容差为 `0`；任何像素差异都会使测试失败。
- 有意视觉变化必须先运行 `--update-goldens`，逐张检查实际 PNG，并取得人工或用户明确委托的视觉批准后才能替换基准。
- 若未来因平台渲染差异引入非零容差，必须先在本契约中记录比较算法、阈值和适用平台，不能在测试代码中静默放宽。

## 7. Accessibility and Motion

- 所有图标按钮必须有 tooltip 或语义标签。
- 键盘焦点不得只用颜色表达，并且顺序遵循 rail → sidebar → header → list → detail。
- 文字缩放到 1.3 倍时不遮挡主要操作。
- reduced-motion 下 hover/selection 允许无动画切换。
