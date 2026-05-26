---
title: M3-B2 Flutter 日历最小体验切片
status: completed
todos:
  - title: 为 zh-cloud-todo-flutter 建立独立开发分支
    status: completed
  - title: 读取现有 B1 Flutter 骨架并确认可复用的本地任务数据
    status: completed
  - title: 在主壳中增加日历/日程入口与周/月/年/列表/日程视图切换
    status: completed
  - title: 运行 dart format 与 flutter test 验证
    status: completed
---

## 范围

- 仅修改 `zh-cloud-todo-flutter` 仓。
- 不接新后端，不改接口。
- 复用现有本地任务数据生成日历事件与日程摘要。

## 验收

- 底部导航可进入日历页。
- 日历页可在周 / 月 / 年 / 列表 / 日程之间切换。
- 页面内容来自现有本地任务数据。
- `dart format` 与 `flutter test` 通过。
