import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 接线判据（FL Issue #410 / PR !431）。
///
/// `features/task/quick_add_batch_reminders_test.dart` 那四条量的是 helper 本身；
/// 本文件量的是「桌面壳的批量入口真的会去调它」——
/// 摘掉 `home_shell.dart` 里那次 `attachResolvedReminders` 调用，本文件必须变红，
/// 否则接线就没有判据（helper 绿只证明它能用，不证明有人用它）。
void main() {
  testWidgets('多行快速添加：识别到时间的每一行都各建一条提醒，且提醒时刻就是任务上的 dueAt', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: const HomeShell(incomingUriStream: Stream.empty()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddBar), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      '写周报 明天9点\n交材料 明天9点\n买牛奶',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final tasks = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    final reminders = await fixture.database
        .select(fixture.database.todoReminders)
        .get();

    expect(tasks, hasLength(3), reason: '三行输入应建三行任务');
    final withDue = tasks.where((task) => task.dueAt != null).toList();
    expect(
      withDue,
      hasLength(2),
      reason: '两行带「明天9点」被识别出时间；若这里是 0，是识别面坏了，不是本单要判的那件事',
    );
    expect(
      reminders,
      hasLength(2),
      reason: '识别到时间的每一行都要各落一条提醒；这里是 0 就说明批量入口没调 attachResolvedReminders',
    );
    expect(
      reminders.map((row) => row.taskId).toSet(),
      withDue.map((task) => task.id).toSet(),
      reason: '提醒要挂在被识别出时间的那两条任务上，不能挂在没时间的行上',
    );
    final byId = {for (final task in tasks) task.id: task};
    for (final row in reminders) {
      expect(
        row.remindAt,
        byId[row.taskId]!.dueAt,
        reason: '提醒时刻必须就是任务上的 dueAt，不做二次换算',
      );
    }
  });
}
