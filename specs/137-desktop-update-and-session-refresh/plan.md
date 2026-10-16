# 137 计划

- 先各自量出真因（Sparkle 缺失配置 / refreshToken 未使用），再做最小修复。
- macOS 更新：只补配置，不动更新流程代码。
- 登录态：在既有 `SessionController` 上接刷新，不新建抽象。

## 步骤

1. 复现与取证：读已签名 entitlements、包内 Info.plist；`rg refreshToken lib/`；
   查后端 `access_token_validity_seconds`。
2. 改 `macos/Runner/{Info.plist,Release.entitlements,DebugProfile.entitlements}`。
3. `AuthGateway.refreshSession` + `ApiClient.memberPost` 透传。
4. `SessionController` 接刷新：bootstrap 续签、401 续签、拒绝/网络两分。
5. `providers.dart` 的 `onUnauthorized` 改接 `refreshOrExpire`。
6. 补判据与台账；同步 `docs/engineering/04-*` 与 `spec.md`。
7. 门禁：analyze、定向测试、反向探针、全量、`flutter build macos --release` 后复核产物。

## 验证策略

- 配置类判据用文件判据（删了照样构建成功、analyze 全绿，只有真点更新才炸）。
- 行为类判据先证「当前实现会红」，再证修复后绿。
- 构建产物复核：`$(PRODUCT_BUNDLE_IDENTIFIER)` 是否真被 Xcode 展开 —— 文件判据
  只能证明写了这行，证明不了替换生效。
