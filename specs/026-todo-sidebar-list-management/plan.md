# 实施计划

- 把 `list_page.dart:36-63` 的「未完成拦截 + 二次确认 + delete」抽成
  `lib/features/list/list_actions.dart` 的顶层函数，`ListPage` 与侧栏共用同一实现（不复制第二套删除语义）。
- `_SidebarRow` 加可选 `onLongPress`（默认 null ⇒ 不注册手势，其它行零行为变化）；
  `_ListRow` 透传长按 → 侧栏弹 `ModalBottomSheet`，两项 `ListTile`（「编辑」「删除」）。
- 「编辑」走既有 `ListEditorSheet(existing: list)`；「删除」走抽出来的共用函数。
- 测试：`test/features/shell/sidebar_list_management_test.dart` 用既有 `TodoVisualFixture` 起真 Drift 库，
  覆盖长按出表、改名落库、有未完成任务时拦截且不删、确认后删除、取消不写、智能清单不出入口。
