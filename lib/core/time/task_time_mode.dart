/// 任务的时间模式，档位与措辞照抄嘀嗒《固定时间与固定时区》。
///
/// 取值与服务端 `todo_task.time_mode` 一致（zh-cloud-service #290 / PR !291）：
/// `0` 浮动、`1` 固定时区、`2` 固定时间。
enum TaskTimeMode {
  /// 两档都没选。服务端把它当"未表达显式意图"，展示算法与 [fixedTimezone] 一致。
  floating(0, null),

  /// 「固定时区」：锚绝对时刻，"任务的时间会随着所在时区的不同而改变"。
  fixedTimezone(1, '固定时区'),

  /// 「固定时间」：锚墙钟，"不论所处时区如何变化，任务的时间都会保持一致"。
  fixedTime(2, '固定时间');

  const TaskTimeMode(this.wire, this.label);

  /// 服务端 `time_mode` 的整型值。
  final int wire;

  /// 界面用词：只有 1/2 有（0 在界面上表现为"两个选项都没选中"）。
  final String? label;

  static TaskTimeMode fromWire(Object? value) {
    final raw = value is int ? value : int.tryParse('$value');
    return TaskTimeMode.values.firstWhere(
      (mode) => mode.wire == raw,
      orElse: () => TaskTimeMode.floating,
    );
  }

  /// 选了档位才需要锚点时区；未选（含从旧数据推出来的浮动）不需要。
  bool get requiresAnchorZone => this != TaskTimeMode.floating;

  /// 与旧的 `fixedTimezone` 布尔对齐：只有「固定时区」算 true。
  static bool legacyFlagOf(TaskTimeMode mode) => mode == TaskTimeMode.fixedTimezone;

  static TaskTimeMode fromLegacyFlag(bool fixedTimezone) =>
      fixedTimezone ? TaskTimeMode.fixedTimezone : TaskTimeMode.floating;
}
