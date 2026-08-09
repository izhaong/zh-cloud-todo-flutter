# Todo 专注屏幕常亮任务

- [x] T001 本地偏好与旧 JSON 兼容合同。
- [x] T002 Dart 原生通道安全降级合同。
- [x] T003 Android/iOS 原生开关与 Android 参数合同。
- [ ] T004 页面会话、生命周期与去重接线。
- [ ] T005 全量验证、独立复核与 Gitea PR。

## 阻塞与验收

- 2026-08-09：T001 红测确认旧实现在访问 `keepScreenAwake` 时失败；实现后 `focus_immersion_settings_test.dart` 6/6 通过，定向分析无问题。任务级审查确认旧 JSON 保持 `autoEnter/style`、缺失或错误字段回退 `false`、存储 key 不变，且无越界改动。
- 2026-08-09：T002 红测确认 Dart API 缺失；实现后 `native_entry_page_test.dart` 9/9 与定向分析通过。任务级审查确认只复用 `zh_cloud_todo/native`，精确发送 `{enabled: bool}`，缺失通道、平台异常和所有非 `true` 返回均为安全失败，未影响其它 native intent。
- 2026-08-09：T003 以 Android 参数解析器缺失完成红测；JDK 17 下 Android JVM 合同测试 8 项通过，`:app:compileDebugKotlin` 通过。完整 iOS Runner 编译因本机未安装 iOS 26.5 Platform Support 被 Xcode 拒绝，`swiftc -parse ios/Runner/AppDelegate.swift` 通过但不替代 Runner 编译。任务级审查确认 Android `FLAG_KEEP_SCREEN_ON` 与 iOS `isIdleTimerDisabled` 的严格布尔映射和无效参数路径。
- Android/iOS 的真实自动锁屏阻止效果需要物理设备；编译或 Dart Mock 不替代该验收。
- iOS 本机若缺少 Platform Support / Simulator runtime，只记录编译或设备门槛，不伪造 iOS 通过。
- 当前 Gradle/Kotlin 组合不能以本机 JDK 25.0.3 配置 Android；本切片 Android JVM 与 Kotlin 编译明确使用 JDK 17，JDK 25 的运行时开发线不因此改变。
