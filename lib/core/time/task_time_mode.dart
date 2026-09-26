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

  /// 旧位是"勾过某一档固定"的派生读值：两档固定都算 true。
  /// 否则存量 `fixed_timezone=true` 的行（行为是保留墙钟）会突然被老客户端当浮动显示。
  static bool legacyFlagOf(TaskTimeMode mode) => mode != TaskTimeMode.floating;

  /// 存量 true 回填成「固定时间」而不是字面更像的「固定时区」：
  /// develop 上这一档的实际行为就是"按配置时区保留墙上钟点"（17 条既有测试钉的全是它），
  /// 名字挂错了不等于用户当初要的是另一件事 —— 改名修名实，翻行为会改用户已设的显示钟点。
  static TaskTimeMode fromLegacyFlag(bool fixedTimezone) =>
      fixedTimezone ? TaskTimeMode.fixedTime : TaskTimeMode.floating;
}
