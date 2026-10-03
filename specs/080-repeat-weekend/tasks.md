# 任务清单：「每周末」档客户端接线

基准：分支 feat/323-weekend-repeat，起点 `origin/develop` 的 `0ddeca851042f49e74de2f390a478dd9cb925152`。

## 实现（三处同轮）

- [x] 频率白名单加 WEEKEND：`lib/state/repositories/repeat_rule_repository.dart` 的 `const frequencies`
- [x] 星期派生加「WEEKEND 命中周六与周日」：同文件的 `_normalizeWeekdays` 分支，与既有 WEEKDAY 分支相邻
- [x] 档位表加「每周末」：`lib/features/task/task_detail_pane.dart` 的频率 `const` 列表（键 `task-repeat-frequency-weekend`）
- [x] 读回文案表加「WEEKEND 对应每周末」：同文件 `_repeatRuleLabel` 的 labels
- [x] 新增用例文件 `test/features/task/task_repeat_weekend_test.dart`（不追加进既有文件，避开与并行会话撞同文件）

## 门禁（最终字节各跑一次，日志留档）

- [x] `git diff --check` rc=0
- [x] `dart format --output=none --set-exit-if-changed` 本轮三个显式文件 rc=0（未做全仓原地格式化）
- [x] `flutter analyze` rc=0，读数 `No issues found!`（日志 /tmp/g3c.log）
- [x] `flutter test --tags golden` rc=0，读数 `+9: All tests passed!`（基线 9 张未重录，日志 /tmp/g4b.log）
- [x] `flutter test --exclude-tags 'golden || performance' --concurrency=1` rc=0，
      读数 `+1375 ~26: All tests passed!`（日志 /tmp/g5-full.log）
- [x] `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` rc=0，
      读数 `✓ Built build/web`（日志 /tmp/g6-build.log）
- [x] 反向探针：删掉档位表里「每周末」那一行 ⇒ 新用例红在写明的判据上（`Found 0 widgets with key [<'task-repeat-frequency-weekend'>]`），
      还原后 `cmp -s` 证字节一致（日志 /tmp/fl-204-b.log）
- [x] `git status --short` 只含本轮三个文件，`pubspec.lock` 未被 pub get 改动

## 未满足项

- [ ] `claude -p` 只读复核 VERDICT 未取到（该通道近期持续 0 字节），以六道门禁 + 反向探针 + 合并试算替代，属未复核。
- [ ] 星期派生 `[6, 7]` 这一处没有单独用例断言（现有用例只量到 freq 与 payload 的 frequency），
      服务端会以 `weekdays` 为 6,7 自行派生，本地派生值留待下一轮补断言。

## 下一轮入口

矩阵 `zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 的 #24 行按本 PR 与服务端 !317 的**已合并** SHA 回写；
本轮不翻矩阵。
