# todo-flutter 部署（Web / H5）

本目录为 **zh-cloud-todo-flutter 唯一 compose 权威源**（`docker-compose.{test,prod}.yml`、`env.*.example`、`nginx/`）。**GitHub Actions** 构建后 SSH 同步到宿主机；Jenkins 为备用。

## 宿主机目录

| 环境 | `DEPLOY_TARGET_DIR` 下子路径 | compose 项目名      | 域名（npm）               | 端口  |
| ---- | ---------------------------- | ------------------- | ------------------------- | ----- |
| test | `todo-flutter`               | `todo-flutter-test` | client-todo-test.zh04.com | 38090 |
| prod | `todo-flutter`               | `todo-flutter`      | client-todo.zh04.com      | 58090 |

目录结构：

```text
todo-flutter/
  dist/              # Flutter build/web（GitHub Actions / Jenkins rsync 更新）
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

## Jenkins（备用）

Gitea webhook 仍可触发 Jenkins；**推荐**合并后 `git push github develop` 走 GitHub Actions 更新。

## GitHub Actions（推荐）

| Workflow | 触发 | 作用 |
| -------- | ---- | ---- |
| `web.yml` | 推 `develop` / tag `v*` | H5 构建 + SSH 部署 |
| `desktop.yml` | 推 `develop` / tag `v*` | 桌面安装包 |
| `ci.yml` | PR / push | analyze + test |

配置与 Secrets：`docs/engineering/03-github-actions.md`

## 从旧路径迁移（`client/todo`）

若宿主机仍保留 React 版 `client/todo` 栈，Flutter 首次部署会在 **`todo-flutter/`** 新建目录；npm 域名不变时，需在 npm 将反代端口指向新目录 `env` 中的 `CLIENT_PORT`，并停掉旧 `client-todo-test` / `client-todo` compose 项目以免端口冲突。
