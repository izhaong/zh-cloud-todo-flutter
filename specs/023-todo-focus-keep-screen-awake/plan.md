# Todo 专注屏幕常亮实施计划

**Issue:** #256  
**分支：** `codex/256-todo-focus-keep-screen-awake`

## 不变条件

- 只使用现有 `zh_cloud_todo/native` 通道；不新增依赖、服务端 API、Drift 或 outbox。
- 常亮是本地系统展示副作用，所有会话事实仍由现有 Pomodoro API 和 15 秒同步决定。
- 缺失通道/不支持平台必须安全降级，不能把“偏好已保存”叙述成“系统已启用”。

## Task 1: 本地偏好与旧 JSON 合同

**Files:** `lib/features/pomodoro/focus_immersion_settings.dart`、`test/features/pomodoro/focus_immersion_settings_test.dart`

先写失败测试：旧版 JSON `{ "autoEnter": true, "style": "flip" }` 必须读取为 `keepScreenAwake: false`；新值往返保存；缺字段/错误类型/写失败均不得抛出。再以最小字段扩展实现，保持既有存储 key 不变。

## Task 2: Dart 原生通道安全降级合同

**Files:** `lib/native/native_intents.dart`、`test/native_entry_page_test.dart`

先写失败测试，精确要求 `NativeIntents.setKeepScreenAwake(true|false)` 使用 `setKeepScreenAwake` 及 `{ "enabled": bool }`，并在缺失通道、平台异常或返回非 `true` 时安全返回 `false`。不改变其它 native intent 的合同。

## Task 3: Android/iOS 原生开关

**Files:** `android/app/src/main/kotlin/com/zh04/zh_cloud_todo_flutter/{MainActivity,NativeIntentContract}.kt`、`android/app/src/test/kotlin/com/zh04/zh_cloud_todo_flutter/NativeIntentContractTest.kt`、`ios/Runner/AppDelegate.swift`

先为 Android 参数解析写失败 JVM 测试：只接受 `{ "enabled": Boolean }`，拒绝空、非 Map 和字符串布尔值。Android 将 true/false 映射到 add/clear `FLAG_KEEP_SCREEN_ON`，iOS 将布尔值映射到 `UIApplication.shared.isIdleTimerDisabled`；其它方法不变。

## Task 4: 会话与生命周期接线

**Files:** `lib/features/pomodoro/pomodoro_page.dart`、`test/pomodoro_page_contract_test.dart`

先写页面失败测试：已加载且启用偏好时，RUNNING 前台会话只请求一次 `true`；15 秒同会话同步不重复；暂停、清会话与后台请求一次 `false`；恢复和回前台再请求 `true`。在“更多专注操作”提供已说明移动端边界的可切换菜单项，并复用当前本地偏好存储。

## Task 5: 验证、Claude 审查与合并

格式、分析、局部/全量 Flutter、Web、Android JVM/编译和 iOS 可用编译按实际环境运行。Claude CLI 以小段 no-tool stdin 审查每个新增合同；每次静默/超时单独记录且绝不作为通过。物理 Android/iOS 的自动锁屏效果是明确的后续验收门槛。完成后创建与 Issue #256 互链的 PR，按用户直接合并授权处理。
