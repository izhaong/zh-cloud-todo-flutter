---
name: gitea-pr-lifecycle
description: >-
  通过 user-gitea MCP 完成 Gitea PR 标准闭环：Code Review、冲突处理、合并、合并后收尾与删分支。
  适配 zh-cloud 四仓 develop 集成线。用户说「审查 PR」「合并 PR」「处理冲突」「删分支」、
  「同步代码收尾」或执行 /gitea-pr-lifecycle 时激活。
origin: adapted-from-cursor-babysit-and-gardusig-gh-pr
---

# Gitea PR 全生命周期（MCP）

**目标**：把 PR 从「打开 / 待审」推进到 **已合并 + 本地 develop 对齐 + 功能分支已删**，且符合 [`00-zh-cloud-core.mdc`](../../rules/00-zh-cloud-core.mdc) 与 [`issue-iteration-sync.mdc`](../../rules/issue-iteration-sync.mdc)。

**MCP 服务器**：`user-gitea`（调用前 **必读** MCP tool schema：`pull_request_read`、`pull_request_write`、`pull_request_review_write`、`delete_branch`、`list_commits`）。

**上游**：开 PR 前见 **[`COMMANDS.md`](../../COMMANDS.md)** · **`/git-sync-gitea`**

**互补 skill**：Issue 整理/发版/仓库健康见 [`gitea-ops/SKILL.md`](../gitea-ops/SKILL.md)、Jenkins 盯盘 [`jenkins-ci-watch-fix-loop/SKILL.md`](../jenkins-ci-watch-fix-loop/SKILL.md)、发版后自检 [`cicd-mcp-verification/SKILL.md`](../cicd-mcp-verification/SKILL.md)。Git Flow 入口见 [`COMMANDS.md`](../../COMMANDS.md)。

---

## 口令与模式

| 用户意图                           | 模式         | 说明                                     |
| ---------------------------------- | ------------ | ---------------------------------------- |
| `/gitea-pr-lifecycle` 或「审查并合并 PR #n」 | **ship**     | 审 → 冲突 → CI → 合并 → 收尾（默认）     |
| 「只 review / 代码审查」           | **review**   | 读 diff、发 Review，**不**合并           |
| 「处理冲突 / rebase」              | **conflict** | 仅同步 base 并解决冲突、推送             |
| 「合并 PR #n」                     | **merge**    | 门禁通过后 `pull_request_write` merge    |
| 「合并后收尾」                     | **cleanup**  | fetch → develop → pull → 删本地/远端分支 |

**参数**（命令 `$ARGUMENTS` 或对话中给出）：

```text
<mode> [owner/repo] [#pr] [base=develop]
```

缺省时：从当前 Git 根 `git remote get-url origin` 解析 `owner/repo`；用 `git branch --show-current` 在 `list_pull_requests` 中匹配 head 分支找 PR。

---

## 固定顺序（ship 模式）

```
1. 识别仓库与 PR
2. 预检（mergeable / diff / 关联 Issue）
3. Code Review（本地读 diff + MCP 发 review）
4. 冲突处理（若 mergeable=false）
5. CI / Jenkins 门禁（相关 Job 绿）
6. 用户确认后合并
7. 合并后收尾（每 Git 根各走一遍）
```

**禁止**：未读 schema 盲调 MCP；对 `develop`/`main` **force push**；未确认即 merge；把多仓改动只合一边。

---

## 1. 识别仓库与 PR

```bash
# 在每个会动到的 Git 根分别执行
git branch --show-current
git remote get-url origin
git status -sb
```

MCP：

```json
{ "owner": "izhaong", "repo": "zh-cloud", "state": "open" }
→ list_pull_requests
```

定位 PR 后：

```json
{
  "method": "get",
  "owner": "izhaong",
  "repo": "zh-cloud",
  "index": 5
}
→ pull_request_read
```

记录：`head.ref`、`base.ref`（默认 **develop**）、`head.sha`、`mergeable`、`html_url`。

---

## 2. 预检清单

- [ ] PR 标题/正文含 **`Fixes #n`** / **`Refs #n`**（跨仓用 URL 互链）
- [ ] `mergeable === true`（否则进入 §4）
- [ ] diff 范围与描述一致（`method: get_diff`）
- [ ] 无 `.env`、密钥、token 入库
- [ ] 后端改动是否同步 `zh-cloud-service/docs/engineering/00-CHANGELOG.md`（若适用）
- [ ] 相关 Jenkins Job 最近构建 **SUCCESS**（见 [`jenkins-ci-watch-fix-loop`](../jenkins-ci-watch-fix-loop/SKILL.md)）

---

## 3. Code Review

**读变更**（优先本地，省 token）：

