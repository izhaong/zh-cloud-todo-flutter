# zh-cloud-todo-flutter Agent 索引

本仓 **权威** Subagent 目录。共享角色由 bootstrap 从父仓同步。

## 本仓优先

| Subagent             | 场景                           |
| -------------------- | ------------------------------ |
| **`todo-flutter-dev`** | Flutter Todo 多端（**默认首选**） |

## 协作

| Subagent       | 场景                 |
| -------------- | -------------------- |
| `flutter-dev`  | Flutter 通用模式兜底 |
| `qa-engineer`  | 联调与回归           |

## agency-agents 补充

| Subagent | 场景 |
| -------- | ---- |
| `agency-code-reviewer` | PR 评审 |
| `agency-mobile-app-builder` | 多端构建与发布 |
| `agency-frontend-developer` | Flutter Web / UI |
| `agency-devops-automator` | Jenkins / 部署 |

映射与更新：`zh-cloud/.cursor/agents/agency-manifest.yaml` → `scripts/sync-agency-agents.sh`

全局索引：`zh-cloud/.cursor/agents/README.md`
