# Tasks 098：倒数纪念日「颜色 + 备注」客户端接线

- [x] T1 `CountdownDto` + `CountdownApi.create/update` 增 color/note/noteShowInDetail（`lib/core/api/efficiency_api.dart`）
- [x] T2 编辑器：8 色 ChoiceChip（含默认档）+ 备注输入框 + 「在详情页中显示」开关（`lib/features/countdown/countdown_page.dart`）
- [x] T3 卡片：左侧色条 + 按开关展示备注行
- [x] T4 新用例 `test/features/countdown/countdown_color_note_test.dart`（5 条全绿）
- [x] T5 既有 fake create/update 签名补参（invalid_override 修复）；契约钉补 `'noteShowInDetail': false`
- [x] T6 变异探针：删 body 三键 + 显隐条件恒假 ⇒ 1 过 4 挂；还原后全绿
- [x] T7 `flutter analyze` No issues found
- [x] T8 全量 `flutter test`：`00:56 +1131: All tests passed!`（1131 过 0 挂，2026-10-12 本工作树）
