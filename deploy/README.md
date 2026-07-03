# todo-flutter 部署（Web / H5）

Flutter `build/web` 静态产物经 Jenkins 部署到宿主机 nginx，**路径与旧 `zh-cloud-client/apps/todo` 一致**，便于平滑替换 React 版。

## 宿主机目录

| 环境 | `DEPLOY_TARGET_DIR` 下子路径 | compose 项目名     | 域名（npm）               | 端口  |
| ---- | ---------------------------- | ------------------ | ------------------------- | ----- |
| test | `client/todo`                | `client-todo-test` | client-todo-test.zh04.com | 38090 |
| prod | `client/todo`                | `client-todo`      | client-todo.zh04.com      | 58090 |

目录结构：

```text
client/todo/
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

rsync -a --delete build/web/ /path/to/client/todo/dist/
cd /path/to/client/todo
docker compose -p client-todo-test -f docker-compose.yml --env-file env up -d --force-recreate client-todo
```

## Jenkins

| 环境 | 控制台 | MCP `jobFullName` |
| --- | --- | --- |
| **test** | https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/ | `zh-cloud-test/zh-cloud-todo-flutter` |
| **prod** | https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/ | `zh-cloud-prod/zh-cloud-todo-flutter` |

- 仓库根 **`Jenkinsfile`**，GWT token：**`zh-cloud-todo-flutter`**
- Webhook：`https://jenkins.zh04.com/generic-webhook-trigger/invoke?token=zh-cloud-todo-flutter`
- Flutter 在 CI 内通过 **`ghcr.io/cirruslabs/flutter:stable`** 容器执行
- 完整索引（含 Gitea、部署路径）：**`docs/engineering/01-ci-jenkins.md`**
- 细则见 `zh-cloud-service/script/jenkins/JENKINSFILE-CONVENTIONS.md`
