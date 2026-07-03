# zh-cloud-todo-flutter — Jenkins CI

> **MCP / Agent 查 Job**：优先读本页；`jobFullName` 用于 Jenkins MCP（`getJob`、`getBuild` 等）。

## Jenkins Job（控制台）

| 环境 | Folder | Job 名 | 控制台 URL | `jobFullName`（MCP） |
| --- | --- | --- | --- | --- |
| **test** | `zh-cloud-test` | `zh-cloud-todo-flutter` | https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/ | `zh-cloud-test/zh-cloud-todo-flutter` |
| **prod** | `zh-cloud-prod` | `zh-cloud-todo-flutter` | https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/ | `zh-cloud-prod/zh-cloud-todo-flutter` |

说明：本仓 Job 名**不带** `-test` / `-prod` 后缀（与 Folder `DEPLOY_ENV` 区分环境）；其它部分仓库仍使用 `zh-cloud-*-test` / `zh-cloud-*-prod` 命名。

## Gitea

| 项 | 值 |
| --- | --- |
| 仓库 | `https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter` |
| Script Path | `Jenkinsfile` |
| GWT Webhook | `https://jenkins.zh04.com/generic-webhook-trigger/invoke?token=zh-cloud-todo-flutter` |
| test 触发 | `refs/heads/develop`（及可选 `release/*`） |
| prod 触发 | `refs/tags/vX.Y.Z`（`main` 上打 tag） |

## 部署产物

- Flutter **`build/web`** → 宿主机 **`$DEPLOY_TARGET_DIR/client/todo/dist`**
- 公网 H5：**client-todo-test.zh04.com**（test）/ **client-todo.zh04.com**（prod）
- 部署模板与 compose：仓库根 **`deploy/README.md`**

## 规范索引

- Jenkinsfile 结构：`zh-cloud-service/script/jenkins/JENKINSFILE-CONVENTIONS.md`
- 双环境与日常操作：`zh-cloud-docs/platform/05_发布与运维/24-cicd-operations-standard.md`
- 控制台逐步配置：`zh-cloud-service/docs/engineering/22-cicd-jenkins-gitea-manual-runbook.md`
