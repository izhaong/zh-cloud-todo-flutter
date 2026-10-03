# 改动点

- `lib/core/api/efficiency_api.dart`：`CountdownDto` 加 `isPinned`（`fromJson` 读 `isPinned`）；`CountdownApi.setPinned(id, pinned)` 走 `PUT /todo/countdown/{id}/pinned?value=`
- `lib/features/countdown/countdown_page.dart`：`_CountdownTile` 加 `onPin`；菜单在未归档且未置顶时给「置顶」项（key `countdown-menu-pin-<id>`）；`_runPin` 写入后 invalidate `countdownsProvider` 与 `archivedCountdownsProvider` 再 await 重取；失败置 `_pinError` 并挂 `AppRefreshFailedHint(key: countdown-pin-error)`
- 测试：`test/features/countdown/countdown_pin_test.dart`，替身复刻服务端独占（置某条时清其余）以保证界面顺序断言量的是真行为
