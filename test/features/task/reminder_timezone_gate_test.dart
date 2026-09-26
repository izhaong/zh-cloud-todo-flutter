import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/055（FL Issue #368）FR-2：「设置 → 日期与时间 → 时区」关掉后，
/// 任务提醒编辑器里的「固定时区」这一档不出现，但 IANA 输入框必须还在。
///
/// 判的是**显隐**，不是数据：R2（settings 那份）已经判过"切开关不动
/// `todo_tasks.timeZone` / `fixedTimezone`"，这里只钉嘀嗒《01-任务/07-固定时间与固定时区》:11
/// 那条"开启后才能选"的入口形状。
const _taskId = TodoVisualFixture.pinnedTaskId;
const _fixedTimezoneRow = Key('task-reminder-fixed-timezone');
const _ianaField = Key('task-reminder-timezone');

void main() {
  testWidgets('开着时「固定时区」这一档在，标签按未固定态写「创建时区（IANA）」', (
    tester,
  ) async {
    await _pumpReminderEditor(tester, timezoneEnabled: true);

    expect(find.byKey(_fixedTimezoneRow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_ianaField),
        matching: find.text('创建时区（IANA）'),
      ),
      findsOneWidget,
      reason: '「固定时区」这一档没打开时，字段就该老实叫「创建时区」（嘀嗒措辞）',
    );
  });

  testWidgets('关掉时「固定时区」消失，但 IANA 输入框仍在（FR-2 后半）', (
    tester,
  ) async {
    await _pumpReminderEditor(tester, timezoneEnabled: false);

    expect(
      find.byKey(_fixedTimezoneRow),
      findsNothing,
      reason: '总开关关掉还露着这一档 = 设置页那条开关是摆设',
    );
    expect(
      find.byKey(_ianaField),
      findsOneWidget,
      reason: '嘀嗒的时区字段与"固定"是两回事：显隐只收「固定时区」，不许顺手收掉输入框',
    );
    expect(
      find.descendant(
        of: find.byKey(_ianaField),
        matching: find.text('创建时区（IANA）'),
      ),
      findsOneWidget,
      reason: '显隐判据不能只看 key 在不在，标签要是也变了说明改错了对象',
    );
  });
}

/// 复用 `task_time_semantics_test.dart` 已经跑通的提醒编辑器路径（同一 fixture、
/// 同一条 tap 链），只把 `timezoneEnabledProvider` 换成要判的那一档。
/// 真实"仓储 → 流 → provider"接线由 settings 那份的 W1 判，这里不重复判。
Future<void> _pumpReminderEditor(
  WidgetTester tester, {
  required bool timezoneEnabled,
}) async {
  final fixture = await TodoVisualFixture.create(
    overridesBuilder: (_) => [
      timezoneEnabledProvider.overrideWith(
        (ref) => Stream.value(timezoneEnabled),
      ),
    ],
  );
  addTearDown(fixture.dispose);
  await (fixture.database.update(fixture.database.todoTasks)
        ..where((task) => task.id.equals(_taskId)))
      .write(const TodoTasksCompanion(timeZone: Value('Asia/Shanghai')));
  final repository = fixture.container.read(reminderRepositoryProvider)!;
  final reminder = await repository.create(
    taskId: _taskId,
    fireAt: DateTime(2026, 7, 11, 9, 10),
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: const Scaffold(
          body: TaskDetailPane(taskId: _taskId, embedded: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('task-schedule-options')));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byKey(const Key('task-reminders')),
    160,
    scrollable: find.byType(Scrollable).last,
  );
  final editReminder = find.byKey(ValueKey('task-reminder-edit-${reminder.id}'));
  await tester.ensureVisible(editReminder);
  await tester.pumpAndSettle();
  await tester.tap(editReminder);
  await tester.pumpAndSettle();

  expect(
    find.text('编辑提醒'),
    findsOneWidget,
    reason: '编辑器没打开的话，下面两条显隐断言全是恒真的',
  );
}
