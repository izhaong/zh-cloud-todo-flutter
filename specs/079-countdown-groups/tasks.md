# 任务清单

## 第 202 轮（显示分组，未收口）

- [x] 契约核对：后端 `AppTodoCountdownRespVO` 已透出 `type`，本轮纯读侧接线
- [x] 取号：FL develop 到 078，扫全部远端分支后 079 未被占
- [x] 红测：实现前编译挂 `Error: No named parameter with the name 'type'`
- [x] 实现：`CountdownDto.type`、`_showGroups`、「显示分组」菜单项、四档渲染与 `_tileFor` 抽公共卡片
- [x] 单文件读数：`flutter test test/features/countdown/countdown_group_test.dart` 全过（用例子述）
- [ ] 四件套的「独立读屏语义」未满足，已立 FL #455 给改法：分组标题的 `Semantics(label:)` 写法在测试里量不到（`descendant` 命中 0、整屏 label 不唯一），那条用例本轮摘掉了——摘掉不等于通过
- [ ] 门禁与 VERDICT 未跑完/未取到：本分支只推上去占位，未开 PR、未合并、矩阵 #50 未改判
