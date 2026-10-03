# 任务清单：侧栏清单「置顶」

基准：分支 feat/341-list-pinned，起点 `origin/develop` 的 `2f170cdac487f62b7c2011f40c6e4398e2c6d7c4`。

## 实现

- [x] `lib/core/db/app_database.dart`：`TodoLists` 加 `isPinned` 列，`schemaVersion` 由 24 抬到 25，
      迁移块用既有写法（先 `_columnExists` 再 `addColumn`）
- [x] `lib/core/db/app_database.g.dart`：`dart run build_runner build --delete-conflicting-outputs` 重生成
- [x] `lib/state/repositories/list_repository.dart`：新增 `setPinned`（写列 + 登记 outbox），
      `watchAll` 与 `getAll` 的排序首位换成置顶优先
- [x] `lib/core/sync/sync_coordinator.dart`：清单落库分支读回 `isPinned`（此前只读 sortOrder 等字段，置顶会被丢弃）
- [x] `lib/features/list/list_actions.dart`：动作表加「置顶 / 取消置顶」，就地处理并显示失败
- [x] `lib/features/shell/sidebar.dart`：清单行包 `Dismissible`（`endToStart`），左滑唤出同一张动作表，长按保留
- [x] 新增 `test/state/list_pinned_repository_sync_test.dart` 与 `test/features/shell/sidebar_list_pin_test.dart`
- [x] 既有 `test/app_database_migration_test.dart` 的 13 处 `user_version` 期望由 24 抬到 25，
      并按同文件先例补一条 v24→v25 步进用例（跑完 14 条全过）

## 门禁（最终字节各跑一次，日志留档）

- [x] `git diff --check` rc=0
- [x] `dart format --output=none --set-exit-if-changed` 本轮 8 个显式文件 rc=0（未做全仓原地格式化）
- [x] `flutter analyze` rc=0，读数 `No issues found!`（日志 /tmp/an-341e.log）
- [x] `flutter test --tags golden` rc=0，读数 `+9: All tests passed!`（基线 9 张一张未重录，日志 /tmp/g4-341.log）
- [x] `flutter test --exclude-tags 'golden || performance' --concurrency=1` rc=0，读数 `+1387 ~26: All tests passed!`（日志 /tmp/g5b-341.log）
- [x] `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` rc=0，读数 `✓ Built build/web`（日志 /tmp/g6-341.log）
- [x] 定向用例读数：`test/features/shell/sidebar_list_pin_test.dart` 6 条、`test/state/list_pinned_repository_sync_test.dart` 5 条、
      `test/app_database_migration_test.dart` 14 条，各跑各绿（日志 /tmp/t3.log 与 /tmp/mig.log）
- [x] 反向探针：把 `sidebar.dart` 的滑出方向改成 `startToEnd` ⇒ 该文件 `+1 -5`（左滑唤不出动作表），
      还原后 `cmp -s` 证字节一致再跑回 6 条全绿（日志 /tmp/probe-dir.log）
- [x] `git status --short` 只含本轮 8 个路径，`pubspec.lock` 未被 pub get 改动

## 未满足项（不当作不适用）

- [ ] `claude -p` 只读复核 VERDICT 未取到（该通道近期持续 0 字节），属未经复核，以六道门禁 + 反向探针 + 合并试算替代。
- [ ] 左滑唤出的是同一张动作表，不是嘀嗒那种「行内露出三个按钮」的形态；文案与选项集合照抄，交互层级降了一格。
- [ ] 置顶状态经服务端回放到第二台设备这条链路只有单元级覆盖（落库分支读 `isPinned`），没有双端联调用例。

## 下一轮入口

矩阵 #19 行「用清单管理任务」的置顶面按本 PR 合并后的 SHA 回写（走 docs PR，判据器与被测文件同 ref）；
标签置顶（#329）等 service #318 合并后开工。
