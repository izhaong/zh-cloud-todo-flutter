/// M11-B3 任务视图模式枚举。
///
/// TasksByListPage 顶部 tab 在 5 个模式间切换；列表分支沿用 M11-B2 行为，
/// 其它 4 模式由 `lib/features/task/views/` 下对应 widget 渲染。
enum TaskViewMode { list, kanban, timeline, eisenhower, calendar }

extension TaskViewModeX on TaskViewMode {
  String get label {
    switch (this) {
      case TaskViewMode.list:
        return '列表';
      case TaskViewMode.kanban:
        return '看板';
      case TaskViewMode.timeline:
        return '时间线';
      case TaskViewMode.eisenhower:
        return '四象限';
      case TaskViewMode.calendar:
        return '日历';
    }
  }

  String get shortLabel {
    switch (this) {
      case TaskViewMode.list:
        return '列表';
      case TaskViewMode.kanban:
        return '看板';
      case TaskViewMode.timeline:
        return '时间';
      case TaskViewMode.eisenhower:
        return '象限';
      case TaskViewMode.calendar:
        return '日历';
    }
  }
}
