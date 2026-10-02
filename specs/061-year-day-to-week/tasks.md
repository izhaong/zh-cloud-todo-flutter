# 061 — 任务与验收台账

判据源与范围见 `spec.md`，落点与决定见 `plan.md`。本台账里的每个读数都是本轮
现跑得到的，命令写在同一行，可复跑核对。

## 任务

| 编号 | 做什么 | 状态 | 证据（本轮现跑） |
| ---- | ------ | ---- | ---------------- |
| T1 | 先写红测：日格不可点、没有「已选中」节点 | 完成 | `flutter test test/features/task/calendar_year_day_to_week_test.dart` 在只接好 `onDayTap` 形参、未加 `InkWell` 的字节上得 `rc=1`、`+0 -4`，失败断言为 `Found 1 widget with key [<'calendar-year-day-2026-03-05'>]` 与 `Found 0 widgets with key [<'calendar-week-selected-day'>]`（日志 `/tmp/386-red.log`） |
| T2 | 最小实现：日格包 `InkWell`、状态记 `_yearSelectedDay`、周视图列头换成 `_WeekDayHeader` | 完成 | 同一命令复跑得 `rc=0`、`+4: All tests passed!`（日志 `/tmp/386-green.log`） |
| T3 | 四件套覆盖：320px 与 1.3 倍字号、独立读屏语义、失败保留已加载数据、过期响应不覆盖新响应 | 完成 | `grep -c "testWidgets(" test/features/task/calendar_year_day_to_week_test.dart` 现读 4；窄视口那条为 `surface: const Size(320, 700)` 与 `textScale: 1.3`；读屏那条断言 `flagsCollection.isSelected` 等于 `Tristate.isTrue`；失败保留那条用会抛的 `_ThrowingRepository` |
| T4 | 六道门禁跑在最终字节上 | 完成 | 见下「门禁」表，六行 `rc` 现读均为 0 |
| T5 | 台账过仓内自扫判据 | 完成 | `python3 tool/check_spec_selfscan.py specs/061-year-day-to-week/tasks.md` 见下「自扫」行 |
| T6 | 只读复核 VERDICT | 未完成 | 本轮未取到结论；`claude -p` 通道在本机排队（上一轮 0 字节输出）。合并前置条件缺这一条，按规矩不合并、矩阵不翻状态 |

## 门禁

| 门 | 命令 | 读数 |
| -- | ---- | ---- |
| 1 | `git diff --check` | `rc=0`，输出 0 字节 |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/task/views/calendar_view.dart test/features/task/calendar_year_day_to_week_test.dart` | `rc=0`，`Formatted 2 files (0 changed)` |
| 3 | `flutter analyze` | `rc=0`，`No issues found!` |
| 4 | `flutter test --tags golden` | `rc=0`，`+9: All tests passed!`，9 张基线未重录 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `rc=0`，`+1318 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `rc=0`，`✓ Built build/web` |

## 自扫

```bash
python3 tool/check_spec_selfscan.py specs/061-year-day-to-week/tasks.md
```

```text
specs/061-year-day-to-week/spec.md: 失项 0 条（仓库根按 wt-fl-386 解析）
specs/061-year-day-to-week/plan.md: 失项 0 条（仓库根按 wt-fl-386 解析）
specs/061-year-day-to-week/tasks.md: 失项 0 条（仓库根按 wt-fl-386 解析）
```

## 与矩阵的关系

矩阵 `dida-parity-matrix.md` 第 28 行本轮不翻状态：本 PR 未合并，按「矩阵翻转只引
已合并 SHA」的口径，只能在 docs 侧追加「已实现待合并」注。
