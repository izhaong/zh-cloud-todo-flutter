/// 嘀嗒《01-欢迎/03-常见问题.md:134》「星期开始于」：
/// 可选「周日」「周一」「周六」三档，默认「周一」（= 本仓改造前 `subtract(Duration(days: weekday - 1))`
/// 的既有行为，也是 9 张黄金基线不重录的前提）。
class WeekStart {
  const WeekStart._();

  static const int defaultFirstDay = DateTime.monday;

  /// 嘀嗒只给这三档，界面上也不许出现第四档。
  static const List<int> allowedFirstDays = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.saturday,
  ];

  static const Map<int, String> _labels = {
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };

  static String labelOf(int firstDay) => _labels[firstDay] ?? '周一';

  /// 该星期几距周首要往回退几天（0..6），永不为负。
  static int offsetOf(int weekday, {int firstDay = defaultFirstDay}) =>
      (weekday - firstDay + 7) % 7;

  /// [day] 所在周的第一天（时分秒抹平，否则时间线按周分桶会漏掉当天晚些时候的任务）。
  static DateTime startOf(DateTime day, {int firstDay = defaultFirstDay}) {
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: offsetOf(day.weekday, firstDay: firstDay)));
  }

  /// 表格从左到右各列对应的 ISO 星期序号（1=周一 … 7=周日）。
  static List<int> columnOrder({int firstDay = defaultFirstDay}) {
    return List<int>.generate(7, (index) => (firstDay - 1 + index) % 7 + 1);
  }
}
