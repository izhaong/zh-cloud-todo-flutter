# 042 任务清单

## 已证实
（待跑完测试与门禁后回填）

## 门禁（最终状态一次跑完，日志 `/tmp/r41_gates.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` |  |
| 2 `dart format --output=none --set-exit-if-changed lib/features/countdown/countdown_page.dart test/features/countdown/countdown_unit_toggle_test.dart` |  |
| 3 `flutter analyze` |  |
| 4 `flutter test --tags golden` |  |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` |  |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` |  |

## 复核
`claude` CLI 本机不可用（`unrecognized_model`），按 objective 的替代口径：由本会话**只读子代理**审 FR-001..FR-006，
必须拿到 `VERDICT`。结论与不采纳理由记在本文件。

## 仍缺（不谎称完成）
- [ ] 嘀嗒移动端那一档《02-打造专属纪念页.md:97》要求「**点进详情页**、点中间的天数」—— 本端没有倒数纪念日详情页，
      本轮按桌面那一档（`:106`「点击倒数纪念日卡片上的天数」）落在列表行上，详情页本身仍是缺口。
- [ ] 读屏 `isButton` 标志位未断言：本机 SDK 的 `SemanticsNode` 没有 `flags` getter（实测编译错误
      `The getter 'flags' isn't defined for the type 'SemanticsNode'`），改用 `SemanticsNode.actions` 断言
      `SemanticsAction.tap`；生产代码里的 `Semantics(button: true)` 只是设了标志，没被断言。
- [ ] 真机（iOS/Android）上的点击目标尺寸未实测：本机只有 web 构建可用（`github.com` 超时 ⇒ SPM 编不了）。
- [ ] 矩阵 #49 其余四面（样式入口、颜色、图片、备注）未动，颜色与备注属服务端契约缺口。
- [ ] 矩阵第 49 行的状态回写：合并前只写「已实现待合并」，不得引 SHA。
