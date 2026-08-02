# Todo Focus Record Management Flutter Plan

**Goal:** 把服务端专注记录和计时调整合同变成可操作、可恢复的 Flutter 体验。

**Architecture:** `PomodoroApi` 负责 CommonResult 与 page 合同；`PomodoroPage` 保持会话单飞轮询，同时独立维护最后成功的历史记录快照。所有服务端写操作先成功再改 UI，统计继续通过 Riverpod invalidation 刷新。

## Task 1: API 红绿合同

修改 `efficiency_api_contract_test.dart`，先引用 adjust/backfill/page/updateDuration/deleteRecord 并断言路径、方法和 payload；再实现最小 API。

## Task 2: Widget 红绿旅程

扩展 `pomodoro_page_contract_test.dart` 和 fake API，依次覆盖活动 ±5、新增、编辑/追加、删除确认、失败保留、重试与 320px。

## Task 3: 页面实现

在现有 `PomodoroPage` 中加入时间调整按钮和“专注记录”区；新增/编辑使用可滚动对话框，删除使用确认对话框。避免把真实记录复制进 Drift 或另建状态源。

## Task 4: 全量验证

运行 format、定向测试、`flutter analyze`、`flutter test --concurrency=1`、test Web release 和 Claude CLI；更新规格证据并提交。
