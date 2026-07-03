# 桌面端自动更新（GitHub Release）

> 仅 **macOS / Linux / Windows** 桌面客户端；Web / 移动端不检查。  
> 安装包来源：[izhaong/zh-cloud-todo-flutter Releases](https://github.com/izhaong/zh-cloud-todo-flutter/releases)

## 机制

1. 启动并登录后，应用请求 GitHub API 读取 Release。
2. 将 Release **tag**（须为 `vX.Y.Z`）与当前 `pubspec` / `package_info` 版本比较。
3. 若远端更新，按本机平台匹配 **RustDesk 风格**安装包并弹窗：
   - macOS：`*-aarch64.dmg` / `*-x86_64.dmg`
   - Linux：`*-x86_64.deb`
   - Windows：`*-x86_64.exe`（优先）或 `*-x86_64.msi`
4. 用户点「前往下载」用系统浏览器打开 GitHub 资产链接（**不**在应用内静默安装）。

实现：`lib/github_release_update.dart`；UI 入口在主页 AppBar「检查更新」与启动静默检查。

## 与 CI 的对应关系

| 环境     | GitHub Release                                                 | 客户端检查 API                       |
| -------- | -------------------------------------------------------------- | ------------------------------------ |
| **prod** | 推送 `v*` tag → `desktop.yml` 创建正式 Release                 | `GET .../releases/latest`            |
| **test** | 可选 prerelease（`TODO_UPDATE_CHANNEL=test` 或 test API 域名） | `GET .../releases` 取最新 semver tag |

**发版步骤（prod 桌面自动更新生效）**：

```bash
# pubspec.yaml version 与 tag 对齐，例如 1.0.1
git tag v1.0.1
git push github v1.0.1
# desktop.yml 上传三端包并创建 GitHub Release
```

## 构建参数（`--dart-define`）

| 参数                  | 默认                            | 说明                                    |
| --------------------- | ------------------------------- | --------------------------------------- |
| `TODO_GITHUB_REPO`    | `izhaong/zh-cloud-todo-flutter` | `owner/repo`                            |
| `TODO_UPDATE_CHECK`   | `true`                          | 设为 `false` 关闭检查                   |
| `TODO_UPDATE_CHANNEL` | 空（按 API 域名推断）           | `test` / `prod` 强制渠道                |
| `TODO_API_BASE_URL`   | 本地默认                        | 含 `-test.` 时按 test 渠道含 prerelease |

桌面 CI 构建时无需改以上参数；prod Release 使用 `https://client-todo.zh04.com` 即走 latest Release。

## 安全说明

- 仅访问 **公开** GitHub API，无 token、无任意 shell。
- 下载链来自 GitHub Release **assets**，用户自行在浏览器完成安装。
- 关闭检查：`--dart-define=TODO_UPDATE_CHECK=false`。
