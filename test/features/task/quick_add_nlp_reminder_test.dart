import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 判据源《03-特色功能/05-智能识别.md》:5 逐字——
/// 「你可以在“快速添加”中直接输入日期文本，滴答清单会自动识别并为您创建日期和提醒。」
/// 原文是两半：日期 + 提醒。本文件钉后半（FL Issue #388）。
void main() {
  Finder sheetMessage(Pattern text) {
    return find.descendant(
      of: find.byKey(const Key('todo-quick-add-sheet')),
      matching: find.textContaining(text),
      matchRoot: true,
    );
  }

  /// 「明天9点」的期望时刻。
  ///
  /// 绑**真实时钟**而不是 fixture 的固定时间：本弹窗用的是 `NlpDateParser()` 无参构造，
  /// 走的是 `DateTime.now()`。把期望挂到 fixture 时间上，早晚两个桶里就会假绿。
  DateTime expectedTomorrowNine() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9, 0);
  }

  Future<List<TodoReminder>> remindersOf(AppDatabase db) =>
      db.select(db.todoReminders).get();

  Future<List<TodoTask>> tasksNamed(AppDatabase db, String title) =>
      (db.select(db.todoTasks)..where((row) => row.title.equals(title))).get();

  Future<void> openSheet(WidgetTester tester, TodoVisualFixture fixture) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(listId: TodoVisualFixture.inboxListId),
          ),
        ),
      ),
    );
  }

  testWidgets('识别到时间就同时建提醒：提醒时刻等于识别到的那个时间', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await openSheet(tester, fixture);

    final due = expectedTomorrowNine();
    await tester.enterText(find.byType(TextField), '明天9点交报告');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskQuickAddSheet), findsNothing);

    final tasks = await tasksNamed(fixture.database, '明天9点交报告');
    expect(tasks, hasLength(1));
    expect(tasks.single.dueAt, due);

    final reminders = await remindersOf(fixture.database);
    expect(reminders, hasLength(1), reason: '原文那句是「创建日期和提醒」，提醒这半不能只留在纸上');
    expect(reminders.single.taskId, tasks.single.id);
    expect(reminders.single.remindAt, due);
  });

  testWidgets('没识别出时间就不建提醒（不无中生有）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await openSheet(tester, fixture);

    await tester.enterText(find.byType(TextField), '买牛奶');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskQuickAddSheet), findsNothing);
    expect(await tasksNamed(fixture.database, '买牛奶'), hasLength(1));
    expect(await remindersOf(fixture.database), isEmpty);
  });

  testWidgets('提醒没建成：任务保留、弹窗不关、原因可见，再点保存不建第二遍任务', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        reminderRepositoryProvider.overrideWith(
          (ref) => _FailingReminderRepository(
            database,
            ref.watch(syncChangeQueueProvider)!,
          ),
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await openSheet(tester, fixture);

    await tester.enterText(find.byType(TextField), '明天9点交报告');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.byType(TaskQuickAddSheet),
      findsOneWidget,
      reason: '任务已经落库，关掉弹窗等于把部分成功说成全部成功（#289/#292 那类缺陷）',
    );
    expect(sheetMessage('任务已建，但提醒没建成'), findsOneWidget);
    expect(await tasksNamed(fixture.database, '明天9点交报告'), hasLength(1));
    expect(await remindersOf(fixture.database), isEmpty);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      await tasksNamed(fixture.database, '明天9点交报告'),
      hasLength(1),
      reason: '第二次点击只该补提醒；再建一遍任务是把失败处理成了重复数据',
    );
  });

  testWidgets('生产形态（320×568 + 1.3 倍字号 + 键盘）：这句新提示也落在键盘上方', (tester) async {
    // 本面没有新增界面，但**新增了一条提示文案**。它落在弹窗 Column 的最后一行，
    // 排版溢出正好会裁掉它 ⇒ 按生产拓扑量一次，不能只继承上一条测试的结论。
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        reminderRepositoryProvider.overrideWith(
          (ref) => _FailingReminderRepository(
            database,
            ref.watch(syncChangeQueueProvider)!,
          ),
        ),
      ],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => const TaskQuickAddSheet(
                    listId: TodoVisualFixture.inboxListId,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 最坏内容：标题命中识别（多一行「已识别截止时间」）+ 多一行反馈 + 1.3 倍字号。
    await tester.enterText(find.byType(TextField), '明天9点交报告');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('已识别截止时间'),
      findsOneWidget,
      reason: '最坏内容不在树里，这条量的就是更短的弹窗',
    );
    final feedback = find.byKey(const Key('todo-quick-add-feedback'));
    expect(feedback, findsOneWidget);
    expect(sheetMessage('任务已建，但提醒没建成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(feedback).bottom,
      lessThanOrEqualTo(568 - 260 + 0.5),
      reason: '被键盘或底边盖住的提示等于没有提示',
    );
  });
}

/// 让提醒这一步单独失败，用来打「部分成功」那条分支。
class _FailingReminderRepository extends ReminderRepository {
  _FailingReminderRepository(super.db, super.queue);

  @override
  Future<TodoReminder> create({
    required String taskId,
    required DateTime fireAt,
    String anchorType = 'ABSOLUTE',
    int? offsetMinutes,
    bool persistent = false,
    int? intervalMinutes,
    String? timeZone,
    bool fixedTimezone = false,
  }) async {
    throw StateError('本地写入被占用');
  }
}
