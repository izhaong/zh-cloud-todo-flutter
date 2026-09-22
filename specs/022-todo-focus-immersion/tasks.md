# Todo 番茄沉浸模式任务

- [x] T001 建立本机沉浸偏好存储的红绿合同。
- [x] T002 建立独立沉浸展示层的视觉、语义和窄屏合同。
- [x] T003 将沉浸状态与现有专注会话状态机安全连接。
- [x] T004 通过格式、静态分析、局部/全量测试、Web 与 Claude CLI 门禁。
- [x] T005 创建并合入 Gitea PR，并保留 CI/Jenkins 的真实证据。

## 执行证据

- 2026-08-02：滴答官方“如何保持专注状态”审计确认现有 Flutter 没有白噪音、沉浸、常亮、悬浮、翻转、严格模式或 Live Activity 表面；Service 也没有这些展示偏好合同。以不伪造原生能力为前提，先切出纯 Flutter 沉浸模式。
- 2026-08-02：偏好存储先以缺少文件、类型和接口的编译错误完成红测；实现默认值、`digital/flip/pixel`、损坏数据回退和写失败降级后，`focus_immersion_settings_test.dart` 3/3 通过。
- 2026-08-02：沉浸展示层先以缺少文件的编译错误完成红测；实现纯展示组件后，`focus_immersive_pane_test.dart` 3/3 通过，覆盖三种样式、计时器语义、可展开动作、暂停措辞，以及 320px/1.3 倍字体无溢出。
- 2026-08-02：页面接线先以缺少菜单、状态和展示层的断言失败完成红测；实现菜单、会话内自动进入和本地展示偏好后，`pomodoro_page_contract_test.dart --plain-name immersive` 6/6 通过，覆盖手动进出、暂停/恢复/取消、会话启动/远端恢复的自动进入、手动退出不重入、远端清除退出与样式持久化。
- 2026-08-02：格式检查、`flutter analyze`、沉浸相关 50 项测试、全仓串行 `flutter test --concurrency=1`（701 通过、26 项环境开关跳过）以及带 test API/tenant 参数的 Web release 均通过。Web 只出现既有 `flutter_secure_storage_web` Wasm dry-run 兼容警告，`build/web` 已成功产出。
- 2026-08-02：Claude CLI 存储合同审查返回 `VERDICT: PASS`；Sonnet 探针可立即响应，但展示源码的三次无工具 stdin 审查（240、118、30 行）均静默/超时，首次超过 90 秒后终止。该独立复核缺口已记录，不能解释为 Claude 批准；待 CLI 恢复后重试展示与页面源码分段审查。
- 2026-08-02：[PR #254](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/254) 已合并到 `develop`（`ed762f9`）。Jenkins 控制器健康、队列为空，但按仓库 URL 与分支查询未找到 Job；Gitea Actions 为 0 次运行。两者均为缺少远端门禁，不能替代本地 701 项测试或宣称远端 CI 通过。
- 2026-09-22：T004 结项，缺口只剩 2026-08-02 记录「三次无工具 stdin 审查静默/超时」的 Claude CLI 独立复核。本机工具链重建后（Flutter 3.44.8 / Dart 3.12.2，`develop` HEAD `a1d7733`）以只读 `plan` 模式（仅 `Read`/`Grep`/`Glob`）复核展示层与页面接线，返回 `VERDICT: PASS`，**无 Blocker/Important**，并逐条确认：进入/退出只改展示字段、不触碰 `_ticker/_secondsLeft/_paused` 与 API（`pomodoro_page.dart:678-717`）；远端暂停/结束经 `_syncActiveSession → _activateSession/_clearSession` 收敛并强制退出沉浸；手动退出由 `_immersiveDismissedSessionId` 记住、15 秒轮询不重入；偏好只落 `shared_preferences` 键 `todo_focus_immersion_settings_v1`，与 outbox/Drift/服务端完全隔离；`FocusImmersivePane` 只 import `material.dart` 与本偏好文件、动作全走构造回调，无任何 API 直调；320×844 + 1.3 倍字体下三种样式无 `takeException`。同日本地门禁复跑全绿：`git diff --check` 干净、`flutter analyze` `No issues found!`、全量 `flutter test --exclude-tags 'golden || performance' --concurrency=1` `+712 ~26: All tests passed!`、golden 9/9、test 配置 Web release `✓ Built build/web`。
- 2026-09-22：该复核另提 2 项 Minor，登记后**不在本切片改动**：① 沉浸操作层的暂停/完成/取消按钮在 `_actionPending` 时仍呈现可点击态（`pomodoro_page.dart:1076-1081`），而普通页面对应按钮此时置灰（`:1344-1367`）；因 `_pause/_resume/_finish` 内部均有 `if (_actionPending) return;` 守卫，不会产生双写，只是连点缺反馈与进度指示，属一致性瑕疵；② 计时区 `Semantics(label:…, button: true, excludeSemantics: true)`（`focus_immersive_pane.dart:51-58`）的 label 只描述计时内容与样式，未描述「点击切换操作层」这一行为。两者均不违反 FR 条款，留待后续沉浸迭代一并处理。

## 当前边界

- 本规格只覆盖应用内沉浸展示和本机偏好。音频资产/播放器、原生权限和系统级功能必须在独立规格中实现和验收。
