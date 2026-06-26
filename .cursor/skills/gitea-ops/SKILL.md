---
name: gitea-ops
description: >
  Gitea 仓库操作、自动化与管理。使用 user-gitea MCP 工具进行 Issue 分类、PR 管理、
  CI/CD 操作、发布管理、安全监控。当用户说"检查 Gitea"、"整理 Issues"、"审查 PR"、
  "合并"、"发版"、"CI 挂了"时激活。
origin: ECC-Gitea-Adaptation
---

# Gitea Operations

使用 Gitea API 管理仓库，聚焦社区健康、CI 可靠性和贡献者体验。

## 激活条件

- 整理 Issues（分类、标注、响应、去重）
- 管理 PR（审查状态、CI 检查、过期 PR、合并就绪）
- 调试 CI/CD 失败
- 准备发布和更新日志
- 监控安全问题
- 管理贡献者体验
- 用户说"检查 Gitea"、"整理 Issues"、"审查 PR"、"合并"、"发版"、"CI 挂了"

## 工具要求

**MCP：`user-gitea`**
- `list_branches` / `create_branch`：分支管理
- `list_pull_requests` / `pull_request_read` / `create_pull_request`：PR 管理
- `list_issues` / `issue_read` / `create_issue`：Issue 管理
- `list_commits` / `get_commit`：提交历史
- `list_tags` / `get_release` / `create_release`：发布管理
- `get_file_contents` / `repository_read`：仓库内容
- `list_actions`：CI/CD 查看

## Issue 整理

按类型和优先级分类：

**类型：** bug、enhancement、question、documentation、invalid、good-first-issue

**优先级：** critical（安全/破坏性）、high（重大影响）、medium（改进）、low（cosmetic）

### 整理流程

1. 读取 Issue 标题、正文和评论
2. 检查是否重复（按关键词搜索）
3. 添加适当标签
4. 问题类：起草并发布回复
5. Bug 类：请求复现步骤
6. 好的首个 Issue：添加 `good-first-issue` 标签
7. 重复项：评论并链接原 Issue，添加 `invalid` 标签

```bash
# 搜索潜在重复
list_issues --search "keyword" --state all --limit 20

# 添加标签
issue_update --id <number> --add-label "bug,high-priority"
```

## PR 管理

### PR 分类流程

1. 检查 PR 标题和描述是否符合规范
2. 查看关联的 Issue 或需求
3. 检查 CI 状态（list_actions）
4. 审查代码变更范围
5. 检查分支是否需要 rebase

### PR 状态检查

```bash
# 列出打开的 PR
list_pull_requests --state open

# 检查 PR 是否可合并
pull_request_read --repo <owner/repo> --pr <number>

# 查看最近提交是否符合规范
list_commits --repo <owner/repo> --branch <branch> --limit 5
```

### 合并规则

- CI 必须通过
- 至少 1 个审查通过（或项目要求数量）
- 分支已更新到最新 main/develop
- 提交信息符合 Conventional Commits

## CI/CD 操作

### 查看 CI 状态

```bash
# 列出最近的动作/工作流
list_actions --repo <owner/repo> --limit 10

# 查看工作流运行详情
# 注意：具体命令取决于 MCP 提供的工具
```

### 调试 CI 失败

1. 获取失败的 workflow run
2. 查看日志输出
3. 定位失败步骤
4. 识别错误模式（测试失败、构建错误、依赖问题）
5. 提供修复建议

## 发布管理

### 发版流程

1. 确认目标分支（通常是 `main` 或 `release/x.y.z`）
2. 检查所有 CI 是否通过
3. 创建 tag
4. 创建 Release（包含变更日志）

```bash
# 列出所有 tag
list_tags --repo <owner/repo>

# 创建 Release
create_release --repo <owner/repo> --tag <version> --title "Release <version>" --body "<changelog>"
```

### 版本规范

遵循 Semantic Versioning：
- `MAJOR.MINOR.PATCH`（如 `1.2.3`）
- 预发布：`1.0.0-beta.1`
- 发版前检查 `CHANGELOG.md` 或 `RELEASE.md`

## 仓库健康检查

### 定期检查项

| 检查项 | 频率 | 工具 |
|--------|------|------|
| 过期 Issue/PR | 每周 | `list_issues --state open --limit 50` |
| 失败 CI | 每日 | `list_actions` |
| 安全问题 | 实时 | Issue 标签过滤 |
| 依赖更新 | 每月 | 手动检查或依赖扫描 |

### 社区健康指标

- 响应时间（Issue/PR 首响应 < 48h）
- 解决率（已关闭 Issue / 总 Issue）
- 平均合并时间
- 贡献者留存

## Gitea vs GitHub 命令对照

| GitHub (gh) | Gitea (MCP) |
|-------------|-------------|
| `gh issue list` | `list_issues` |
| `gh pr list` | `list_pull_requests` |
| `gh pr merge` | PR 合并通过 UI 或 API |
| `gh release list` | `list_tags` / `list_releases` |
| `gh run list` | `list_actions` |
| `gh api repos/...` | `repository_read` |

## 常用工作流

### 日常检查

```
1. list_issues --state open --limit 20
2. list_pull_requests --state open --limit 10
3. list_actions --limit 5
```

### Issue 响应

```
1. issue_read --id <number>
2. 添加标签: issue_update --add-label
3. 如果需要: 创建回复 Issue 或请求更多信息
```

### PR 审查

```
1. pull_request_read --repo <owner/repo> --pr <number>
2. 检查描述是否完整
3. list_commits 查看提交历史
4. 检查 CI 状态
5. 决定: approve / request-changes / comment
```

### 发布检查

```
1. list_tags --limit 10
2. 检查 latest release 内容
3. 验证 CHANGELOG.md 更新
4. 确认所有 PR 已合并
5. 执行发布操作
```

## 约束与限制

- **只读优先**：优先使用 `list_*`、`*_read`、`*_search` 等只读操作
- **修改需确认**：创建、更新、删除操作前必须确认用户意图
- **标签规范**：使用项目定义的标签系统（参考 `.gitea/` 目录下的配置）
- **CI 不可触发**：不通过 MCP 操作 CI 触发（应由 CI 系统自身处理）
