# 146 台账

## T1 现读订正

- [x] `.when(` 现读 17 处（2 处是注释）⇒ 真实 15 处；批次 1 已合并（`4b71d21a`）。
- [x] `cal_subscription_page` provider 自 catch 成 data（`:19-32`）⇒ 那条 error 分支不可达，排除。
- [x] 新出现且原单未点名的两处（`habit_journal:147`、`tasks_by_list_page:3243`）本切片不碰。

## T2 改动

- [x] 4 处各加 `skipError: true` + `AppRefreshFailedHint`（`if (x.hasError && x.hasValue)`）。
- [x] 用脚本按锚点套壳（避免手抄 4 遍渲染块），随后 `dart format` 归位缩进。

## T3 判据

- [x] `test/features/keep_loaded_on_failure_pages_test.dart` 2 条（SavedFiltersPage / TagPage）。
- [x] 反向探针：删 `skipError: true` ⇒ **两条各自红**（已跑）。
- [x] 既有回归 `+27` 全过。

## 过程教训

1. **先用框架开关，别急着抽方法**：初版我把 `saved_filters_page` 的渲染块抽成 `_list()`
   再三分支（+42 行）。改用 Riverpod 的 `skipError: true` 后语义逐字相同、diff 只剩
   一行 + 提示条。**框架已经为「有旧值的失败」设计了开关，先找它。**
2. **`pumpAndSettle` 会在加载态超时**：加载态是 `CircularProgressIndicator`（无限动画），
   流还没发值时 `pumpAndSettle` 永远不 settle ⇒ 判据必须用 `pump()`。这是写流驱动用例
   的固定坑，已在测试注释里写明。
3. **判据要「先证有数据」再推失败**：否则断言「数据还在」在「数据从来没渲染出来」时
   也会绿（恒真）。测试里第一条断言就是为这个。
4. **原单的分类会过期**：批次 1 已合并、两处新增、一处机制不同（cal_sub）。**先现读再动手**，
   别照抄行号。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 新增判据 | `+2 All tests passed!` |
| 反向探针 | 两条红 |
| 既有回归（saved_filters/tag_page/folder_disband） | `+27 All tests passed!` |
| `flutter analyze` | `No issues found!` |
| `dart format --set-exit-if-changed lib test` | `rc=0` |
| 全量（exclude golden/performance） | `+2095 ~26`，**0 失败** |
