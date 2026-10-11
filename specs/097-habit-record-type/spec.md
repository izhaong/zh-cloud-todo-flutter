# 097 — 习惯「打卡方式」三档客户端接线（FL #544，矩阵 #45 ①）

## 背景

嘀嗒《05-习惯打卡/02-更好地完成习惯.md》：打卡方式三档——自动记录（每次打卡算一次）、手动记录（打卡时可输入完成的量）、完成全部（当日有记录即完成），设置路径「编辑-目标-打卡时」。服务端契约已由 zh-cloud-service !347 落 develop（`record_type` + `amount`，service #308 关）。

## 契约

1. **编辑入口**：习惯编辑表单新增「打卡方式」三档 ChoiceChip（自动记录/手动记录/完成全部），新建缺省自动记录，编辑回显既有档位；create/update 请求体带 `recordType`。
2. **打卡流**：手动档点「打卡」先弹「本次完成量」输入（默认 1、@≥1 校验、非法给可见错误且不发请求），确认后 check-in 带 `amount`；自动/完成全部档直接打卡、请求体不带 `amount` 键。
3. **可读展示**：非自动档在列表行副标题带「· 手动记录 / · 完成全部」，自动档不加后缀。统计数字（总打卡/连续/本周）由服务端口径返回，客户端不改算法。

## 测试（8 条，`test/features/habit/habit_record_type_test.dart`）

8 条（复算：`grep -c 'testWidgets(\|^  test(' test/features/habit/habit_record_type_test.dart` ⇒ 8）。

- DTO 解析 recordType、缺省 1；checkIn amount 上送/自动档不带键（2 条单测）
- 新建默认自动、选手动后 create 带 recordType=2；编辑回显改档后 update 带 recordType=3
- 手动档弹完成量、输入 3 后 check-in 带 amount=3；非法 0 给「完成量至少为 1」且不发请求
- 自动档不弹层直接打卡；非自动档列表行可读展示

假服务用拦截器真记请求（CaptureServer），语义变异探针：把 `_checkIn` 的手动档分支拆掉 ⇒ 恰好「带 amount=3」「非法不发请求」两条红、自动档用例仍绿，已还原（`cmp -s` 字节一致）。

## 门禁

- `flutter analyze`：No issues found。
- 全量 `flutter test`：结果回填 tasks.md（后台跑）。

## 边界

- 月度打卡表的「补记」不支持完成量输入（补记语义是补一次在场记录，不属于本面）。
- 统计页数字随服务端 `aggregateByRecordType` 口径自动变化，客户端零改动；联调需 test 库先执行 service 仓 `sql/mysql/modules/todo-habit-record-type-2026-10-12.sql`（待批准）。
