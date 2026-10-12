# 037 实施计划

## 落点

| 文件 | 动作 | 说明 |
| --- | --- | --- |
| `lib/features/habit/habit_repository.dart` | 改 | `HabitDto` 补 `icon`/`reminderAt`/`sortOrder`；新增 `update` / `delete`；`create` 补齐可编辑字段 |
| `lib/features/habit/habit_editor.dart` | 新 | 嘀嗒「自定义习惯 / 编辑习惯」同一张表单，新建与编辑共用（FR-5 要求新建也带全字段，共用可避免两份表单漂移） |
| `lib/features/habit/habit_detail_page.dart` | 新 | 详情页 = 「...」菜单宿主（FR-1、FR-2） |
| `lib/features/habit/habit_page.dart` | 改 | 卡片可点进详情页；AppBar 的「+」改调共用编辑器 |
| `test/features/habit/habit_detail_page_test.dart` | 新 | 本单全部断言 |

不动 `test/visual/todo_workspace_golden_test.dart`；不动 `lib/state/efficiency_providers.dart` 之外的 provider。

## 契约映射（逐字段，来自 `zh-cloud-service@origin/develop 48f1e4db60`）

| UI | 请求 | 备注 |
| --- | --- | --- |
| 名称 | `name` | 必填，trim 后为空则不提交 |
| 图标 | `icon` | `AppTodoHabitBaseVO:19` |
| 颜色 | `color` | `:22`，存 `#RRGGBB` |
| 频率 | `period` | `:25`，1=每天 2=每周 3=每月（照 VO 的 `example`，不发明第四档） |
| 目标 | `targetCount` | `:28` |
| 提示 | `reminderAt` | `:30`，服务端全局 `LocalDateTime <-> epoch 毫秒`（见 spec FR-6）；`checkIn` 的 `checkedAt` 同形状 |
| 编辑提交 | `PUT /app-api/todo/habit/update` | body 必带 `id`（`AppTodoHabitUpdateReqVO:11`） |
| 删除 | `DELETE /app-api/todo/habit/delete?id=` | `AppTodoHabitController:50` |

`sortOrder` 属契约有、UI 无（嘀嗒的排序是长按拖动，本单不做拖拽）⇒ 编辑时**原值回传**，不丢。

## 反向探针（在最终字节上跑，恢复后 `cmp` 证明逐字节一致）

脚本 `/tmp/r21_probes.py`，日志 `/tmp/r21_probes_final.log`。判据：**摘掉那段生产代码必须看到对应用例红**。

| 探针 | 摘掉什么 | 结果 |
| --- | --- | --- |
| PA | `_HabitTile` 的 `onTap` → `null` | 红（点不进详情，连带 8 条依赖详情页的用例全红） |
| PB | 菜单里的「编辑」`PopupMenuItem` | 红（T2 + 5 条走编辑入口的用例） |
| PC | update body 的 `id` 改名 `idx` | 红（repo body 用例 + 编辑用例） |
| PD | 编辑初值 `widget.habit?.name ?? ''` → `''` | 红（回填用例 + 在飞用例） |
| PE | `'reminderAt': reminderAt?.millis` → 恒 `null` | 红（未改动字段被发成 null） |
| PF | 删除的 `repo.delete(...)` 调用 | 红（DELETE 用例） |
| PG | 确认框的 `!confirmed` 早退 | 红（「取消不发写请求」用例） |
| PH | catch 里的 `_submitError = '保存失败：…'` | 红（失败可见用例） |
| **PI** | **只**摘按钮的 `loading: _saving` | **绿** |
| **PK** | **只**摘 `if (_saving) return;` | **绿** |
| PL | 两处**同时**摘 | 红（「只发一次 PUT」用例） |
| PJ | `checkedAt` 退回 ISO 字符串 | 红（wire 形状用例） |
| PM | 名称字段的 `errorText: _nameError` | 红（字段级错误用例） |
| PN | `_habitBody` 里的 `'icon': icon` | 红（含 FR-5 新建用例） |

PI / PK 单侧都绿 ⇒ 「保存在飞」这条用例覆盖的是**这一对守卫的协同**，不是其中某一行：
`loading` 管可感知（按钮点不动 + 转圈），早退守卫管正确性（键盘 Enter / 重建后的残留回调）。
按这个粒度记录，不把它写成「两行都有独立用例」。

## 六项门禁

见 tasks.md 末尾的原文记录位。基线：黄金 9 张不变；非 golden `713 passed / 26 skipped`（2026-09-23）。
