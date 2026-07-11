# Data Model: Todo 多端视觉高保真垂直切片

本功能不新增数据库表、服务端实体或同步白名单。以下模型均为现有任务数据的展示派生状态或测试场景描述。

## WorkspaceSelection

表示主工作区的当前选择。

| Field | Type | Rules |
| --- | --- | --- |
| `section` | Section identifier | 必须是当前可见模块 |
| `smartList` | Smart-list identifier | 仅任务模块有效 |
| `listId` | Optional task-list ID | 普通清单选中时存在；智能清单时可为空 |
| `taskId` | Optional task ID | 必须属于当前仍可见的数据集合 |
| `layoutProfile` | `wide` / `compact` / `tablet` / `mobile` | 由当前逻辑视口唯一确定 |

### State transitions

```text
No task selected
  ├─ click visible task ─> Task selected
  ├─ add task ───────────> No task selected（列表保留）
  └─ change list ────────> No task selected

Task selected
  ├─ click another task ─> Other task selected
  ├─ close detail ───────> No task selected
  ├─ selected task hidden/deleted ─> No task selected
  └─ viewport profile changes ─────> Same task selected, different detail container
```

## TaskRowPresentation

由现有 `TodoTask`、标签、子任务和清单信息派生，不持久化。

| Field | Type | Rules |
| --- | --- | --- |
| `taskId` | String | 稳定身份，用于选择和重排 |
| `title` | String | 主信息；最多两行，桌面默认单行 |
| `completed` | Boolean | 控制完成框和标题弱化 |
| `selected` | Boolean | 同一工作区最多一条为 true |
| `hovered` | Boolean | 仅有鼠标的平台使用 |
| `pinned` | Boolean | 影响分组/排序；快捷图标不应常驻 |
| `priority` | 0–3 | 用克制的状态色或图标表达 |
| `dueLabel` | Optional string | 由固定/当前时钟派生 |
| `dueStatus` | none / overdue / today / future | 决定日期语义色 |
| `listLabel` | Optional string | 空间不足时优先省略 |
| `tagLabels` | List of strings | 超出预算时折叠，不挤压标题 |
| `subtaskCount` | Non-negative integer | 作为次级信息 |

## TaskGroupPresentation

表示任务列表中的稳定分组。

| Field | Type | Rules |
| --- | --- | --- |
| `key` | String | 同一数据集内唯一 |
| `title` | String | 例如“置顶”“今天”“明天”“最近 7 天” |
| `count` | Non-negative integer | 与可见任务数量一致 |
| `collapsed` | Boolean | 首轮默认为 false |
| `items` | Ordered list of `TaskRowPresentation` | 排序稳定；重排后身份不变 |

## VisualScenario

描述一个可重复视觉验收场景，不进入生产数据。

| Field | Type | Rules |
| --- | --- | --- |
| `id` | String | 稳定、可作为 golden 文件名 |
| `viewport` | Width × height | 使用规格批准的逻辑尺寸 |
| `theme` | light / dark | 首轮以 light 为主 |
| `fixedNow` | DateTime | 所有日期标签基于同一时刻 |
| `fixtureSet` | populated / empty / long-content | 不包含真实用户数据 |
| `selectedTaskId` | Optional string | 必须存在于 fixtureSet |
| `expectedLayout` | Layout profile | 与 viewport contract 一致 |
| `expectedDetailMode` | fixed / drawer / full-screen / hidden | 与 layout profile 一致 |

## Persistence Impact

- 数据库迁移：无。
- 服务端契约：无。
- 同步实体：无。
- 用户偏好新增字段：无；断点由当前视口直接派生。
