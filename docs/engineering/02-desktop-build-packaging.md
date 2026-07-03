# Todo Flutter — 桌面端构建与打包

> Web/H5 与桌面端均在 **GitHub Actions** 完成；见 `03-github-actions.md`。Jenkins 仅 Gitea 备用。

## 原则

- **不维护 `scripts/` 目录**：构建、打包、部署逻辑全部写在 **`.github/workflows/*.yml`** 与 **`Jenkinsfile`** 中，便于在 GitHub / Jenkins UI 直接审阅。
- **Web/H5 CI**：`.github/workflows/web.yml`
- **桌面端 CI**：`.github/workflows/desktop.yml`
- **同一套 Dart 代码**，`--dart-define` 注入 `TODO_API_BASE_URL`、`TODO_TENANT_ID`
- **各平台在对应 Runner 上构建**（`ubuntu-latest` / `macos-latest` / `windows-latest`）

## GitHub Actions（正式路径）

| Workflow    | 文件                            | 触发                                              | 作用                               |
| ----------- | ------------------------------- | ------------------------------------------------- | ---------------------------------- |
| **Desktop** | `.github/workflows/desktop.yml` | 推 `develop`（test 包）；tag `v*`；手动           | 并行三端安装包                     |
| **Web**     | `.github/workflows/web.yml`     | 推 `develop`（test 部署）；tag `v*`（prod）；手动 | H5 构建 + SSH 部署                 |
| **CI**      | `.github/workflows/ci.yml`      | `develop` / `main` 的 push 与 PR                  | `flutter analyze` + `flutter test` |

### Desktop 工作流

并行 Job（每 Job 内为显式 `flutter build` + 打包命令，见 workflow 文件）：

| Job         | Runner           | 产物                 |
| ----------- | ---------------- | -------------------- |
| Linux x64   | `ubuntu-latest`  | `*-linux-x64.tar.gz` |
| macOS       | `macos-latest`   | `*-macos.zip`        |
| Windows x64 | `windows-latest` | `*-windows-x64.zip`  |

**环境（`build_env`）**

| 触发方式                   | `BUILD_ENV` | 默认 API 基址                       |
| -------------------------- | ----------- | ----------------------------------- |
| 推送 `develop`             | `test`      | `https://client-todo-test.zh04.com` |
| 推送 tag `v*`              | `prod`      | `https://client-todo.zh04.com`      |
| 手动 Run workflow → `test` | `test`      | `https://client-todo-test.zh04.com` |
| 手动 Run workflow → `prod` | `prod`      | `https://client-todo.zh04.com`      |

产物目录：`.gha-dist/desktop/`。  
推送 **`v*` tag**（如 `v1.0.1`，与 `pubspec.yaml` 对齐）会创建 **GitHub Release** 并附三端安装包；桌面客户端**自动更新**读取该 Release（`04-desktop-github-release-update.md`）。  
`develop` 推送仅上传 Actions Artifacts，不建 Release。

详见 **`03-github-actions.md`**。

## 本地调试（非发版路径）

与 `desktop.yml` 中单平台步骤相同，例如 macOS：

```bash
flutter pub get
flutter build macos --release \
  --dart-define=TODO_API_BASE_URL=https://client-todo-test.zh04.com \
  --dart-define=TODO_TENANT_ID=1
ditto -c -k --sequesterRsrc --keepParent \
  build/macos/Build/Products/Release/zh_cloud_todo_flutter.app \
  todo-flutter-test-macos.zip
```

产物命名示例（CI 按 `pubspec.yaml` 版本号生成）：

| 平台        | 文件名示例                                    |
| ----------- | --------------------------------------------- |
| macOS       | `todo-flutter-test-v1.0.0+1-macos.zip`        |
| Linux x64   | `todo-flutter-test-v1.0.0+1-linux-x64.tar.gz` |
| Windows x64 | `todo-flutter-test-v1.0.0+1-windows-x64.zip`  |

## 各平台原始产物路径（未打包前）

| 平台    | `flutter build`                   | 目录                                                           |
| ------- | --------------------------------- | -------------------------------------------------------------- |
| macOS   | `flutter build macos --release`   | `build/macos/Build/Products/Release/zh_cloud_todo_flutter.app` |
| Linux   | `flutter build linux --release`   | `build/linux/x64/release/bundle/`                              |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/`                            |

## 与 Android / iOS

移动端（APK/IPA）尚未接入；可参考同平台 `zh-cloud-beecount-flutter/.github/workflows/release.yml`。
