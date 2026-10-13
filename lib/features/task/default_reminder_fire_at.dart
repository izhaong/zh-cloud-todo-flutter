/// 「默认提醒」档的换算（specs/105，矩阵 #9 面 ⑥）。
///
/// 判据源《02-功能指南/01-任务/04-超强大的提醒功能.md》:33——
/// 「在『设置』-『更多设置』-『任务默认值』-『默认提醒』中选择常用的提醒，
/// 将它设置为默认提醒」。单条快速添加（`TaskQuickAddSheet._save`）与
/// 多行批量（`attachResolvedReminders`）两条路径共用本函数，
/// 保证同一档位在两条入口换算出的提醒时刻一致。
///
/// 返回 null 表示「这条不用建」：默认提醒档把时刻推到了过去（<= [now]）。
/// 给过期时刻建提醒只会立刻响一次，不是用户设默认值想要的；任务本身照建。
DateTime? reminderFireAtFor(
  DateTime dueAt, {
  required int? defaultReminderMinutes,
  required DateTime now,
}) {
  final minutes = defaultReminderMinutes;
  if (minutes == null || minutes <= 0) return dueAt;
  final fireAt = dueAt.subtract(Duration(minutes: minutes));
  if (!fireAt.isAfter(now)) return null;
  return fireAt;
}
