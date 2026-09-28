# 048 · 实施计划

基准 `origin/develop@9032005`，分支 `feat/328-sidebar-show-tags`。

| 步 | 落点 | 说明 |
| -- | ---- | ---- |
| 1 | `lib/state/repositories/sidebar_visibility_repository.dart` | `todo_view_preferences` 行 + `viewPreference` outbox，`get/watch/save`，默认「显示」 |
| 2 | `lib/state/providers.dart` | `sidebarVisibilityRepositoryProvider` + `sidebarShowTagsProvider`（StreamProvider） |
| 3 | `lib/features/shell/sidebar.dart` | `tagEntries` 按偏好门控（只收条目，不收「标签」行 ⇒ spec 取舍 1） |
| 4 | `lib/features/settings/settings_route.dart` | 新增「智能清单」分组 →「标签」行 + 选项弹层（显示/隐藏），`_Tile` 加 `super.key` 与 `trailingText` |
| 5 | 测试 | 仓库层 `test/sidebar_visibility_repository_test.dart`；侧栏 `test/features/shell/sidebar_show_tags_test.dart`；设置 `test/features/settings/sidebar_show_tags_settings_test.dart` |

不动的：`schemaVersion`（仍 22）、侧栏宽度与布局 token、9 张黄金基线、路由表、后端契约（`viewPreference` 实体与 `sourceType/sourceKey/valueJson` 字段 develop 上已存在，本轮只是多一个 `sourceType` 取值）。
