# 070 · 落地方案

1. `TaskFilter` 已有 `tagIds`，无需新字段；`FilterBar` 的 `copyWith` 语义是 `tagIds ?? this.tagIds` ⇒ 传空列表即清空条件。
2. `_AdvancedFilter` 增 `tagIds`；`_draftFilter` 增 `required List<String> tagIds`，预览草稿与应用结果都带它。
3. `_pickAdvancedFilter` 增两个位置参数 `List<TodoTag> tags, bool tagsUnavailable`，由 `FilterBar.build` 用
   `ref.watch(tagsStreamProvider)` 的 `valueOrNull ?? const []` 与 `hasError` 注入；页面侧
   `TasksByListPage._openFilterPanel` 只渲染 `FilterBar`，无需改动 ⇒ 不碰 `tasks_by_list_page.dart`（该文件正被 5 条 open PR 改）。
4. 新增私有组件 `_TagConditionSection`：`Key('task-filter-tag-section')` + 每个标签一层
   `Semantics(label: '标签 <名>，已选中/未选中', selected:, button: true, excludeSemantics: true)` 包住
   `FilterChip(key: Key('task-filter-tag-<id>'))`。
5. `_hasAdvancedFilter` / `_advancedFilterLabel` 各补一档 ⇒ 应用后筛选条入口能显示「标签」。