```bash
git fetch origin develop
git diff origin/develop...HEAD
git log origin/develop..HEAD --oneline
```

**MCP 读 PR**：

```json
{ "method": "get_diff", "owner": "...", "repo": "...", "index": N }
→ pull_request_read

{ "method": "get_reviews", ... }
{ "method": "get_review_comments", ... }
```

**评审维度**（输出给用户，再决定是否发 MCP review）：

| 级别        | 含义                                         |
| ----------- | -------------------------------------------- |
| 🔴 **阻塞** | 必须修才能合并（安全、数据丢失、破坏集成线） |
| 🟡 **建议** | 应改进，可跟进了再合                         |
| 🟢 **可选** | 风格/文档，不挡合并                          |

**提交 Review**（用户同意或 mode=ship 且无阻塞项时）：

```json
{
  "method": "create",
  "owner": "izhaong",
  "repo": "zh-cloud",
  "index": 5,
  "commit_id": "<head.sha>",
  "body": "## 摘要\n...\n\n## 测试\n- [ ] ...",
  "state": "APPROVED"
}
→ pull_request_review_write
```

`REQUEST_CHANGES` 时 **停止 ship**，列出待办。

行内评论（可选）：

```json
{
  "method": "create",
  "comments": [{ "path": "src/foo.ts", "new_line_num": 42, "body": "..." }],
  ...
}
```

---

## 4. 冲突处理

当 `mergeable === false` 或 Gitea 提示 behind/conflict：

```bash
git fetch origin
git checkout <head-branch>
git merge origin/develop   # 或 git rebase origin/develop（团队默认 merge）
# 解决冲突 → 最小 diff，勿改无关文件
git add <resolved-files>
git commit -m "fix(merge): 解决与 develop 的冲突"
git push origin HEAD
```

**禁止** `git push --force` 到共享分支，除非用户**明确**要求且仅针对功能分支。

推送后 **重新** `pull_request_read` method `get`，确认 `mergeable: true`。

---

## 5. CI 门禁

- 后端：`zh-cloud-service` 相关 Jenkins Job → MCP `user-jenkins`
- 失败且属 **本 PR 范围**：本地最小修复 → push → 再盯盘至绿
- 失败且 **与 PR 无关**：先 §4 同步 develop，再复跑

---

## 6. 合并

**须用户明确说「合并」或 mode=merge/ship 且无阻塞**。

```json
{
  "method": "merge",
  "owner": "izhaong",
  "repo": "zh-cloud",
  "index": 5,
  "merge_style": "merge",
  "delete_branch": true,
  "title": "可选合并标题"
}
→ pull_request_write
```

合并后再次 `pull_request_read` method `get`，确认 `merged: true`。

---

## 7. 合并后收尾（每个 Git 根）

```bash
git fetch origin
git checkout develop
git pull --ff-only origin develop
git branch -d <head-branch>    # 已合并用 -d；仅删本地 PR 分支
```

远端分支若 MCP merge 未删：

```json
{ "owner": "izhaong", "repo": "zh-cloud", "branch": "feat/hooks-organize-plans" }
→ delete_branch
```

**多仓**：`zh-cloud-service`、`docs`（Gitea：`zh-cloud-docs`）、`zh-cloud`、`zh-cloud-admin-vben` 等 **各自**执行；互链 Issue 上补一句「已合并 #PR」。

---

## Review 评论模板（粘贴后改）

```markdown
## 摘要

（1–3 句：做什么、为什么）

## 变更要点

- …

## 测试 / 验证

- [ ] 本地构建 / 冒烟
- [ ] CI 绿

## 结论

- [ ] ✅ Approve — 可合并
- [ ] ⛔ Request changes — （列出阻塞项）
```

---

## 故障对照

| 现象                | 处理                                                       |
| ------------------- | ---------------------------------------------------------- |
| `mergeable: false`  | §4 同步 develop + 解决冲突                                 |
| push 被拒（behind） | fetch + merge/rebase + push                                |
| Review 提交失败     | 检查 `commit_id` 是否等于当前 `head.sha`                   |
| merge API 403/409   | 分支保护 / 未满足 Required Check → 查 Gitea 设置与 Jenkins |
| 删分支失败          | 确认已合并；保护分支不可删                                 |

---

## MCP 速查

详见 [mcp-reference.md](./mcp-reference.md)。

---

## 参考来源

- Cursor 内置 [`babysit`](file:///Users/zhonghao/.cursor/skills-cursor/babysit/SKILL.md)（PR 盯盘循环）
- [gardusig/cursor-skills `gh-pr`](https://github.com/gardusig/cursor-skills/tree/main/skills/gh/pr)（GitHub 版编排，本 skill 改为 Gitea MCP + zh-cloud 多仓）
