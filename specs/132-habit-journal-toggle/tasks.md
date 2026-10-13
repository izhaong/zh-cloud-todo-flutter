# 132 台账（客户端半）

## T1 HabitDto

- `journalEnabled` 字段（ctor 缺省 true；fromJson 无键 != false —— 读侧
  兼容存量行/旧数据）。

## T2 仓储

- `create/update/_habitBody` 透传 `journalEnabled`（默认 true）。

## T3 编辑器

- 底部「打卡日志」SwitchListTile（key `habit-editor-journal-toggle`，
  默认开、可关）；create/update 透传 `_journalEnabled`。

## T4 用例（test/features/habit/habit_journal_toggle_test.dart，3 条）

- DTO 2：旧数据无键按开启 / ctor 缺省 true。
- 编辑器 1：开关存在、默认开、可关（状态交互；落库由服务端契约测试覆盖）。

## 存量用例适配（specs/132 表单加高的一揽子连锁）

- 编辑器表单加高 ⇒ 保存键在 320x720 视口外：
  - habit_record_type_test 两条：视口抬到 320x900。
  - habit_detail_page_test 视口 320x900→1100；4 处 inSurface 保存 tap 前
    加 scrollUntilVisible（scrollable 取 inSurface 内 first，避免
    「Too many elements」——弹层内有嵌套滚动）；pumpNewHabitSheet 流程
    两条 sheetChild 保存 tap 同样加滚动。
- body pinned map 补 `journalEnabled: true`：detail_page_test create pin
  （FR-5）/update pin（逐键断言）/repo pin（`'sortOrder': 3` 那张是
  HABIT 行 fixture 非请求体，不动）。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +3（客户端） |
| 全量 | `+2033 ~26 -1`（habit/contract 全目录连跑全绿；唯一红 #569 存量） |

## 存量 body pin 追加（第三处）

- `efficiency_api_contract_test.dart` 的 /habit/create 请求体 pin 同样补
  `journalEnabled: true`（specs/132 的连锁第三处；前两处为
  habit_detail_page_test 的 create/update pin）。
