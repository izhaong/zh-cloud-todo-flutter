# GitHub Actions（构建、部署、发版）

> 权威仓库：[izhaong/zh-cloud-todo-flutter](https://github.com/izhaong/zh-cloud-todo-flutter)  
> Gitea 仍为日常 PR/Issue；**合并后须 `git push github develop`**，由 GitHub 完成 **Web 更新** 与 **桌面打包**。

## 工作流一览

| Workflow    | 文件          | 触发                                                    | 作用                                                     |
| ----------- | ------------- | ------------------------------------------------------- | -------------------------------------------------------- |
| **Web**     | `web.yml`     | 推 `develop`（test）/ tag `v*`（prod）/ 手动            | 构建 H5 + SSH 部署宿主机                                 |
| **Desktop** | `desktop.yml` | 推 `develop`（test 包）/ tag `v*`（prod Release）/ 手动 | 三端 **EXE/MSI/DMG/DEB** 安装包（对齐 RustDesk Release） |
| **CI**      | `ci.yml`      | `develop`/`main` 的 PR 与 push                          | analyze + test（不部署）                                 |

Jenkins（Gitea webhook）仅作备用，见 `01-ci-jenkins.md`。

## 推荐更新流程

```text
Gitea：feat/* → PR → merge develop
        ↓
本地：git fetch origin && git checkout develop && git pull --ff-only
        ↓
GitHub：git push github develop
        ↓
Actions 自动：
  · web.yml     → todo-test.zh04.com 更新
  · desktop.yml → 测试环境三端 Artifacts（不建 Release）
```

**生产发版**（Web prod 部署 + 桌面 GitHub Release + 客户端自动更新）：

```bash
# 1. 确保 pubspec.yaml version 与 tag 一致（如 1.0.0+1 → tag v1.0.0）
# 2. 代码已在 github develop（含 .github/workflows/）
git tag v1.0.0
git push github v1.0.0
```

触发：

- `web.yml` → prod SSH 部署（须已配置 Secrets）
- `desktop.yml` → 三端 **`.exe` / `.msi` / `.dmg` / `.deb`** + **GitHub Release**（Release 页含 RustDesk 风格下载表格）

**无本地 tag 时**：Actions → **Desktop** → Run workflow → `build_env=prod`、`create_release=true`、`release_version=1.0.0`。

## 配置 GitHub 远程

```bash
git remote add github https://github.com/izhaong/zh-cloud-todo-flutter.git
git push -u github develop
```

## Repository / Environment 配置（Web 部署）

在 GitHub 仓库 **Settings → Environments** 建 `test`、`production`。

### Secrets（两环境可共用或分别配置）

| Secret            | 说明                                          |
| ----------------- | --------------------------------------------- |
| `DEPLOY_SSH_HOST` | 跳板/宿主机 SSH 主机名                        |
| `DEPLOY_SSH_USER` | SSH 用户                                      |
| `DEPLOY_SSH_KEY`  | 私钥（`-----BEGIN OPENSSH PRIVATE KEY-----`） |

### Variables（按环境区分）

| Variable             | test 示例                            | prod 示例                |
| -------------------- | ------------------------------------ | ------------------------ |
| `DEPLOY_TARGET_DIR`  | `/izhaong/zh-cloud-test`             | `/izhaong/zh-cloud-prod` |
| `DEPLOY_STAGING_DIR` | `/tmp/zh-cloud-staging-todo-flutter` | 同左                     |
| `DEPLOY_SSH_PORT`    | `22`                                 | `22`                     |

部署逻辑与 Jenkins `Jenkinsfile`「部署到宿主机」阶段相同，均内联在 **`.github/workflows/web.yml`** 的 `deploy` Job 中（无 `scripts/`）。

## 安全与可审阅性

- **无 `scripts/` 目录**：构建、打包、SSH 部署均为 workflow / Jenkinsfile 内联步骤，在 PR 中可直接 diff 审阅。
- **SSH 密钥**仅存放在 GitHub Environment Secrets（`DEPLOY_SSH_*`），不进仓库。
- **部署范围**：仅更新 `DEPLOY_TARGET_DIR/todo-flutter/` 下 `dist/`、compose、nginx 模板；`env` 变更前会备份。

## 手动操作

| 场景                                   | 操作                                                                            |
| -------------------------------------- | ------------------------------------------------------------------------------- |
| 只部署 test Web                        | Actions → **Web** → Run workflow → `build_env=test`                             |
| 只打 test 桌面包                       | Actions → **Desktop** → Run workflow → `build_env=test`，`create_release=false` |
| prod 桌面包 + Release + 客户端自动更新 | `git push github vX.Y.Z`（tag 须 semver）                                       |

## 与 Gitea / Jenkins 的分工

| 交付物                   | 推荐流水线               |
| ------------------------ | ------------------------ |
| Web H5 更新（test/prod） | **GitHub `web.yml`**     |
| 桌面安装包               | **GitHub `desktop.yml`** |
| PR 质量门禁              | GitHub `ci.yml`          |
| Gitea 推送触发的 Jenkins | 备用（未推 GitHub 时）   |

桌面细节：`02-desktop-build-packaging.md`；**自动更新**：`04-desktop-github-release-update.md`；compose 模板：`deploy/README.md`。
