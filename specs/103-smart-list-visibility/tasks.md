# Tasks: specs/103-smart-list-visibility

- [x] T001 仓储层：`SmartListVisibility` 枚举 + `getSmartListStates`/`watchSmartListStates`/`saveSmartListState`（inbox 守卫）+ `_jsonMap` 放宽保留 String；provider `sidebarSmartListStatesProvider`
- [x] T002 侧栏：7 行按状态过滤渲染（auto 用 TaskStats 计数）+「新建清单」右侧设置入口
- [x] T003 管理页弹层 `smart_list_manager_sheet.dart`：7 行、inbox 固定「显示」、三档/两档按 FR-5
- [x] T004 测试：仓储用例 + 侧栏用例 + 管理弹层用例
- [x] T005 变异探针（仓储守卫/侧栏过滤/弹层落库 各一条）+ dart format + analyze 0 issue
- [ ] T006 commit 后全量门禁（flutter test 全量）+ 收口（PR → #337 留言 → 矩阵 #19 追记 → 父仓 bump）
