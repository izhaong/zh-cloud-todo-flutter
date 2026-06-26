# user-gitea MCP — PR 生命周期速查

调用前打开 `mcps/user-gitea/tools/<tool>.json` 核对参数。

## pull_request_read

| method                | 用途                                           |
| --------------------- | ---------------------------------------------- |
| `get`                 | PR 元数据、`mergeable`、`head.sha`、`html_url` |
| `get_diff`            | 服务端 diff（大 PR 时优先本地 `git diff`）     |
| `get_reviews`         | 已有 review 列表                               |
| `get_review_comments` | 行内评论（需 `review_id` 时用 `get_review`）   |

必填：`owner`, `repo`, `index`, `method`

## pull_request_review_write

| method               | 用途                                                                         |
| -------------------- | ---------------------------------------------------------------------------- |
| `create`             | 创建 review；`state`: `APPROVED` / `REQUEST_CHANGES` / `COMMENT` / `PENDING` |
| `submit`             | 提交 pending review（需 `review_id`）                                        |
| `delete` / `dismiss` | 管理 review                                                                  |

`create` 常用字段：`commit_id`（= PR head SHA）、`body`、`comments[]`（`path`, `new_line_num`, `body`）

## pull_request_write

| method   | 用途                                                                                                 |
| -------- | ---------------------------------------------------------------------------------------------------- |
| `create` | 新建 PR：`head`, `base`, `title`, `body`                                                             |
| `update` | 改标题/正文                                                                                          |
| `merge`  | 合并：`merge_style`（`merge`/`squash`/`rebase`/`rebase-merge`/`fast-forward-only`），`delete_branch` |

zh-cloud 默认：**base = `develop`**，merge_style = **`merge`**（与 Gitea UI 一致）。

## delete_branch

合并后删远端功能分支：`owner`, `repo`, `branch`（不含 `refs/heads/` 前缀）。

## 辅助

- `list_pull_requests` — `state: open`
- `list_commits` — 核对 Conventional Commits
- `issue_read` / `issue_write` — PR 关联 Issue 结项

## REST 兜底（无 MCP 时）

见 [`00-zh-cloud-core.mdc`](../../rules/00-zh-cloud-core.mdc)「Gitea PR 生命周期」API 表。
