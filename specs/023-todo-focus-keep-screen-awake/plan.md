# Todo 专注屏幕常亮实施计划

**Issue:** #256  
**分支：** `codex/256-todo-focus-keep-screen-awake`

## 不变条件

- 只使用现有 `zh_cloud_todo/native` 通道；不新增依赖、服务端 API、Drift 或 outbox。
- 常亮是本地系统展示副作用，所有会话事实仍由现有 Pomodoro API 和 15 秒同步决定。
- 缺失通道/不支持平台必须安全降级，不能把“偏好已保存”叙述成“系统已启用”。

## 任务

1. 对 `FocusImmersionSettings` 补充向后兼容的 `keepScreenAwake` 字段与 JSON 合同；先写旧 JSON/写失败的红测。
2. 在 `NativeIntents` 增加布尔通道方法与缺失插件回退；补 Dart 通道合同测试。
3. 在 Android `MainActivity` 和 iOS `AppDelegate` 处理 `setKeepScreenAwake`；补 Android 参数单测与可用平台编译检查。
4. 将偏好和生命周期安全接入 `PomodoroPage`：RUNNING 前台才启用，PAUSED/后台/清会话/销毁关闭，同值不重复调用；先写页面红测。
5. 跑格式、分析、局部/全量 Flutter、Web、Android/iOS 可用编译与 Claude 分段复核；记录物理设备验收边界后走 PR。
