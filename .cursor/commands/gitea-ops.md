---
description: >-
  Gitea 全流程（skill gitea-ops）：默认连续执行 Git 同步 + PR 闭环（原 git-sync-gitea →
  gitea-pr-lifecycle ship）。口令「同步代码」。子模式可只跑一段。速查见 .cursor/COMMANDS.md
---

## User Input

```text
$ARGUMENTS
```

## 默认行为（无子模式 / 仅仓库名等参数）

**连续执行两段，不停顿**：

1. **§A Git 同步**（原 `/git-sync-gitea` `sync`）：对齐 develop → 分支 → commit → push → 开/更新 PR
2. **§B PR 闭环**（原 `/gitea-pr-lifecycle` `ship`）：review → 冲突 → CI → 合并 → develop 收尾

口令 **「同步代码」** = 上述默认全流程。

## 子模式路由（只跑一段时显式指定）

| 首参                                                 | 行为                  |
| ---------------------------------------------------- | --------------------- |
| `sync` · `commit` · `push` · `branch`                | **仅 §A** Git 同步    |
| `ship` · `review` · `conflict` · `merge` · `cleanup` | **仅 §B** PR 生命周期 |

### §A Git 同步

解析为：`<mode> [issue=#n] [branch=...] [repo=...]`

| mode       | 行为                                     |
| ---------- | ---------------------------------------- |
| **sync**   | 对齐 develop → 分支 → commit → push → PR |
| **branch** | 仅建功能分支                             |
| **commit** | 仅规范 commit                            |
| **push**   | push + 开/更新 PR                        |

### §B PR 生命周期

解析为：`<mode> [owner/repo] [#pr] [base=develop]`

| mode         | 行为                                     |
| ------------ | ---------------------------------------- |
| **ship**     | review → conflict → CI → merge → cleanup |
| **review**   | 只读 diff + 发 Review，不合并            |
| **conflict** | 同步 develop、解决冲突、推送             |
| **merge**    | 门禁通过后合并                           |
| **cleanup**  | 合并后 checkout develop、pull、删分支    |

示例：

```text
/gitea-ops                          # 默认：§A sync → §B ship（连续）
/gitea-ops zh-cloud-service         # 同上，限定仓库
/gitea-ops sync                     # 仅 Git 同步
/gitea-ops ship izhaong/zh-cloud-service 92   # 仅 PR 闭环
```

## 执行要求

1. **速查**：[`../COMMANDS.md`](../COMMANDS.md)
2. **Skill**：[`../skills/gitea-ops/SKILL.md`](../skills/gitea-ops/SKILL.md)
   - §A 细则：[`../skills/git-sync-gitea/SKILL.md`](../skills/git-sync-gitea/SKILL.md)
   - §B 细则：[`../skills/gitea-pr-lifecycle/SKILL.md`](../skills/gitea-pr-lifecycle/SKILL.md) · [`mcp-reference.md`](../skills/gitea-pr-lifecycle/mcp-reference.md)
3. **规则**：[`00-zh-cloud-core.mdc`](../rules/00-zh-cloud-core.mdc)、[`issue-iteration-sync.mdc`](../rules/issue-iteration-sync.mdc)、[`git-flow-and-release.mdc`](../rules/git-flow-and-release.mdc)
4. **禁止**在 `develop`/`main` 堆功能 commit；**禁止** force push 主干；多仓各建分支、各开 PR、各自收尾
5. §A 完成后**立即**进入 §B，除非用户显式指定了 `sync`/`commit`/`push`/`branch` 等仅同步子模式
