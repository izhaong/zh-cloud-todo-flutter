# 137 · 桌面端更新失败 + 每次启动重新登录

## 背景

两条用户实测反馈，同属「桌面端日常可用性」：

1. **macOS 应用内更新必失败**：设置 → 检查更新（或启动后台检查）下载完 DMG 后弹
   `Update Error! An error occurred while launching the installer. Please try again later.`
2. **每次启动都要重新登录**：macOS 档关掉应用再打开就回到登录页。

> 编号说明：本轮原用 136，落地时发现 `specs/136-desktop-user-journey-and-sync-conflict`
> 已被另一功能占用，故改用 137（避免 specs 重号，正是 FL #395 / service #309 记录的那类问题）。

## 判据（先量后改，两条都在本机复现）

### 一、Sparkle 沙盒接线缺失

- 现象句出自 Sparkle 的 `SPUInstallerDriver`（装在应用包里的
  `Sparkle.framework/Versions/B/Sparkle` 可 `strings` 到原文）。
- 本应用是沙盒档：已签名 entitlements 里 `com.apple.security.app-sandbox = true`（实测
  `codesign -d --entitlements :- /Applications/zh_cloud_todo_flutter.app`）。
- 但包内 `Info.plist` **没有** `SUEnableInstallerLauncherService`，entitlements 里也
  **没有** `-spks` / `-spki` 两个 mach-lookup 服务名 —— 正是 Sparkle 沙盒文档要求的两项。
- 结论：这不是签名/网络问题，是纯配置缺失。appcast 本身正常（线上 `<enclosure>` 带
  `sparkle:edSignature`，`SUPublicEDKey` 与 `~/.config/.../updater-keys/` 里的公钥一致，
  Release DMG 可下载）。

### 二、访问令牌 30 分钟 + 刷新令牌从没用过

- 后端 `default` OAuth2 客户端 `access_token_validity_seconds = 1800`（30 分钟），
  `refresh_token_validity_seconds = 2592000`（30 天）；见 `zh-cloud-service` 的
  `system_oauth2_client` 初始数据。
- 客户端把 `refreshToken` 存进 `SessionStore`，但 `rg refreshToken lib/` 除
  `auth_session.dart` 的模型定义外 **0 命中** —— 从来没被用过。
- 于是启动 `bootstrap()` 拿过期 accessToken 去校验 ⇒ 401 ⇒ 直接
  `clearSession()` + 标「登录已失效」⇒ 用户重新登录。**这是每次启动掉登录的直接原因**，
  与钥匙串能否写入无关。

## 内容

### macOS 更新（配置）

- `macos/Runner/Info.plist`：加 `SUEnableInstallerLauncherService = true`；
  不加 `SUEnableDownloaderService`（本应用已有 `network.client`，按官方文档不该开）。
- `macos/Runner/Release.entitlements` 与 `DebugProfile.entitlements`：加
  `com.apple.security.temporary-exception.mach-lookup.global-name =
  [$(PRODUCT_BUNDLE_IDENTIFIER)-spks, $(PRODUCT_BUNDLE_IDENTIFIER)-spki]`。

### 登录态（代码）

- `AuthGateway` 加 `refreshSession(TodoAuthSession)`；实现走后端
  `POST /app-api/todo-member/auth/refresh-token?refreshToken=...`（`@RequestParam`，
  不是请求体）。响应不含 mobile / tenantId，用本机会话补齐。
- `ApiClient.memberPost` 加 `queryParameters` / `options` 透传。
- `SessionController`：
  - `bootstrap()` 校验不过时先 `_tryRefresh`，续得上就保持登录并落盘；
  - 新增 `refreshOrExpire()`，业务 401 也先续签再决定是否结束会话；
  - `_refreshWasRejected()` 把「服务端拒绝」（信封/HTTP 401、其它 4xx）与
    「网络不可确认」（connectionError / timeout / 5xx）分开：只有前者清会话，
    后者保留本地会话与 Drift 数据（沿用既有离线承诺）；
  - 并发 401 共用同一次刷新（`_refreshing` 单飞）。
- `providers.dart`：`onUnauthorized` 由 `expireSession()` 改为 `refreshOrExpire()`。

## 边界

- 不改后端：`refresh-token` 接口已存在且 `@PermitAll`，刷新令牌不轮换。
- 不引入刷新令牌轮换/过期时间本地预判：保持最小改动，靠服务端答复判定。
- 未做 Developer ID 签名 + 公证：本机 0 个有效签名身份，属发版链路，另立账。
  ad-hoc 签名下 Sparkle 走「同 team ID」例外分支，沙盒接线正确时能完成替换安装，
  但首次仍会被 Gatekeeper 拦一次需手动放行。见 `docs/engineering/04-desktop-github-release-update.md`。
- 本仓 `FL #568`「去掉 auto_updater、改各端手动打开 Release 页」与本切片方向相反，
  本切片**不**照 #568 执行（#568 另需裁定，见该单评论）。

## 验证

- `test/macos_update_sandbox_contract_test.dart`：plist / 两档 entitlements 的文件判据。
- `test/state/session_state_test.dart`：续签成功不掉登录、网络不可确认保留会话、
  信封 401 才清会话、业务 401 先续签。
- `test/core/auth/auth_gateway_test.dart`：刷新走查询参数、保留 mobile / tenantId。
- `flutter build macos --release` 后对产物复核：`SUEnableInstallerLauncherService = true`，
  且签名 entitlements 里 `$(PRODUCT_BUNDLE_IDENTIFIER)` 已展开成
  `com.zh04.zhCloudTodoFlutter-spks` / `-spki`（Xcode 变量替换是否生效的唯一实证）。
