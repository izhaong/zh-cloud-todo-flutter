# 134 · 习惯提醒多时间段（矩阵 #45 面 ②）

## 背景

嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》:40：

> 提示时间可分在各个时间段 9:00、12:00、18:00、21:00，到点都会自动提醒你。

本端只有单值 reminderAt（一个 DateTime）。矩阵 #45 面 ②。

## 设计（零 breaking：现有调用不受影响）

- `todo_habit` 加 `reminder_times varchar(500)`（JSON 数组 HH:mm；
  NULL = 沿用单值 reminderAt）。
- 客户端 `HabitDto.reminderTimes`（List\<String\>?）+ 编辑器时间段
  chips（添加/删除，HH:mm 排序）。

## 验收（AC）

- AC-1 服务测试 2 条（create/update 透传），todo 模块 527 全绿。
- AC-2 编辑器时间段 chips 可添加/删除。
- AC-3 门禁：analyze 0 issue、全量不回归。
