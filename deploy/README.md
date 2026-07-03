# todo-flutter 部署（Web / H5）

本目录为 **zh-cloud-todo-flutter 唯一 compose 权威源**（`docker-compose.{test,prod}.yml`、`env.*.example`、`nginx/`）。Jenkins 构建后同步到宿主机，**不再**使用 `zh-cloud-client/deploy/apps/todo`。

## 宿主机目录

| 环境 | `DEPLOY_TARGET_DIR` 下子路径 | compose 项目名       | 域名（npm）               | 端口  |
| ---- | ---------------------------- | -------------------- | ------------------------- | ----- |
| test | `todo-flutter`               | `todo-flutter-test`  | client-todo-test.zh04.com | 38090 |
| prod | `todo-flutter`               | `todo-flutter`       | client-todo.zh04.com      | 58090 |

目录结构：

```text
todo-flutter/
  dist/              # Flutter build/web（Jenkins rsync 更新）
  nginx/client.nginx.conf.template
  docker-compose.yml
  env                # 从 env.*.example 初始化，勿提交密钥
```

## 本地手工部署（调试）

```bash
flutter build web --release \
  --dart-define=TODO_API_BASE_URL=https://client-todo-test.zh04.com \
  --dart-define=TODO_TENANT_ID=1

rsync -a --delete build/web/ /path/to/todo-flutter/dist/
cd /path/to/todo-flutter
docker compose -p todo-flutter-test -f docker-compose.yml --env-file env up -d --force-recreate todo-flutter
```

## Jenkins

| 环境 | 控制台 | MCP `jobFullName` |
| --- | --- | --- |
| **test** | https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/ | `zh-cloud-test/zh-cloud-todo-flutter` |
| **prod** | https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/ | `zh-cloud-prod/zh-cloud-todo-flutter` |

- 仓库根 **`Jenkinsfile`**，GWT token：**`zh-cloud-todo-flutter`**
- Webhook：`https://jenkins.zh04.com/generic-webhook-trigger/invoke?token=zh-cloud-todo-flutter`
- Flutter 在 CI 内通过 **`ghcr.io/cirruslabs/flutter:stable`** 容器执行（Docker Pipeline `inside()`）
- 完整索引：**`docs/engineering/01-ci-jenkins.md`**
- 细则见 `zh-cloud-service/script/jenkins/JENKINSFILE-CONVENTIONS.md`

## 从旧路径迁移（`client/todo`）

若宿主机仍保留 React 版 `client/todo` 栈，Flutter 首次部署会在 **`todo-flutter/`** 新建目录；npm 域名不变时，需在 npm 将反代端口指向新目录 `env` 中的 `CLIENT_PORT`，并停掉旧 `client-todo-test` / `client-todo` compose 项目以免端口冲突。
