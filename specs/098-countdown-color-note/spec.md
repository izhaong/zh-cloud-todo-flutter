# Spec 098：倒数纪念日「自定义颜色 + 备注」客户端接线

Refs: FL #546 · service #280（契约侧，已合并 svc `ac1f36d535`）· 矩阵 #49 ②⑤

## 背景

service #280 已把 `color varchar(16)` / `note text` / `note_show_in_detail bit(1)` 三列与
`/app-api/todo/countdown` create/update/list/get 契约暴露（svc `ac1f36d535`，矩阵 #49 追记）。
本轮把这组字段接到 Flutter 客户端：编辑器可挑颜色、写备注、开「在详情页中显示」，
卡片按开关把备注带出来、按颜色画左侧色条。

## 契约（与 svc develop@ac1f36d535 对齐）

| 字段 | 类型 | 客户端语义 |
| --- | --- | --- |
| `color` | `String?` | `#RRGGBB` 十六进制；`null`＝未设置；**显式清色送空串 `''`**（服务端 updateById 跳过 null，只有空串能清） |
| `note` | `String` | 始终送 String，`''` 清空备注 |
| `noteShowInDetail` | `bool` | 始终送（默认 false） |

- `CountdownApi.create/update`：body 增加 `'color': ?color`（null 缺省即不发）、`'note': ?note`、`'noteShowInDetail': noteShowInDetail`。
- `CountdownDto.fromJson`：`color`/`note` 可空读出，`noteShowInDetail == true` 才 true。

## UI

- 编辑器「显示已过天数」开关下方新增：颜色 8 色 ChoiceChip（含「默认」档，选中默认时送 `''`）→ 既有「切换图片」→ 备注多行输入框（key `countdown-note-field`）→「在详情页中显示」开关（key `countdown-note-show-in-detail`）。
- 卡片：左侧 4px 色条（key `countdown-color-strip-{id}`，仅当颜色可解析）；标题下方当 `noteShowInDetail && note 非空` 时展示备注行（key `countdown-note-{id}`）。本端暂无独立详情页（矩阵 #49 ④），卡片行即详情表面。
- `parseCountdownColor`：trim、去 `#`、6 位补 FF 前缀成 8 位 ARGB，非法/空 → null。

## 测试

`test/features/countdown/countdown_color_note_test.dart`（5 条，全绿）：
DTO 缺省解析；编辑器 create 三键齐进 body；编辑回显（旧备注/旧颜色回填、开关读出）；「默认」清色送 `''`；卡片色条颜色与备注按开关显隐。

既有契约钉：`test/countdown_manage_contract_test.dart` update body 精确钉补 `'noteShowInDetail': false`（color/note 走 null-aware 不发）。

## 门禁（本工作树 develop@691ba9a + 本轮改动）

- `flutter analyze`：No issues found（2.1s）。
- `flutter test`（全量）：见 tasks.md 记录。
- 变异探针：去掉 create/update body 三键 + 色条/备注显隐条件置恒假 ⇒ `countdown_color_note_test.dart` 1 过 4 挂（DTO 解析条不受影响，符合预期），还原后全绿。

## 范围裁定

- 嘀嗒备注入口在独立详情页（「点击左下角的『备注』按钮」）；本端无详情页，故备注编辑放编辑器、展示放卡片行，形态差异记矩阵判定而非在本轮造新页面。
- 颜色档位 8 色为嘀嗒取色面板近似子集，矩阵判定按「有配置色 + 可清回默认」的功能面记，不逐色对表。
