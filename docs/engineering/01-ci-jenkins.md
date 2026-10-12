# zh-cloud-todo-flutter — Jenkins CI/CD

Todo Flutter 使用一个根级 Gitea Multibranch Job `zh-cloud-todo-flutter`，并由根级 `zh-cloud` List View 聚合展示。Web/桌面 GitHub Actions 仍见 [`03-github-actions.md`](03-github-actions.md)，但它们不替代 Jenkins 对合并后 `develop` 的 test 构建与部署证据。

## Jenkins Job

| 项 | 值 |
| --- | --- |
| Job | `zh-cloud-todo-flutter` |
| 控制台 | https://jenkins.zh04.com/job/zh-cloud-todo-flutter/ |
| `jobFullName`（MCP） | `zh-cloud-todo-flutter`；分支为 `zh-cloud-todo-flutter/develop` 等 |
| Script Path | `Jenkinsfile` |
| 展示 | 根级 `zh-cloud` List View，不从 View/Folder 注入变量 |

## 触发与 ref 路由

- Jenkinsfile 不声明 `GenericTrigger`、`pollSCM`、cron 或 `withFolderProperties()`；触发只由 Jenkins Gitea SCM Source 自动维护的 `/gitea-webhook/post` 负责。
- Branch Source 只发现 `develop`、`main` 与严格 SemVer `v*` tag，不发现 PR；Job 配置与 Jenkinsfile 不重复维护触发器。
- `develop` → `DELIVERY_MODE=test`：重新分析、测试、构建 Web，并在 `DEPLOY_TO_HOST=true` 时部署 test。
- `main` → `DELIVERY_MODE=candidate`：使用 production 公开配置构建并归档候选 Web 制品，不部署 production。
- `vX.Y.Z[-prerelease]` → `DELIVERY_MODE=production`：在同 digest promotion 尚未落地前 fail-closed，禁止从 tag 重新构建或人工 input 绕过。

## 仓库自带运行时

- Jenkins 不依赖全局 Flutter、Dart、Node、JDK 或 Maven Tool Installation；根 Jenkinsfile 声明 `ghcr.io/cirruslabs/flutter:3.44.0` 构建容器。
- 节点已缓存镜像时直接复用；未缓存时最多重试拉取三次。缓存存在、镜像可拉取与流水线最终通过是三类独立证据。
- Pipeline 显式使用 `built-in`，总超时 10 分钟，保留最近 10 次构建及制品；不叠加 `quietPeriod`，也不在日志枚举全部环境变量或参数。
- test 部署只使用 Jenkins 已登记的 Publish Over SSH Server `192.168.3.94`；不再默认使用当前 agent 无法解析的 `host.docker.internal`。
- `tool/test_jenkinsfile_runtime_contract.sh` 冻结固定运行时、无旧插件、无 Job 名推断、ref 路由、并发排队、平台 options、安全日志、部署目录参数与 production fail-closed 契约，并由 Jenkins 的“环境检查”阶段执行。

## GitHub Actions（主路径）

| 项 | 值 |
| --- | --- |
| 仓库 | https://github.com/izhaong/zh-cloud-todo-flutter |
| Web 部署 | `.github/workflows/web.yml` |
| 各端安装包 | `.github/workflows/desktop.yml`（Linux / macOS / Windows / Android / 未签名 iOS；tag 挂到 GitHub Release） |
| 说明 | `docs/engineering/03-github-actions.md` |

## 部署产物

- **Web（Jenkins）**：`build/web` → `.jenkins-dist/todo-flutter-web.tar.gz` → `$DEPLOY_TARGET_DIR_TEST/todo-flutter/dist`；Compose、env 示例与 nginx 全部来自本仓 `deploy/`。
- **Web（GitHub）**：`build/web` → `$DEPLOY_TARGET_DIR/todo-flutter/dist`（`web.yml` SSH）；不得与 Jenkins 对同一次 test 交付双活触发。
- **桌面与移动端（GitHub）**：`.gha-dist/desktop/*` → Actions Artifacts；`v*` tag 挂到 GitHub Release，下载地址就是 Release 附件
- test 部署只由 `develop` 进入；`main` 与 tag 不使用生产部署参数或 SSH Publisher。

## 规范索引

- GitHub Actions：`docs/engineering/03-github-actions.md`
- 桌面打包：`docs/engineering/02-desktop-build-packaging.md`
- Jenkinsfile 结构：`zh-cloud-service/script/jenkins/JENKINSFILE-CONVENTIONS.md`
