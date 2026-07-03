# zh-cloud-todo-flutter — Jenkins CI（备用）

> **推荐**：Web 更新与桌面打包走 **GitHub Actions**，见 **`03-github-actions.md`**。  
> 本页为 Gitea webhook → Jenkins 备用路径（未同步推 GitHub 时仍可用）。

## Jenkins Job（控制台）

| 环境     | Folder          | Job 名                  | 控制台 URL                                                                      | `jobFullName`（MCP）                  |
| -------- | --------------- | ----------------------- | ------------------------------------------------------------------------------- | ------------------------------------- |
| **test** | `zh-cloud-test` | `zh-cloud-todo-flutter` | https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/ | `zh-cloud-test/zh-cloud-todo-flutter` |
| **prod** | `zh-cloud-prod` | `zh-cloud-todo-flutter` | https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/ | `zh-cloud-prod/zh-cloud-todo-flutter` |

## GitHub Actions（主路径）

| 项 | 值 |
| --- | --- |
| 仓库 | https://github.com/izhaong/zh-cloud-todo-flutter |
| Web 部署 | `.github/workflows/web.yml` |
| 桌面打包 | `.github/workflows/desktop.yml` |
| 说明 | `docs/engineering/03-github-actions.md` |

## Gitea

| 项          | 值                                                                                    |
| ----------- | ------------------------------------------------------------------------------------- |
| 仓库        | `https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter`                                |
| Script Path | `Jenkinsfile`                                                                         |
| GWT Webhook | `https://jenkins.zh04.com/generic-webhook-trigger/invoke?token=zh-cloud-todo-flutter` |

## 部署产物

- **Web（GitHub）**：`build/web` → `$DEPLOY_TARGET_DIR/todo-flutter/dist`（`web.yml` SSH）
- **桌面（GitHub）**：`.jenkins-dist/desktop/*` → Actions Artifacts / Release
- compose：`deploy/`（权威）

## 规范索引

- GitHub Actions：`docs/engineering/03-github-actions.md`
- 桌面打包：`docs/engineering/02-desktop-build-packaging.md`
- Jenkinsfile 结构：`zh-cloud-service/script/jenkins/JENKINSFILE-CONVENTIONS.md`
