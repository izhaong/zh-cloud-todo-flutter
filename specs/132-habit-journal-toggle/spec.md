# 132 · 习惯级「打卡日志」开关（矩阵 #45 面 ④ 收尾）

## 背景

嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》:60-:62：

> 在「编辑习惯」中底部，可以将打卡日志关闭。

specs/131 已交付 note 的记录与回顾；本切片补习惯级开关（默认开启）。
经 cursor-agent 交叉验证取 A：开关是习惯本身的属性（与周期、提醒同类，
要跟着习惯同步）——`todo_habit` 加列，不写进 `todo_habit_check_in`，
不改 note 的含义（B 前缀约定会与用户正文撞车），也不做本地偏好
（C 换设备就失联，对不齐编辑习惯里的那个开关）。

## 目标（FR）

- FR-1 `todo_habit` 加 `journal_enabled tinyint(1) NOT NULL DEFAULT 1`
  （增量脚本 todo-m15，未在任何环境执行——属改数据，单独批准）。
- FR-2 DO/BaseVO/RespVO 带位；RespVO 读侧 null → true 兼容存量行；
  create 显式默认开；update null 保持原值。
- FR-3 checkIn 语义收紧（交叉验证校验点）：journal 关闭时**打卡仍成功**，
  服务端丢弃本次非空 note（历史 note 保留不清空）——开关管的是
  还要不要记日志，不是打卡能不能成功。
- FR-4 客户端：HabitDto.journalEnabled（缺省 true、旧数据无键按开启）；
  编辑习惯底部「打卡日志」开关；create/update 透传。

## 验收（AC）

- AC-1 服务测试 3 条：关 → note 丢弃且打卡成功 / 开 → note 保留 /
  null → 默认开启。
- AC-2 客户端 DTO 序列化 2 条 + 编辑器开关交互 1 条。
- AC-3 门禁：analyze 0 issue、全量不回归。
