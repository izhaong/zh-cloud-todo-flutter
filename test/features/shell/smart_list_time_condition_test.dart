import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/smart_list_time_condition.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》`:61`「拖动到智能清单上」
/// `:63`「会为任务自动添加该智能清单关联的时间条件，例如“今天”、“本周”等。」
///
/// 这一档的落点日不是新造的规则，而是**本端那一档智能清单自己在用的日期窗口**
/// （谓词：`tasks_by_list_page.dart` 的 `_dateConditionMatches`，经 `applyTaskFilter` 走公开入口）。
/// 所以下面最重要的用例是「逐日对账」：窗口说满足 ⇔ 谓词说满足，两边一旦漂移，
/// 就会出现「拖上去却不在清单里」或「清单里的任务被落点判成已满足」。
TodoTask _taskDueAt(DateTime due) => TodoTask(
  id: 'task-due',
  serverId: null,
  listId: 'list-1',
  allDay: false,
  fixedTimezone: false,
  timeMode: 0,
  title: '对账任务',
  completed: false,
  cancelled: false,
  priority: 0,
  isPinned: false,
  sortOrder: 0,
  dueAt: due,
  updatedAt: DateTime(2026, 10, 1, 8),
  createdAt: DateTime(2026, 10, 1, 8),
);

/// 谓词侧的真实判定：把这条任务丢进那一档智能清单的过滤条件里，看留不留得下。
bool _matchesSmartListFilter(String dueRange, DateTime due, DateTime now) =>
    applyTaskFilter(
      <TodoTask>[_taskDueAt(due)],
      TaskFilter(dueRange: dueRange),
      null,
      now,
    ).isNotEmpty;

const _timedSmartLists = <SmartList>[
  SmartList.today,
  SmartList.tomorrow,
  SmartList.upcoming,
];

void main() {
  // 非整点、且离两侧边界都远，避免「测试自己的时钟」参与判定。
  final now = DateTime(2026, 10, 12, 14, 5);
  final startOfDay = DateTime(2026, 10, 12);

  group('智能清单的时间条件窗口', () {
    test('只有带日期窗口的三档有条件，其余五档为 null', () {
      for (final smart in SmartList.values) {
        final condition = smartListTimeConditionOf(smart, now);
        if (_timedSmartLists.contains(smart)) {
          expect(condition, isNotNull, reason: '$smart 该有落点条件');
        } else {
          expect(condition, isNull, reason: '$smart 没有「关联的时间条件」这句话可落成的语义');
        }
      }
      // 正向对照：三档确实各有条件，不是整表都 null。
      expect(
        SmartList.values.where((s) => smartListTimeConditionOf(s, now) != null),
        hasLength(3),
      );
    });

    test('三档的落点日都落在自己的窗口里', () {
      for (final smart in _timedSmartLists) {
        final condition = smartListTimeConditionOf(smart, now)!;
        expect(
          condition.targetDaySatisfies,
          isTrue,
          reason: '${smart.name} 落完必须让任务出现在这一档里',
        );
        expect(
          _matchesSmartListFilter(condition.dueRange, condition.targetDay, now),
          isTrue,
          reason: '${smart.name} 的落点日谓词侧也必须认',
        );
      }
    });

    test('逐日对账：窗口判定与任务页过滤谓词在 -10..+12 天上一致', () {
      for (final smart in _timedSmartLists) {
        final condition = smartListTimeConditionOf(smart, now)!;
        for (var offset = -10; offset <= 12; offset++) {
          final day = startOfDay.add(Duration(days: offset));
          // 带时刻，且两侧都用同一个墙钟时刻：只用 00:00 会把
          // 「上界含不含端点」这件事量不出来。
          final dueOnDay = DateTime(day.year, day.month, day.day, 9, 30);
          expect(
            condition.satisfiedBy(dueOnDay),
            _matchesSmartListFilter(condition.dueRange, dueOnDay, now),
            reason: '${condition.dueRange} 在 $dueOnDay 两侧判定漂移',
          );
        }
      }
    });

    test('窗口边界：今天不含明天 00:00；最近七天不含今天、含第 7 天、不含第 8 天', () {
      final today = smartListTimeConditionOf(SmartList.today, now)!;
      expect(today.fromInclusive, startOfDay);
      expect(today.toExclusive, startOfDay.add(const Duration(days: 1)));
      expect(
        today.satisfiedBy(
          startOfDay.add(const Duration(hours: 23, minutes: 59)),
        ),
        isTrue,
      );
      expect(
        today.satisfiedBy(startOfDay.add(const Duration(days: 1))),
        isFalse,
        reason: '明天 00:00 不属于「今天」',
      );

      final tomorrow = smartListTimeConditionOf(SmartList.tomorrow, now)!;
      expect(tomorrow.targetDay, startOfDay.add(const Duration(days: 1)));
      expect(
        tomorrow.satisfiedBy(startOfDay.add(const Duration(days: 1, hours: 6))),
        isTrue,
      );
      expect(tomorrow.satisfiedBy(startOfDay), isFalse);

      final upcoming = smartListTimeConditionOf(SmartList.upcoming, now)!;
      // 本端「最近七天」= 明天起 7 天：下界今天结束、上界今天+8 天。
      expect(upcoming.fromInclusive, startOfDay.add(const Duration(days: 1)));
      expect(upcoming.toExclusive, startOfDay.add(const Duration(days: 8)));
      expect(
        upcoming.satisfiedBy(startOfDay.add(const Duration(hours: 9))),
        isFalse,
        reason: '今天不在这档窗口里 ⇒ 今天 overdue 的任务拖到「最近七天」要挪到明天',
      );
      expect(
        upcoming.satisfiedBy(
          startOfDay.add(const Duration(days: 7, hours: 23)),
        ),
        isTrue,
      );
      expect(
        upcoming.satisfiedBy(startOfDay.add(const Duration(days: 8))),
        isFalse,
      );
    });

    test('无日期任务不满足任何一档（所以一定是有效落点）', () {
      for (final smart in _timedSmartLists) {
        expect(
          smartListTimeConditionOf(smart, now)!.satisfiedBy(null),
          isFalse,
          reason: '$smart：无日期 = 还没有这一档的时间条件',
        );
      }
    });
  });
}
