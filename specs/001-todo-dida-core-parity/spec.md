# Feature Specification: 滴答清单核心能力对齐（Flutter 客户端重建）

**Feature Branch**: `001-todo-dida-core-parity`

**Created**: 2026-07-04

**Status**: Draft

**Input**: 用户描述："实现一个与滴答清单一模一样的应用，现阶段偏差和遗漏太大，需要彻底完成 Flutter 客户端（手机/Web/桌面）+ 后端 todo 模块 + admin-vben 管理端对齐"

**范围决策**（已与用户确认，详见 `zh-cloud/.cursor/plans/滴答清单对齐交付计划_7dae23b6.plan.md`）：

- 核心产品对齐优先；第三方生态（Google/iCloud/Outlook/Exchange 日历、微信、Notion、Siri、Apple 健康、课表导入、MCP）仅做 ICS URL 订阅 + 导出订阅源，其余排入后续里程碑。
- 本仓（`zh-cloud-todo-flutter`）承担唯一 C 端全量重建；`zh-cloud-admin-vben` 仅补小缺口；`zh-cloud-admin-uniapp` 暂缓。
- 后端 `zh-cloud-service` 的 `yudao-module-todo` 已有 42 张表与全域 `/app-api/todo/**`，本 spec 以消费既有 API 为主，仅在实测发现缺口时在 service 仓开小 Issue 补齐。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 离线优先的任务与清单管理 (Priority: P1)

用户在 Flutter 客户端（手机/Web/桌面任一端）登录后，可以创建/编辑/完成/删除任务与子任务，组织到清单、文件夹、标签中，并通过过滤器/智能清单快速查找；断网时改动本地立即生效，联网后自动与服务端双向同步，多端数据一致。

**Why this priority**：这是 Todo 应用的最小可用核心，没有它其余功能都无意义。

**Independent Test**：断网创建/编辑若干任务与清单 → 恢复网络 → 验证服务端 `/app-api/todo/task`、`/app-api/todo/list` 数据与本地一致，且换一台设备登录同账号能看到相同数据。

**Acceptance Scenarios**：

1. **Given** 已登录且离线，**When** 创建一个任务并指定清单、标签、截止日期，**Then** 任务立刻出现在本地列表且标记为“待同步”；恢复网络后 30 秒内标记消失且服务端可查到该任务。
2. **Given** 两台设备同时登录同一账号，**When** 设备 A 修改任务标题，**Then** 设备 B 在下次前台/下拉刷新时看到最新标题（无需重启应用）。
3. **Given** 任务已同步过，**When** 服务端与本地同时修改同一字段（版本冲突），**Then** 客户端以服务端版本为准覆盖本地，并提示用户“已按最新版本同步”。

---

### User Story 2 - 多视图与日历 (Priority: P1)

用户可以在列表、看板、时间线三种视图间切换查看任务，并通过日历的周/月/年/列表/日程视图查看任务的时间分布，视图偏好跨端保持。

**Why this priority**：滴答清单的核心差异化体验之一，是当前 Flutter 客户端完全缺失的部分。

**Independent Test**：切换视图后杀进程重启应用，验证视图偏好被记住（本地 + 服务端 `view_preference` 同步）。

**Acceptance Scenarios**：

1. **Given** 清单内有多个任务，**When** 切换到看板视图，**Then** 任务按状态/自定义列分组展示，可拖拽调整分组与顺序。
2. **Given** 任务设置了起止时间，**When** 打开时间线视图，**Then** 任务按时间轴横向排布，可视化重叠区间。
3. **Given** 打开日历月视图，**When** 某天有 ≥1 个任务，**Then** 当日单元格显示任务数量角标，点击进入当日日程视图。

---

### User Story 3 - 四象限、番茄专注、习惯打卡、倒数纪念日 (Priority: P2)

用户可以用四象限（重要/紧急）整理任务、启动番茄钟专注并统计时长、创建习惯并每日打卡看连续天数、创建倒数纪念日查看剩余天数——四者均为真实后端数据，而非本地演示。

