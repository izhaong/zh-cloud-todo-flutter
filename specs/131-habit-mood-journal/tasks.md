# 131 台账

## T1 服务端（zh-cloud-service !359，已合并）

- `AppTodoHabitCheckInListRespVO`（id/checkedAt/note/amount，无 requiredMode
  照既有 VO 风格）。
- `TodoHabitService.getCheckInJournal(userId, habitId, limit)` +
  impl（requireOwned 校验、90 天窗口倒序、limit 裁剪）。
- `AppTodoHabitController` `GET /check-in/list`（CommonResult.success 显式
  写法照同文件先例；不新增 PreAuthenticated 注释——app-api 默认鉴权）。
- 测试 3 条（倒序+limit / 越权 / note 透传）；todo 模块 522 全绿。

## T2 客户端仓储

- `checkIn(habitId, {date, amount, note})` 加 note 形参。
- `listCheckIns(habitId, {limit})` 调新端点。
- `HabitCheckInEntry`（fromJson epoch 毫秒 / moodAndJournal 拆分约定：
  (String?, String?)? —— 空 note null、纯 emoji journal null、无 emoji
  mood null）。

## T3 客户端 UI

- `habit_journal.dart`（新文件）：`showHabitCheckInSheet`（心情五档
  IconButton 单选再点取消、日志 TextField、保存拼 note、失败可见提示）
  + `HabitJournalSection`（时间轴：MM-dd HH:mm / 心情 / 正文）。
- `habit_detail_page.dart`：FAB「打卡」→ 弹层（成功 invalidate journal）；
  body 追加 `HabitJournalSection`。
- `habit_page.dart`：列表行一键打卡**保持直达**（specs/097 打卡方式档
  既有行为；habit_record_type_test 钉死自动档不弹层）——弹层只在详情页。

## T4 用例（test/features/habit/habit_journal_test.dart，8 条）

- 拆分约定 5：emoji+journal / 纯 emoji / 无 emoji / 空 note / fromJson。
- widget 2：弹层交互可达（五档按钮 + 输入框）/ 关闭不落库。
- 时间轴 2：条目渲染日期/心情/正文 / 空整段不渲染。

## 过程教训

- python 行级多块编辑在长文件上反复失败（缩进/三引号冲突），多次
  整文件重写——大改动应直接整文件重写或用脚本文件。
- epoch 测试数据 1784086800000 = 2026-07-14 23:40（UTC+8 边界），构造
  note 断言时注意时区。
- habit_record_type_test 钉死自动档不弹层：新弹层入口只挂详情页，
  列表行直达是既有验收（顺延不破坏）。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | 客户端 +8 / 服务端 +3 |
| 全量 | 待回填 |
