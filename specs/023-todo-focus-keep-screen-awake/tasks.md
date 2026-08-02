# Todo 专注屏幕常亮任务

- [ ] T001 本地偏好与旧 JSON 兼容合同。
- [ ] T002 Dart 原生通道安全降级合同。
- [ ] T003 Android/iOS 原生开关与 Android 参数合同。
- [ ] T004 页面会话、生命周期与去重接线。
- [ ] T005 全量验证、独立复核与 Gitea PR。

## 阻塞与验收

- Android/iOS 的真实自动锁屏阻止效果需要物理设备；编译或 Dart Mock 不替代该验收。
- iOS 本机若缺少 Platform Support / Simulator runtime，只记录编译或设备门槛，不伪造 iOS 通过。
