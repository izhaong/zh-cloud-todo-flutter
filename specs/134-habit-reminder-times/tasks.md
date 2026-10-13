# 134 台账（客户端半）

## T1 DTO

- `HabitDto.reminderTimes`（List\<String\>?；fromJson null→null，
  非空 List→List\<String\>）。

## T2 编辑器

- `_reminderTimes` 状态 + `_addReminderTime`（showTimePicker 去重排序）
  + `_pickReminderTime`（已有单值选择器，同时写入 _reminderTimes）。
- UI：chips 行（Wrap + Chip + onDeleted）+「添加时间段」TextButton。
- create/update 透传（服务端 !365 已交付）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format | 0 changed |
| 全量 | 待回填 |
