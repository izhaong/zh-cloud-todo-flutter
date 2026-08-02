# Todo 番茄沉浸模式任务

- [x] T001 建立本机沉浸偏好存储的红绿合同。
- [x] T002 建立独立沉浸展示层的视觉、语义和窄屏合同。
- [x] T003 将沉浸状态与现有专注会话状态机安全连接。
- [ ] T004 通过格式、静态分析、局部/全量测试、Web 与 Claude CLI 门禁。
- [x] T005 创建并合入 Gitea PR，并保留 CI/Jenkins 的真实证据。

## 执行证据

- 2026-08-02：滴答官方“如何保持专注状态”审计确认现有 Flutter 没有白噪音、沉浸、常亮、悬浮、翻转、严格模式或 Live Activity 表面；Service 也没有这些展示偏好合同。以不伪造原生能力为前提，先切出纯 Flutter 沉浸模式。
- 2026-08-02：偏好存储先以缺少文件、类型和接口的编译错误完成红测；实现默认值、`digital/flip/pixel`、损坏数据回退和写失败降级后，`focus_immersion_settings_test.dart` 3/3 通过。
- 2026-08-02：沉浸展示层先以缺少文件的编译错误完成红测；实现纯展示组件后，`focus_immersive_pane_test.dart` 3/3 通过，覆盖三种样式、计时器语义、可展开动作、暂停措辞，以及 320px/1.3 倍字体无溢出。
- 2026-08-02：页面接线先以缺少菜单、状态和展示层的断言失败完成红测；实现菜单、会话内自动进入和本地展示偏好后，`pomodoro_page_contract_test.dart --plain-name immersive` 6/6 通过，覆盖手动进出、暂停/恢复/取消、会话启动/远端恢复的自动进入、手动退出不重入、远端清除退出与样式持久化。
- 2026-08-02：格式检查、`flutter analyze`、沉浸相关 50 项测试、全仓串行 `flutter test --concurrency=1`（701 通过、26 项环境开关跳过）以及带 test API/tenant 参数的 Web release 均通过。Web 只出现既有 `flutter_secure_storage_web` Wasm dry-run 兼容警告，`build/web` 已成功产出。
- 2026-08-02：Claude CLI 存储合同审查返回 `VERDICT: PASS`；Sonnet 探针可立即响应，但展示源码的三次无工具 stdin 审查（240、118、30 行）均静默/超时，首次超过 90 秒后终止。该独立复核缺口已记录，不能解释为 Claude 批准；待 CLI 恢复后重试展示与页面源码分段审查。
- 2026-08-02：[PR #254](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/254) 已合并到 `develop`（`ed762f9`）。Jenkins 控制器健康、队列为空，但按仓库 URL 与分支查询未找到 Job；Gitea Actions 为 0 次运行。两者均为缺少远端门禁，不能替代本地 701 项测试或宣称远端 CI 通过。

## 当前边界

- 本规格只覆盖应用内沉浸展示和本机偏好。音频资产/播放器、原生权限和系统级功能必须在独立规格中实现和验收。
