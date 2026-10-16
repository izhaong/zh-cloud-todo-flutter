# 143 计划

## 切片

- T1 模型：`TaskCaptureDefaults` 加 `defaultReminderMinutes`（int?），toJson/fromJson/==/hashCode
  同步扩展；null 语义＝「不提醒」。
- T2 UI：`_TaskCaptureDefaultsPage` 加「默认提醒」下拉（7 档），保存/回读走既有仓储。
- T3 消费·单条：`TaskQuickAddSheet._save` 建提醒时按默认偏移换算 fireAt；
  过去时刻跳过建提醒（任务照建、无失败提示）。
- T4 消费·批量：`attachResolvedReminders` 加 `defaultReminderMinutes` 形参，
  两个调用点接线（home_shell / tasks_by_list_page）。
- T5 测试：`test/features/task/task_default_reminder_test.dart`（AC-1..5 逐条 +
  反向探针）。
- T6 台账与门禁回写。

## 验证

- `flutter analyze` 0 issue
- `TZ=Asia/Shanghai flutter test` 全量（基线 +1922 ~26 -1[已知 #569]）
- 探针：改错换算方向（dueAt + minutes）、跳过条件写反、null 档丢进 toJson
  各自让对应用例变红。
