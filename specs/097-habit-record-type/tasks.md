# 097 tasks — 习惯「打卡方式」客户端接线（FL #544）

- [x] 仓储层：`HabitDto.recordType`（缺省 1）、`_habitBody`/`create`/`update` 带 `recordType`、`checkIn` 支持 `amount`（手动档）
- [x] 编辑表单：「打卡方式」三档 ChoiceChip + 回显 + create/update 穿线（`habit_editor.dart`）
- [x] 打卡流：手动档弹「本次完成量」弹层（默认 1、≥1 校验、非法不发请求），自动/完成全部档直通（`habit_page.dart`）
- [x] 列表行可读展示：非自动档副标题带「· 手动记录 / · 完成全部」
- [x] 测试 8 条 `test/features/habit/habit_record_type_test.dart`（复算：`grep -c 'testWidgets(\|^  test(' test/features/habit/habit_record_type_test.dart` ⇒ 8）
- [x] 红测先行（编译级缺符号红）+ 语义变异探针（拆手动档分支 ⇒ 恰 2 条红，还原 `cmp -s` 一致）
- [x] 既有 fake 签名修正：`habit_month_grid_test.dart` 的 `checkIn` override 补 `int? amount` 参数（invalid_override）
- [x] 既有契约钉更新：`efficiency_api_contract_test.dart`（create body）与 `habit_detail_page_test.dart`（FR-5 create body、update body）补 `'recordType': 1`——服务端契约 !347 后 create/update 恒带该键
- [x] `flutter analyze` = No issues found
- [x] 全量 `flutter test` 门禁：1626 通过 / 26 跳过 / 0 失败（复算：`flutter test` 摘要行 ⇒ `+1626 ~26`；首跑 3 失败为既有契约钉缺 recordType，补钉后全绿）
- [ ] 分支 feat/544-habit-record-type → push → PR → 合并 → 关 #544
- [ ] 矩阵 #45 ① 追记（docs worktree，校验器同 ref PASS）+ 父仓 bump
