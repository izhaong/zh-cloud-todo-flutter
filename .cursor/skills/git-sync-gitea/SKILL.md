---
name: git-sync-gitea
description: >-
  zh-cloud 规范提交与同步：Git Flow（develop 集成线）、Conventional Commits 中文摘要、
  小步 commit、推送、Gitea 开 PR。用户说「同步代码」、规范提交、push、开 PR 或执行 /git-sync-gitea 时激活。
origin: adapted-from-gardusig-git-start-commit-push-and-issue-iteration-sync
---

# Git 同步与规范提交（Gitea / zh-cloud）

**目标**：在**每个独立 Git 根**完成 **对齐 develop → 功能分支 → 规范 commit → push → 开/更新 PR**，且符合 [`git-flow-and-release.mdc`](../../rules/git-flow-and-release.mdc) 与 [`issue-iteration-sync.mdc`](../../rules/issue-iteration-sync.mdc)。

**下游 skill**：PR **审查 / 合并 / 删分支** 用 [`gitea-pr-lifecycle/SKILL.md`](../gitea-pr-lifecycle/SKILL.md) 或 **`/gitea-pr-lifecycle`**（本 skill **不**默认 merge）。

**MCP**：`user-gitea` — `list_pull_requests`、`pull_request_write`（create/update）、`issue_read`（可选）。

---

## 口令与模式

| 用户意图                     | 模式             | 说明                                     |
| ---------------------------- | ---------------- | ---------------------------------------- |
| **`同步代码`** / `/git-sync-gitea` | **sync**（默认） | 全链路：核对 → 分支 → commit → push → PR |
| 「只提交」                   | **commit**       | 规范 message + 小步 commit，不 push      |
| 「推送并开 PR」              | **push**         | push + create/update PR                  |
| 「从 develop 拉分支」        | **branch**       | 对齐 develop + 新建功能分支              |
| 「多仓一起同步」             | **sync** + 多根  | 各 Git 根 **分别** 走一遍                |

**参数**（`$ARGUMENTS`）：

```text
<mode> [issue=#n] [branch=feat/42-slug] [repo=zh-cloud-service]
```

缺省：扫描**工作区内有改动的 Git 根**；Issue 编号来自对话或本地追踪表。

---

## 固定顺序（sync 模式）

```
1. 开工核对（分支 / status / remote）
2. 对齐 develop（fetch + pull --ff-only）
3. 分支门禁（禁止在 develop/main 堆功能提交）
4. 规范 commit（可多次小步）
5. push -u origin HEAD
6. Gitea 创建或更新 PR → develop
7. （可选）PR 创建后 checkout develop + 删本地功能分支
8. 提示：合并用 /gitea-pr-lifecycle
```

**禁止**：在 `develop`/`main` 直接功能 commit；force push 主干；多仓只 push 一边；commit 含密钥。

---

## 1. 开工核对

**每个会动到的 Git 根**（`zh-cloud-service`、`docs`（Gitea：`zh-cloud-docs`）、`zh-cloud`、`zh-cloud-admin-vben` 等）：

```bash
git branch --show-current
git status -sb
git remote get-url origin
git log -3 --oneline
```

| 当前分支                      | 动作                                                   |
| ----------------------------- | ------------------------------------------------------ |
| `develop` 且有未提交改动      | **必须**新建功能分支（§3）                             |
| `feat/*` / `fix/*` / `docs/*` | 继续，确认从 develop 拉出                              |
| 已合并的旧功能分支            | `checkout develop` → `pull --ff-only` → 为新工作建分支 |

---

## 2. 对齐 develop

```bash
git fetch origin
git checkout develop
git pull --ff-only origin develop
```

若已在功能分支且需同步基线：

```bash
git fetch origin
git merge origin/develop   # 或 rebase（团队默认 merge）
# 有冲突 → 最小解决后 commit，见 gitea-pr-lifecycle §4
```

---

## 3. 分支门禁

**集成线**：**`develop`**（非 upstream 的 `main`）。**`main`** 仅 hotfix / 发版。

| 类型        | 分支名                  | PR 目标                   |
| ----------- | ----------------------- | ------------------------- |
| 新功能      | `feat/<issue>-<slug>`   | `develop`                 |
| 缺陷        | `fix/<issue>-<slug>`    | `develop`                 |
| 文档/规则   | `docs/<issue>-<slug>`   | `develop`                 |
| 工程维护    | `chore/<issue>-<slug>`  | `develop`                 |
| 线上 hotfix | `hotfix/<issue>-<slug>` | `main` → 再回灌 `develop` |

