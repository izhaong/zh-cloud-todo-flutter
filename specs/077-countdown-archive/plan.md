# 实现方案

## 触点（只动这几处）

- `lib/core/api/efficiency_api.dart`
  - `CountdownDto` 增 `final bool archived;`，构造默认 `false`，`fromJson` 读 `j['archived'] == true`
  - `CountdownApi.list()` 改为 `list({bool archived = false})`，把 `{'archived': archived}` 作为 `queryParameters` 传给 `${ApiConfig.todoPrefix}/countdown/list`
  - 新增 `CountdownApi.setArchived(int id, bool archived)`，走 `PUT ${ApiConfig.todoPrefix}/countdown/$id/archived`，`queryParameters: {'value': archived}` —— 与同文件里番茄钟的 `setTimerArchived` 同形
- `lib/state/efficiency_providers.dart`：在 `countdownsProvider` 旁增 `archivedCountdownsProvider`，调 `api.list(archived: true)`
- `lib/features/countdown/countdown_page.dart`
  - AppBar 增页面级「...」`PopupMenuButton`（key `countdown-page-more`），菜单项「已归档」（key `countdown-menu-archived`）
  - 页面状态加 `_showArchived`，据此决定 watch 哪个 provider；两视图共用 `_countdownList`
  - `_CountdownTile` 增 `onArchive` / `onRestore` 与条目级「...」菜单（key `countdown-tile-more-<id>`，项 key `countdown-menu-archive-<id>` / `countdown-menu-restore-<id>`），文案逐字取「归档」「恢复」
  - 写操作沿用页面已有的 `_writePending` 重入闸门；失败时保留已加载列表并在列表上方显示 `AppRefreshFailedHint`（key `countdown-archive-error`）

## 四件套怎么落

- 窄屏与放大字号：入口是 AppBar 与卡片上的图标按钮，菜单靠 `PopupMenuButton` 自适位；用例在 320 宽 + 1.3 倍字缩放的本页 context 里实测菜单项可点
- 读屏：菜单按钮给 `Semantics(label:)`，归档项 label 含「归档」，恢复项含「恢复」
- 失败保留数据：`setArchived` 抛错不清空列表，`valueOrNull` 继续渲染，提示可重试
- 过期响应不覆盖新响应：主列表与已归档走两个独立 provider，切换视图时迟到的主列表响应不会写进已归档视图

## 不做

不改 `GET /list` 的返回结构，不动 `type` 列，不做「显示分组」开关（见 spec 范围之外）。
