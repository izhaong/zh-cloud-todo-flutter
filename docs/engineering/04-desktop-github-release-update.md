# 桌面端自动更新（GitHub Release）

> 仅 **macOS / Windows** 用 Sparkle 在应用内安装。**Android** 下载 Release 里的 APK 后交给系统安装器。**Linux** 在设置页打开 GitHub Release。Web / iOS 不检查。  
> 安装包来源：[izhaong/zh-cloud-todo-flutter Releases](https://github.com/izhaong/zh-cloud-todo-flutter/releases)

## 机制

插件是 [`auto_updater`](https://pub.dev/packages/auto_updater)：macOS 用 Sparkle，Windows 用 WinSparkle。它不读 GitHub Release JSON，读 Release 里的 `appcast.xml`。Android 用 [`ota_update`](https://pub.dev/packages/ota_update) 下载同一个 Release 里的 `*-android.apk`，再拉起系统安装器。

1. macOS / Windows 启动后调用 `setFeedURL`，每天检查一次。有新版本时由 Sparkle / WinSparkle 弹出安装界面。
2. Android 启动后请求 GitHub `releases/latest`。版本更高时下载 APK 并打开安装界面。
3. 设置 → 关于 → **检查更新**：macOS / Windows 立刻再查 appcast；Android 再查 APK；Linux 用浏览器打开 `releases/latest`。
4. `desktop.yml` 在创建 GitHub Release 时，把 `dmg` / `exe` 写进 `appcast.xml` 并一起上传。APK 仍作为 Release 资产，不写进 appcast。`deb`、IPA 不进订阅。

订阅地址：

`https://github.com/izhaong/zh-cloud-todo-flutter/releases/latest/download/appcast.xml`

实现：`lib/core/update/`。macOS 的 `SUFeedURL` / `SUPublicEDKey` 在 `macos/Runner/Info.plist`。Windows 的 `windows/dsa_pub.pem` 会装到 exe 旁边。

## 签名

Sparkle 拒绝没有签名的更新包。私钥不入库，放在 GitHub Actions secrets：

| Secret | 内容 |
| --- | --- |
| `SPARKLE_ED25519_KEY` | Ed25519 私钥 PEM |
| `WINSPARKLE_DSA_PRIVATE_KEY` | 1024 位 DSA 私钥 PEM |

本机已生成的对应文件在 `~/.config/zh-cloud-todo-flutter/updater-keys/`（`sparkle_ed25519.pem`、`dsa_priv.pem`）。仓库里只有公钥。没配这两个 secret 时，Release 仍会带上 `appcast.xml`，但安装包没有签名，更新装不上。

macOS 安装还要求应用本身经过 Developer ID 签名。当前流水线打出的 DMG 未签名，Sparkle 在签名补上之前不能完成替换安装。

## 构建参数（`--dart-define`）

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `TODO_UPDATE_FEED_URL` | 上面的 `appcast.xml` | 覆盖订阅地址 |
| `TODO_UPDATE_CHECK` | `true` | `false` 时关闭检查，设置页不显示入口 |