**无 Issue 时**（`issue-iteration-sync` 例外）：`feat/<简述>`、`docs/<简述>` 等，PR 正文说明「无前置 Issue」。

```bash
git checkout -b feat/42-count-login   # 从 develop
```

---

## 4. 规范 Commit

格式（权威：[`conventional-commits.mdc`](../../rules/conventional-commits.mdc)）：

```text
<type>(<scope>): <中文摘要>

[可选正文：影响面、验证方式]
```

| type       | 用途                                               |
| ---------- | -------------------------------------------------- |
| `feat`     | 新功能                                             |
| `fix`      | 缺陷修复                                           |
| `refactor` | 重构                                               |
| `docs`     | 文档                                               |
| `chore`    | 工程/脚本                                          |
| `ci`       | CI/Jenkins（**admin-vben 仓 CI 一律 `ci` scope**） |

**原则**：

- **摘要与说明用中文**；type 英文小写
- **小步提交**：每个可独立描述、可回滚的步骤一次 commit
- 提交前：`git diff` / `git diff --cached` 检查无 `.env`、token
- 后端目录/约定变更 → 同步 [`zh-cloud-service/docs/engineering/00-CHANGELOG.md`](../../../zh-cloud-service/docs/engineering/00-CHANGELOG.md)

```bash
git add <paths>   # 勿 git add -A 盲加无关文件
git commit -m "$(cat <<'EOF'
feat(count): 新增租户解析接口

EOF
)"
```

**用户未明确说「提交」时**：先展示拟用 message 与 staged 文件清单，获确认再 `commit`。

---

## 5. Push

```bash
git push -u origin HEAD
```

push 失败（behind）：§2 同步 develop 后重试；**禁止** force push `develop`/`main`。

---

## 6. 创建 / 更新 PR（Gitea MCP）

**先查是否已有 open PR**（同 head 分支）：

```json
{ "owner": "izhaong", "repo": "zh-cloud-service", "state": "open" }
→ list_pull_requests
```

**新建**：

```json
{
  "method": "create",
  "owner": "izhaong",
  "repo": "zh-cloud-service",
  "head": "feat/42-count-login",
  "base": "develop",
  "title": "feat(count): 租户登录能力",
  "body": "## Summary\n- …\n\nFixes #42\n\nRefs izhaong/zh-cloud-docs#7\n\n## Test plan\n- [ ] …"
}
→ pull_request_write
```

**更新**已有 PR：`method: update`，补全 `Fixes`/`Refs`、Test plan。

| 关联        | 写法                      |
| ----------- | ------------------------- |
| 本仓关单    | `Fixes #n`                |
| Epic / 跨仓 | `Refs #n` 或 Issue/PR URL |
| 无 Issue    | 正文说明原因              |

PR 标题与首条 commit 摘要风格一致（中文 + conventional）。

---

## 7. PR 创建后本地收尾（可选，团队约定）

PR **已成功创建**后，若不再向同一 PR 追加提交：

```bash
git fetch origin
git checkout develop
git pull --ff-only origin develop
git branch -D feat/42-count-login   # 远端 PR 分支保留
```

合并进 develop 后的收尾 → **`/gitea-pr-lifecycle cleanup`**。

---

## 8. 多仓 sync

对**每个有改动的 Git 根**重复 §1–§7：

- **一仓一分支一 PR**
- 跨仓 PR 互链 `Refs` + URL
- 子模块指针 bump → 父仓 **另开** Issue + PR

---

## 与 `/gitea-pr-lifecycle` 的分工

| 阶段                              | Skill / 命令                |
| --------------------------------- | --------------------------- |
| 分支、commit、push、开 PR         | **`/git-sync-gitea`**（本 skill） |
| Review、冲突、merge、合并后删分支 | **`/gitea-pr-lifecycle`**             |

推荐顺序：**`/git-sync-gitea`** → **`/gitea-pr-lifecycle`**。速查 **[`COMMANDS.md`](../../COMMANDS.md)**。

---

## 输出清单（结束时）

- [ ] 各 Git 根：分支名、commit SHA 列表
- [ ] PR URL（新建或更新）
- [ ] `Fixes`/`Refs` 是否齐全
- [ ] 是否已回到 `develop` / 删本地分支
- [ ] 待办：合并请用 `/gitea-pr-lifecycle`

---

## 参考来源

- [gardusig/cursor-skills `git-start` / `git-commit` / `git-push`](https://github.com/gardusig/cursor-skills/tree/main/skills/git)
- zh-cloud [`issue-iteration-sync.mdc`](../../rules/issue-iteration-sync.mdc)「口令『同步代码』」
