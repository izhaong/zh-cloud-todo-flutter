# Todo 专注屏幕常亮规格

**Issue:** #256  
**状态：** 设计完成，待实现

## 目标

在已有番茄专注会话中提供设备本地的“专注时保持屏幕常亮”偏好。它只影响当前前台 Android/iOS 应用的自动锁屏；不会暂停、完成、取消、创建或同步服务端专注会话。

## 可验收行为

- 用户可从“更多专注操作”查看并切换 `专注时保持屏幕常亮`，并且界面说明该能力只在 Android/iOS 有效。
- 偏好默认关闭，使用既有本地 `todo_focus_immersion_settings_v1` JSON 存储；旧的 `{autoEnter, style}` 数据读取时 `keepScreenAwake` 必须安全回退为 `false`。
- 偏好开启时，只有已加载的 RUNNING 会话且应用处于前台才向原生层请求启用；PAUSED、会话清除、进入后台、登出清理和页面销毁时请求关闭。
- 从 PAUSED 恢复或从后台回到前台时，若偏好仍开启且会话 RUNNING，则重新请求启用。
- 每个“期望状态”只请求一次；15 秒会话同步不得重复发送同值原生调用。
- Dart 通道缺失或原生返回不支持时安全返回 `false`，不显示已启用的虚假系统状态，不影响会话或偏好保存。

## 原生边界

- Android：`MainActivity` 在现有 MethodChannel 上以 `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` 显式 add/clear flag。
- iOS：`AppDelegate` 在同一通道设置 `UIApplication.shared.isIdleTimerDisabled`。
- Web、macOS、Windows、Linux 不实现原生常亮；Dart 安全降级。
- 不含白噪音/音频资产、悬浮窗、翻转传感器、严格模式、Live Activity，也不新增 REST、Drift、outbox、权限或服务端字段。

## 验证边界

- Flutter 单元/Widget 测试验证通道参数、旧偏好兼容、生命周期和会话转换的精确调用次数。
- Android JVM 单测验证参数解析；可用 SDK 时编译 Android。iOS 在可用 Xcode Platform Support 时做 Runner 编译检查。
- 系统是否真的在具体机型上阻止自动锁屏，必须由 Android/iOS 物理设备验收；本地 Dart 测试和编译不替代该证据。