**Why this priority**：效率工具是滴答清单的招牌功能，当前实现是纯本地 mock，必须接入 `/app-api/todo/{quadrant,pomodoro,habit,countdown}` 真实闭环。

**Independent Test**：完成一次番茄钟后查看统计页，验证时长来自服务端 `todo_pomodoro_session` 而非本地缓存（换设备登录仍可见）。

**Acceptance Scenarios**：

1. **Given** 任务未分类，**When** 进入四象限页按规则分类，**Then** 任务落入对应象限且规则可编辑并持久化。
2. **Given** 启动一个 25 分钟番茄钟，**When** 计时结束，**Then** 生成一条专注记录并计入当日/近 7 天统计。
3. **Given** 创建一个每日习惯，**When** 连续 3 天打卡，**Then** streak 显示为 3，中断一天后清零。
4. **Given** 创建一个倒数纪念日，**When** 查看纪念页，**Then** 剩余/已过天数正确且样式可自定义。

---

### User Story 4 - 提醒与重复任务 (Priority: P2)

用户设置任务提醒后能在到点收到本地通知，可在提醒收件箱中稍后提醒/完成/忽略；设置重复规则后任务能按规则自动生成后续实例，支持单次跳过。

**Why this priority**：时间管理闭环，直接影响任务不被遗漏。

**Independent Test**：设置 1 分钟后提醒的任务，验证到点收到系统通知且提醒收件箱出现对应条目。

**Acceptance Scenarios**：

1. **Given** 任务设置了提醒时间，**When** 到达提醒时间，**Then** 应用在前台/后台均能触发本地通知。
2. **Given** 收到提醒，**When** 点击“稍后提醒”，**Then** 提醒按选定间隔重新调度。
3. **Given** 任务设置每周一重复，**When** 完成本次实例，**Then** 自动生成下一周一的新实例，可对某次实例设置跳过。

---

### User Story 5 - 共享协作与账号安全 (Priority: P3)

用户可以将清单共享给其他成员并分配角色（owner/editor/viewer），协作者可评论、查看动态；用户可以修改密码、开启双重验证、导出个人数据。

**Why this priority**：多人协作与账号安全是完整产品不可或缺，但依赖前四类核心能力先落地。

**Independent Test**：邀请第二个测试账号加入共享清单为 editor，验证其能编辑任务但不能删除清单；owner 能在成员列表中看到并移除该成员。

**Acceptance Scenarios**：

1. **Given** 清单 owner，**When** 邀请成员并设为 viewer，**Then** 该成员只能查看不能编辑。
2. **Given** 已登录账号，**When** 在设置中开启双重验证，**Then** 下次登录需二次验证。
3. **Given** 用户请求导出数据，**When** 导出完成，**Then** 可下载包含任务/清单/习惯等的导出文件。

---

### User Story 6 - 日历订阅（最小生态） (Priority: P3)

用户可以通过 ICS URL 订阅外部日历只读展示在日历视图中，也可以获取一个 ICS 订阅链接供第三方日历订阅本应用任务。

**Why this priority**：生态集成范围内被裁剪为最小闭环，验证基础订阅协议可用，不做各厂商 OAuth 深度集成。

**Independent Test**：添加一个公开测试用 ICS URL 订阅，验证其事件出现在日历视图（只读、不可编辑）。

**Acceptance Scenarios**：

1. **Given** 一个有效 ICS URL，**When** 添加订阅，**Then** 日历视图展示其事件且标注来源。
2. **Given** 已开启导出订阅，**When** 复制订阅链接到第三方日历客户端，**Then** 第三方客户端能读取到本账号任务的截止时间。

### Edge Cases

