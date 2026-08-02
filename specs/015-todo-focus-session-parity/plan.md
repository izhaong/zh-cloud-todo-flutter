# Todo Focus Session Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 service 现有专注合同替换 Flutter 硬编码模式，并补齐自定义时长、任务关联、备注与 15 秒多端状态收敛。

**Architecture:** `PomodoroApi` 负责 VO 解析与 HTTP 合同；`PomodoroPage` 只维护当前页面会话、计时和可恢复错误。任务选项来自 Drift 的只读 StreamProvider，活跃会话轮询只读 service，不直接修改任务或 outbox。

**Tech Stack:** Flutter 3.44、Dart 3.11、Riverpod、Dio、Drift、flutter_test。

## Global Constraints

- CUSTOM 分钟必须为 1–1440 的整数；备注裁剪后最大 512 字符。
- 服务端预设是成功事实源；加载失败必须可见且可重试。
- 轮询固定 15 秒，刷新失败保留当前状态，不制造本地完成结论。
- 测试不得连接真实后端；真实环境用例继续受显式 dart-define 保护。

---

### Task 1: 专注 API 合同

**Files:**
- Modify: `lib/core/api/efficiency_api.dart`
- Modify: `test/efficiency_api_contract_test.dart`

**Interfaces:**
- Produces: `PomodoroPresetDto`、`Future<List<PomodoroPresetDto>> presets()`。
- Extends: `complete(int id, {String? remark, DateTime? clientEndAt})`。

- [ ] **Step 1: 写 presets 失败测试**

```dart
final presets = await PomodoroApi(dio).presets();
expect(presets.first.mode, 'MODE_25_5');
expect(presets.first.focusMinutes, 25);
expect(presets.first.breakMinutes, 5);
expect(presets.first.label, '经典 25/5');
```

- [ ] **Step 2: 验证红测**

Run: `flutter test test/efficiency_api_contract_test.dart`
Expected: FAIL，因为 `PomodoroApi.presets` 尚不存在。

- [ ] **Step 3: 最小实现**

```dart
class PomodoroPresetDto {
  const PomodoroPresetDto({required this.mode, required this.label, this.focusMinutes, this.breakMinutes});
  final String mode;
  final String label;
  final int? focusMinutes;
  final int? breakMinutes;
}
```

`presets()` GET `/pomodoro/presets` 并用 `_unwrapData` 解析列表；`complete` 只在非空时发送裁剪后的 remark，并发送 ISO-8601 `clientEndAt`。

- [ ] **Step 4: 验证绿测**

Run: `flutter test test/efficiency_api_contract_test.dart`
Expected: PASS，且断言 complete 请求体包含 `remark` 和 `clientEndAt`。

### Task 2: 服务端预设、自定义时长与任务关联

**Files:**
- Modify: `lib/state/providers.dart`
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Produces: `allTasksStreamProvider`，只读 `TaskRepository.watchAll()`。
- Consumes: Task 1 的 `PomodoroPresetDto` 与 `PomodoroApi.presets()`。

- [ ] **Step 1: 写失败 Widget 测试**

```dart
expect(find.text('经典 25/5'), findsOneWidget);
await tester.tap(find.text('自定义'));
await tester.enterText(find.byKey(const Key('pomodoro-custom-minutes')), '45');
await tester.tap(find.text('开始专注'));
expect(api.startedMode, 'CUSTOM');
expect(api.startedMinutes, 45);
```

另一个测试覆盖任务下拉只显示 `serverId != null && !completed`，start 收到选择的服务端 ID。

- [ ] **Step 2: 验证红测**

Run: `flutter test test/pomodoro_page_contract_test.dart`
Expected: FAIL，因为页面仍硬编码三种模式且无自定义输入/任务选择。

- [ ] **Step 3: 最小实现**

新增预设加载状态、可重试错误、ChoiceChip/Wrap 模式选择、自定义整数输入和 `DropdownButtonFormField<int?>` 任务选择。开始按钮仅在预设可用且 CUSTOM 输入合法时启用。

- [ ] **Step 4: 验证绿测与窄屏**

Run: `flutter test test/pomodoro_page_contract_test.dart`
Expected: PASS，并覆盖 320 宽度无 overflow。

### Task 3: 备注与多端状态收敛

**Files:**
- Modify: `lib/features/pomodoro/pomodoro_page.dart`
- Modify: `test/pomodoro_page_contract_test.dart`

**Interfaces:**
- Consumes: `PomodoroApi.active/pause/resume/complete/cancel`。
- Produces: 15 秒轮询、可恢复 `syncError/actionError` 与完成备注提交。

- [ ] **Step 1: 写失败测试**

```dart
await tester.enterText(find.byKey(const Key('pomodoro-remark')), ' 完成初稿 ');
api.completeError = StateError('offline');
await tester.tap(find.text('完成'));
expect(find.textContaining('完成失败'), findsOneWidget);
expect(find.text('完成初稿'), findsOneWidget);
expect(find.text('取消'), findsOneWidget);
```

再用 `tester.pump(const Duration(seconds: 15))` 证明远端 PAUSED 更新为“已暂停”，下一轮 active 返回 null 后本地回到“开始专注”。

- [ ] **Step 2: 验证红测**

Run: `flutter test test/pomodoro_page_contract_test.dart`
Expected: FAIL，因为页面无备注输入、错误保留和周期刷新。

- [ ] **Step 3: 最小实现**

页面创建 15 秒 `_syncTicker`；每轮通过请求序号拒绝过期响应。完成成功后才清空会话与备注，失败只设置可读屏错误。`dispose` 取消计时与轮询。

- [ ] **Step 4: 验证绿测**

Run: `flutter test test/pomodoro_page_contract_test.dart test/efficiency_api_contract_test.dart`
Expected: PASS，无 pending timer 或 dispose 异常。

### Task 4: 规格与全量门禁

**Files:**
- Modify: `spec.md`
- Modify: `specs/015-todo-focus-session-parity/tasks.md`

**Interfaces:**
- Consumes: Tasks 1–3 的最终行为。
- Produces: 可追溯的本地、Claude、Gitea/Jenkins 证据边界。

- [ ] **Step 1: 定向与静态验证**

Run: `flutter analyze`
Run: `flutter test test/pomodoro_page_contract_test.dart test/efficiency_api_contract_test.dart`
Expected: 0 issue，定向测试全部 PASS。

- [ ] **Step 2: 全量与 Web 构建**

Run: `flutter test --concurrency=1`
Run: `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`
Expected: 非 live 测试全部 PASS、受保护 live 用例按条件跳过、Web build 成功。

- [ ] **Step 3: Claude CLI 聚焦复核**

只读审查 API、页面和两个测试文件；必须返回明确 verdict，超时或空输出不计通过。

- [ ] **Step 4: 外部恢复门禁**

恢复后补 Issue 编号、规范化分支名、创建 PR，等待 Gitea Actions 和 Jenkins develop 构建；未取得真实响应与部署证据前不勾选外部验收。
