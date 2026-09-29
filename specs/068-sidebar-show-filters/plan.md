# 技术方案：侧栏「过滤器」显隐偏好（FL Issue #336）

## 落点清单

| 文件 | 改什么 |
| --- | --- |
| `lib/state/repositories/sidebar_visibility_repository.dart` | 新增 `defaultShowFilters`、`getFilters()`、`watchFilters()`、`saveFilters()`；写路径由 `save()` 的内联 `jsonEncode` 改成私有 `_write(patch)`，两个写方法都走它（避免互相覆盖另一键）；`_decode` 拆成 `_jsonMap` + `_decodeKey(key, fallback)` |
| `lib/state/providers.dart` | 新增 `sidebarShowFiltersProvider`，与 `sidebarShowTagsProvider` 同一形状（无仓库时回默认「显示」） |
| `lib/features/shell/sidebar.dart` | 三态读法多一份 `showFilters`；`todo-sidebar-row-filters` 那一行由 `if (showFilters)` 包起来 |
| `lib/features/settings/settings_route.dart` | 「智能清单」分组下新增一档「过滤器」（自己的 `AppCard`）；`_pickShowFilters` 抄 `_pickShowTags` 的形状；三态标签抽成 `_visibilityLabel` / `_visibilityStale`，标签那两条改为转调 |
| `test/features/shell/sidebar_show_filters_test.dart` | 新增用例：侧栏显隐三种态、两键互不覆盖、设置页那一档存在且落库、写失败可见、320px + 1.3 倍两种态不溢出 |

## 为什么这样切

- **不新增表、不加 schema 版本**：`todo_view_preferences` 已经是"一行 JSON 存一档偏好"的容器，
  `SIDEBAR_VISIBILITY`/`global` 那行的键位天然能放第二个开关。
  代价是一个真实的坑：`save()` 原本 `jsonEncode({'showTags': …})` 是整块覆盖 ——
  加第二个键后必须先读旧行再 patch，否则改一个开关会把另一个顶回默认。
  这条由用例「两个开关写同一行偏好：改「过滤器」不许把「标签」的取值盖回默认」钉住，两个方向都断言。
- **设置页那一档单独一张卡**：并进「标签」那张卡会改掉「标签」档的合并语义节点
  （同目录 `sidebar_show_tags_settings_test.dart` 里四件套 ② 那条实测变红），
  分组标题仍共用「智能清单」。

## 回退

整条特性只加了一个偏好键、一个 provider、一处 `if`、一档设置项。回退 = 去掉 `if (showFilters)`
并把 `saveFilters` 调用点删掉；旧行里多出来的 `showFilters` 键被 `_jsonMap` 忽略，不影响 `showTags` 读取。
