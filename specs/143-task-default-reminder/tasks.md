# 143 台账

## T1 模型（TaskCaptureDefaults.defaultReminderMinutes）

- 落点：`lib/state/repositories/task_capture_defaults_repository.dart`
- 判据：toJson 保留 null 键、fromJson 读回 null/数字两态、旧数据（无键）读 null。
- 用例：`TaskCaptureDefaults 默认提醒档` 三条（test/features/task/task_default_reminder_test.dart）。

## T2 设置页「默认提醒」下拉

- 落点：`lib/features/settings/settings_route.dart`（`_TaskCaptureDefaultsPage`）。
- 档位：不提醒(null)/准时(0)/5/15/30/60/120 分钟；副标题同步改三档。
- 用例：AC-1 两条（进页可选可存可回读）。

## T3 单条快速添加换算

- 落点：`TaskQuickAddSheet._save` → `reminderFireAtFor`（新文件
  `lib/features/task/default_reminder_fire_at.dart`）。
- 语义：null/0 ⇒ fireAt=识别时刻；>0 ⇒ fireAt=识别时刻−分钟数；
  结果 <= now ⇒ 不建提醒不报错，任务照建。
- 用例：widget 三条（提前 30 / null 现状锁 / 过去时刻跳过）。

## T4 批量路径换算

- 落点：`lib/features/task/quick_add_batch_reminders.dart`
  `attachResolvedReminders(defaultReminderMinutes:, now:)`；
  两个调用点接线：`home_shell.dart`、`tasks_by_list_page.dart`。
- 用例：批量两条（−15 分钟 / 过去时刻跳过不计失败）。

## T5 探针（各自红后还原，`cmp`/复跑验证）

- PA 换算方向反（subtract→add）⇒ 换算/批量/单条 4 条红。
- PB 跳过条件写反（`!isAfter`→`isAfter`）⇒ 4 条红（+9 -4）。
- PC toJson 丢 null 键 ⇒ 9 条红（含旧数据兼容那两条）。

## T6 门禁（TZ=Asia/Shanghai）

- `flutter analyze` ⇒ No issues found
- 新用例 13 条全绿
- 全量：见本文件末尾「最终门禁」表（跑完回填）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format --set-exit-if-changed（改动文件） | 0 changed |
| 新用例 | +13（4 探针各自红后还原） |
| 全量（TZ=Asia/Shanghai） | 待回填 |

> 最终门禁回填（2026-10-13，TZ=Asia/Shanghai）：全量 `+1935 ~26 -1`
> （基线 +1922 ~26 -1，差额即本切片 +13；唯一红仍是 #569 的 raw_error_text_gate 存量）。
