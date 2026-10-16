# 137 台账

> 本切片原在一次性 worktree `fix/todo-desktop-update-and-session-refresh` 上完成，
> 该 worktree 于 2026-10-16 的一次 worktree 清理中被删除（未提交改动已抢救进
> `worktree-rescue-20261016-010729/rescue-update-session.{patch,full.tgz}`）。
> 本轮把它捡回，重放到当时最新的 `origin/develop` 上并重跑门禁。

## T1 取证（先量后改）

- [x] macOS 更新真因：已签名 entitlements 有 `app-sandbox`，但包内 `Info.plist` 无
      `SUEnableInstallerLauncherService`、entitlements 无 `-spks`/`-spki`；
      报错原文出自 `Sparkle.framework/Versions/B/Sparkle` 的 `SPUInstallerDriver`。
- [x] 排除签名/订阅问题：线上 appcast 有 `sparkle:edSignature`，`SUPublicEDKey` 与
      `~/.config/zh-cloud-todo-flutter/updater-keys/sparkle_public_edkey.txt` 一致，
      Release DMG 可下载；`SUFeedURL` 可达。
- [x] 登录真因：`rg refreshToken lib/` 除模型定义外 0 命中；后端 `default` 客户端
      `access_token_validity_seconds = 1800`。旧 `bootstrap()` 校验不过即
      `clearSession()` ⇒ 30 分钟后每次启动必掉登录。

## T2 macOS 更新配置

- [x] `macos/Runner/Info.plist` 加 `SUEnableInstallerLauncherService = true`。
- [x] `Release.entitlements` / `DebugProfile.entitlements` 加 `-spks` / `-spki`
      mach-lookup 例外（用 `$(PRODUCT_BUNDLE_IDENTIFIER)`，由 Xcode 展开）。
- [x] 不开 `SUEnableDownloaderService`：本应用已有 `network.client`。

## T3 登录态刷新

- [x] `AuthGateway.refreshSession` + `AuthGatewayImpl` 实现（查询参数，非请求体）。
- [x] `ApiClient.memberPost` 透传 `queryParameters` / `options`。
- [x] `SessionController`：bootstrap 续签、`refreshOrExpire()`、`_refreshWasRejected()`
      两分、`_refreshing` 单飞。
- [x] `providers.dart` 的 `onUnauthorized` 改接 `refreshOrExpire()`。

## T4 判据

- [x] 新增 `test/macos_update_sandbox_contract_test.dart`（2 条，文件判据）。
- [x] `test/state/session_state_test.dart` 新增 4 条：续签成功不掉登录、
      网络不可确认保留会话、信封 401 才清会话、业务 401 先续签。
- [x] `test/core/auth/auth_gateway_test.dart` 新增 1 条：刷新走查询参数 +
      保留 mobile / tenantId。
- [x] 4 个既有 `AuthGateway` 替身补 `refreshSession`：
      `widget_test.dart`、`change_password_page_test.dart`、
      `todo_auth_page_test.dart`、`session_state_test.dart`。

### 反向探针（本轮在**重放后的 develop** 上重跑，均实测会红）

| 探针 | 结果 |
| --- | --- |
| 删 `Info.plist` 的 `SUEnableInstallerLauncherService` | 该文件 `-1`，plist 那条红 |
| bootstrap 去掉续签分支（回到旧行为） | `+10 -2`（「启动不该掉登录」「网络不可确认保留会话」红） |

## T5 文档

- [x] `docs/engineering/04-desktop-github-release-update.md` 加「macOS 沙盒接线」节，
      并订正原「DMG 未签名则不能完成替换安装」的绝对说法（ad-hoc 下走同 team ID 例外，
      但首次仍需用户手动放行）。
- [x] `spec.md` §4.1 补刷新语义、§6 补桌面更新沙盒配置。

## 过程教训

- **配置类缺陷不会被常规门禁抓到**：这两处 plist/entitlements 缺失时，
  `flutter analyze` 全绿、全量单测也全绿（本轮实测），只有真点更新才炸。
  ⇒ 必须用文件判据钉住，不能只靠「跑一遍测试」。
- **文件判据证不了变量替换**：判据只能证明写了
  `$(PRODUCT_BUNDLE_IDENTIFIER)-spks`，证明不了 Xcode 真会展开。
  故补构建产物复核（下面门禁最后一行的读数）。
- **「异常类型」不足以区分拒绝与网络问题**：芋道的「刷新令牌已过期」是 HTTP 200 +
  信封 `code:401`，被 `envelopeFailure` 包成 `DioException`，只看 `on TodoAuthException`
  会把它错判成网络问题而永不清会话。必须连同信封码 / HTTP 状态码一起判。
- 首版 `_refresh` 用 `catch (_) { return null; }` 抹平了两种失败，会导致断网时
  误清会话（与既有离线承诺相反）；改为异常上抛 + 显式分类。
- **worktree 清理会连未提交改动一起删**：本切片因此丢过一次。清理前先
  `git status` 逐棵看，或先打成 patch/bundle 再删。

## 最终门禁（重放到 `origin/develop` tip `2e00505c` 后重跑）

| 门 | 读数 |
| --- | --- |
| flutter analyze | `No issues found! (ran in 5.9s)` |
| 定向测试（7 个文件，含本切片全部判据） | `+43 All tests passed!` |
| 反向探针 1（删 plist 键） | 红（按预期） |
| 反向探针 2（去掉续签分支） | `+10 -2`（按预期） |
| `flutter build macos --release` | `✓ Built … zh_cloud_todo_flutter.app (65.7MB)`（重放后重跑） |
| 产物复核：`plutil -p Info.plist` | `"SUEnableInstallerLauncherService" => true` |
| 产物复核：`codesign -d --entitlements :-` | `com.zh04.zhCloudTodoFlutter-spks` / `-spki`（**变量已展开**） |

构建产物复核在重放后的 develop 上重跑，两项读数与首次一致 ⇒ 配置确实进了签名产物，
不是只写在源文件里。构建会顺带改写 `macos/Podfile.lock` 与 `Runner.xcscheme`
（Flutter 3.44.8 的 SwiftPM 迁移噪声，与本切片无关），已在提交前还原。

### 另立账

- 端到端「点更新真的装上」未验：需先发一个带本修复的新版 DMG，再由旧版拉取。
- Developer ID 签名 + 公证：本机 0 个有效签名身份，属发版链路。
- FL #568（去掉 auto_updater、改手动打开 Release 页）与本切片方向相反，
  本切片不照 #568 执行；已在 #568 留评论请裁定。
