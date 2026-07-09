import 'package:flutter/material.dart';

/// 顶层导航分区（对齐 TickTick 信息架构）。
///
/// - tasks: 任务（智能清单 + 列表 + 多视图）
/// - calendar: 日历
/// - habit: 习惯
/// - mine: 我的（设置 / 账户）
enum Section { tasks, calendar, habit, mine }

extension SectionX on Section {
  String get label {
    switch (this) {
      case Section.tasks:
        return '任务';
      case Section.calendar:
        return '日历';
      case Section.habit:
        return '习惯';
      case Section.mine:
        return '我的';
    }
  }

  IconData get icon {
    switch (this) {
      case Section.tasks:
        return Icons.check_circle_outline;
      case Section.calendar:
        return Icons.calendar_month_outlined;
      case Section.habit:
        return Icons.autorenew;
      case Section.mine:
        return Icons.person_outline;
    }
  }
}

/// 智能清单（Sidebar 内嵌）。
///
/// 选择后驱动任务页的过滤条件；[listId] 非空时等价于选中某清单。
enum SmartList { inbox, today, upcoming, all, completed, trash }

extension SmartListX on SmartList {
  String get label {
    switch (this) {
      case SmartList.inbox:
        return '收件箱';
      case SmartList.today:
        return '今天';
      case SmartList.upcoming:
        return '最近7天';
      case SmartList.all:
        return '全部';
      case SmartList.completed:
        return '已完成';
      case SmartList.trash:
        return '垃圾桶';
    }
  }

  IconData get icon {
    switch (this) {
      case SmartList.inbox:
        return Icons.inbox_outlined;
      case SmartList.today:
        return Icons.today_outlined;
      case SmartList.upcoming:
        return Icons.date_range;
      case SmartList.all:
        return Icons.select_all;
      case SmartList.completed:
        return Icons.check_circle_outline;
      case SmartList.trash:
        return Icons.delete_outline;
    }
  }
}
