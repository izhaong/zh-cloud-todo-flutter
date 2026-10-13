/// 任务行"滑动露出动作"的动作集合与默认档位。
///
/// 判据源：嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》
/// - `:66`「将任务向左短滑，可以看到任务右侧出现了三个选项，它们分别代表：
///   「移动任务」、「删除任务」、「修改日期」，根据需要点击对应的选项进行操作。」
/// - `:71`「向右滑动分别为「完成」、「置顶」。」
/// - `:75`「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置。」
///
/// ⇒ 默认档位就是原文那两句给的集合；`:75` 允许用户改，所以档位是**可配置的数据**，
///   不是散落在行组件里的 if。
enum TaskSwipeAction {
  complete('complete', '完成'),
  pin('pin', '置顶'),
  moveTo('move', '移动任务'),
  delete('delete', '删除任务'),
  changeDueDate('dueDate', '修改日期');

  const TaskSwipeAction(this.wire, this.label);

  /// 落库/出箱用的稳定名。**不与界面文案混用**：文案可以改口径，存储的键不能漂，
  /// 否则第二台设备读不到同一档（`WeekStart` 那面踩过的同类账）。
  final String wire;
  final String label;

  static TaskSwipeAction? fromWire(Object? raw) {
    if (raw is! String) return null;
    for (final action in TaskSwipeAction.values) {
      if (action.wire == raw) return action;
    }
    return null;
  }
}

/// 一次滑动的配置：左右各一组动作，顺序即界面上从左到右（或从右到左）的按钮顺序。
class TaskSwipePreferences {
  const TaskSwipePreferences({
    required this.swipeLeft,
    required this.swipeRight,
  });

  /// 原文 `:66`/`:71` 给的两组，就是没配过任何东西时的默认值。
  static const TaskSwipePreferences defaults = TaskSwipePreferences(
    swipeLeft: [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ],
    swipeRight: [TaskSwipeAction.complete, TaskSwipeAction.pin],
  );

  /// 一侧最多露出三个：`:66` 写的是"三个选项"，多于三个时按钮会挤成不可点的小块
  /// （窄屏 320px 那一档实测每个动作只剩 ~53px，再挤就没法用指尖命中）。
  static const int maxActionsPerSide = 3;

  /// 手指**向左**拖（嘀嗒原文「将任务向左短滑」）时露出的动作，位于行的**右**边。
  final List<TaskSwipeAction> swipeLeft;

  /// 手指**向右**拖（原文「向右滑动」）时露出的动作，位于行的**左边**。
  final List<TaskSwipeAction> swipeRight;

  bool get isValid {
    return _sideIsValid(swipeLeft) && _sideIsValid(swipeRight);
  }

  /// 只换一侧，另一侧原样带走：配置页每次勾选都只动一侧。
  TaskSwipePreferences withSwipeLeft(List<TaskSwipeAction> actions) =>
      TaskSwipePreferences(swipeLeft: actions, swipeRight: swipeRight);

  TaskSwipePreferences withSwipeRight(List<TaskSwipeAction> actions) =>
      TaskSwipePreferences(swipeLeft: swipeLeft, swipeRight: actions);

  static bool _sideIsValid(List<TaskSwipeAction> actions) {
    if (actions.length > maxActionsPerSide) return false;
    return actions.toSet().length == actions.length;
  }

  Map<String, Object> toJson() => {
    'swipeLeft': [for (final action in swipeLeft) action.wire],
    'swipeRight': [for (final action in swipeRight) action.wire],
  };

  /// 读一份配置。**任何读不懂的地方都退回默认值而不是抛错**：
  /// 这份值可能被另一台设备/旧版本写进来，崩在这里会让设置页打不开。
  /// 缺哪一侧就只退那一侧的默认档（一侧写歪了不该把另一侧也清空）。
  static TaskSwipePreferences fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    return TaskSwipePreferences(
      swipeLeft: _readSide(raw['swipeLeft'], defaults.swipeLeft),
      swipeRight: _readSide(raw['swipeRight'], defaults.swipeRight),
    );
  }

  /// `value` 不是列表（键缺失或类型歪了）走 `fallback`；是列表但全认不出来的，
  /// 按"这一侧不露动作"处理 —— 那是配置页能明确造出来的形状，不该静默变回默认档。
  static List<TaskSwipeAction> _readSide(
    Object? value,
    List<TaskSwipeAction> fallback,
  ) {
    if (value is! List) return fallback;
    final actions = <TaskSwipeAction>[];
    for (final entry in value) {
      final action = TaskSwipeAction.fromWire(entry);
      if (action == null) continue;
      if (actions.contains(action)) continue;
      if (actions.length >= maxActionsPerSide) break;
      actions.add(action);
    }
    return List<TaskSwipeAction>.unmodifiable(actions);
  }

  /// 按内容相等：档位是"两份配置是不是同一份"这种要反复比较的值，
  /// 界面上"配置没变就别重建这一行"也靠它。
  @override
  bool operator ==(Object other) {
    if (other is! TaskSwipePreferences) return false;
    return _sameList(swipeLeft, other.swipeLeft) &&
        _sameList(swipeRight, other.swipeRight);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(swipeLeft), Object.hashAll(swipeRight));

  static bool _sameList(List<TaskSwipeAction> a, List<TaskSwipeAction> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