- 网络在同步 push 过程中中断：客户端必须保留未确认的 outbox 条目，下次联网重试，且服务端幂等键防止重复写入。
- 用户在离线期间删除了一个同时被其他设备编辑的任务：以服务端 tombstone 为准，本地放弃冲突编辑并提示。
- 设备本地时间被篡改：提醒/重复调度以服务端 `serverTime` 校准，避免大幅漂移。
- 番茄钟计时中应用被系统杀死：重启后从本地持久化的会话状态恢复或判定会话失效。
- ICS 订阅源不可达或格式非法：显示订阅失败状态，不影响其余日历渲染。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须在本地维护任务/清单/文件夹/标签/提醒/重复规则/过滤器/视图偏好的离线可读写副本，并与服务端 `/app-api/todo/sync/{pull,push}` 双向同步。
- **FR-002**: 系统必须为任务提供多级子任务（≤5 层）、检查事项、Markdown 描述、优先级、日期时间与时区。
- **FR-003**: 系统必须提供列表/看板/时间线三种任务视图与周/月/年/列表/日程五种日历视图，视图偏好持久化并跨端同步。
- **FR-004**: 系统必须提供四象限视图与可编辑分类规则。
- **FR-005**: 系统必须提供番茄专注计时、习惯打卡、倒数纪念日三个效率工具，数据来自服务端 app-api 而非本地存储。
- **FR-006**: 系统必须在任务到达提醒时间时触发本地通知，并支持提醒收件箱的稍后提醒/完成/忽略操作。
- **FR-007**: 系统必须支持重复任务规则的创建、编辑与单次实例跳过。
- **FR-008**: 系统必须支持清单共享协作（成员/角色）、评论与动态查看。
- **FR-009**: 系统必须支持账号安全能力：改密、双重验证、数据导出，复用 `todo-member` 与 `/app-api/todo/security`。
- **FR-010**: 系统必须支持添加 ICS URL 日历订阅（只读展示）与生成本账号任务的 ICS 导出订阅链接。
- **FR-011**: 系统的同步冲突处理必须遵循“服务端版本优先”策略并提示用户。
- **FR-012**: 系统必须在会话失效时引导用户重新登录且不丢失本地未同步数据。

### Key Entities

- **Task（任务）**：标题、描述、状态、优先级、清单归属、父任务、起止时间/时区、提醒、标签、排序、是否置顶、revision。
- **List（清单）/Folder（文件夹）/Tag（标签）**：任务的组织维度，清单支持共享成员与角色。
- **Filter（过滤器）**：条件组合 + 排序键，可另存为智能清单。
- **Reminder（提醒）/RepeatRule（重复规则）/RepeatOccurrence（重复实例）**：任务时间闭环三元组。
- **ViewPreference（视图偏好）**：用户对视图类型、显示设置的选择，随 sync 白名单同步。
- **HabitCheckIn（习惯打卡）/PomodoroSession（番茄记录）/Countdown（倒数纪念日）/Achievement（成就）**：效率域实体，直连 REST，不进入 sync 白名单。
- **SyncChange/SyncState（同步变更/状态）**：客户端 outbox 与服务端 revision/tombstone 的本地镜像。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**：断网创建的任务，在恢复网络后 30 秒内完成同步且跨设备一致。
- **SC-002**：`zh-cloud-docs/todo` 对照矩阵中标记为「BE(有)/FL(部分或无)」的效率工具四项（四象限、番茄、习惯、倒数）在 Flutter 端全部可对真实数据端到端验证。
- **SC-003**：`flutter analyze` 零告警、`flutter test` 全绿，作为每个阶段 PR 的必过门槛。
- **SC-004**：核心任务/清单操作在弱网（模拟 2G）下操作响应 < 300ms（本地优先），同步延迟不阻塞 UI。

## Assumptions

- 后端 `/app-api/todo/**` 契约以当前 `zh-cloud-service` 实测行为为准；发现字段缺口时以最小 ALTER/接口补丁处理，不推翻既有表结构。
- 本地通知使用 `flutter_local_notifications`，不依赖服务端推送通道（后续如需远程推送再评估）。
- 第三方日历深度集成（Google/iCloud/Outlook/Exchange OAuth）不在本 spec 范围内，仅做 ICS URL 层。
- `zh-cloud-admin-uniapp` 的 Todo 移动管理端本轮不做，不影响本 spec 验收。
