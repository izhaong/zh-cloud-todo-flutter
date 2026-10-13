import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/task/default_reminder_fire_at.dart';
import 'package:zh_cloud_todo_flutter/features/task/quick_add_batch_reminders.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/105 · 新任务默认值补「默认提醒」档（矩阵 #9 面 ⑥）。
///
/// 判据源《02-功能指南/01-任务/04-超强大的提醒功能.md》:33——
/// 「在…『任务默认值』-『默认提醒』中选择常用的提醒，将它设置为默认提醒」。
void main() {
  group('reminderFireAtFor 换算', () {
    final due = DateTime(2030, 5, 6, 9, 0);
    final now = DateTime(2030, 5, 5, 12, 0);

    test('null 档（不提醒）不加偏移：提醒时刻就是任务时刻', () {
      expect(
        reminderFireAtFor(due, defaultReminderMinutes: null, now: now),
        due,
      );
    });

    test('0 档（准时）不加偏移，与 null 同时刻但语义分档', () {
      expect(reminderFireAtFor(due, defaultReminderMinutes: 0, now: now), due);
    });

    test('提前 30 分钟：提醒 = 任务时刻 − 30 分钟', () {
      expect(
        reminderFireAtFor(due, defaultReminderMinutes: 30, now: now),
        due.subtract(const Duration(minutes: 30)),
      );
    });

    test('换算结果落在过去（<= now）⇒ 返回 null，这条不建', () {
      // 任务 30 分钟后到期、默认提前 60 分钟 ⇒ 提醒时刻已是过去。
      final soonDue = now.add(const Duration(minutes: 30));
      expect(
        reminderFireAtFor(soonDue, defaultReminderMinutes: 60, now: now),
        isNull,
      );
      // 恰好等于 now 也算过去（<= 语义钉死，别在下一轮当成 > 才跳过）。
      final exactDue = now.add(const Duration(minutes: 30));
      expect(
        reminderFireAtFor(exactDue, defaultReminderMinutes: 30, now: now),
        isNull,
      );
    });
  });

  group('TaskCaptureDefaults 默认提醒档', () {
    test('toJson 保留 null 档；fromJson 能读回 null 与数字两态', () {
      final off = TaskCaptureDefaults(defaultReminderMinutes: null);
      final offJson = off.toJson();
      expect(offJson.containsKey('defaultReminderMinutes'), isTrue);
      expect(
        TaskCaptureDefaults.fromJson(offJson).defaultReminderMinutes,
        isNull,
      );

      final early = TaskCaptureDefaults(defaultReminderMinutes: 30);
      final back = TaskCaptureDefaults.fromJson(early.toJson());
      expect(back.defaultReminderMinutes, 30);
      expect(back, early);
    });

    test('旧数据（JSON 里没有这一档）读成 null，不抛错', () {
      final legacy = TaskCaptureDefaults.fromJson({
        'defaultListId': 'list-1',
        'defaultPriority': 2,
      });
      expect(legacy.defaultReminderMinutes, isNull);
      expect(legacy.defaultListId, 'list-1');
      expect(legacy.defaultPriority, 2);
    });
  });

  group('批量路径 attachResolvedReminders 套用默认提醒', () {
    Future<List<TodoTask>> batchCreate(
      TodoVisualFixture fixture,
      String input,
    ) async {
      final repo = fixture.container.read(taskRepositoryProvider);
      expect(repo, isNotNull);
      return repo!.createBatch(
        listId: TodoVisualFixture.inboxListId,
        input: input,
        dueAtResolver: (line) =>
            line.endsWith('明天9点') ? DateTime(2030, 5, 6, 9, 0) : null,
      );
    }

    Future<List<TodoReminder>> remindersFor(AppDatabase db, Set<String> ids) =>
        (db.select(
          db.todoReminders,
        )..where((row) => row.taskId.isIn(ids))).get();

    test('默认提前 15 分钟：每行的提醒 = 识别时刻 − 15 分钟', () async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final created = await batchCreate(fixture, '写周报 明天9点\n买牛奶\n交材料 明天9点');
      expect(created, hasLength(3));

      final message = await attachResolvedReminders(
        created: created,
        reminders: fixture.container.read(reminderRepositoryProvider),
        defaultReminderMinutes: 15,
      );

      expect(message, isNull);
      final ids = created.map((task) => task.id).toSet();
      final rows = await remindersFor(fixture.database, ids);
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.remindAt).toSet(), {
        DateTime(2030, 5, 6, 8, 45),
      });
      // 任务本身的 dueAt 不被默认提醒改写。
      final touched = created.where((task) => task.dueAt != null);
      expect(
        touched.map((task) => task.dueAt),
        everyElement(DateTime(2030, 5, 6, 9, 0)),
      );
    });

    test('默认提前量把时刻推进过去的行：不建提醒、不计失败、不回报', () async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repo = fixture.container.read(taskRepositoryProvider);
      final created = await repo!.createBatch(
        listId: TodoVisualFixture.inboxListId,
        input: '马上开会\n买牛奶',
        dueAtResolver: (line) => line.contains('开会')
            ? DateTime.now().add(const Duration(minutes: 30))
            : null,
      );
      expect(created, hasLength(2));

      final message = await attachResolvedReminders(
        created: created,
        reminders: fixture.container.read(reminderRepositoryProvider),
        defaultReminderMinutes: 60,
      );

      expect(message, isNull, reason: '默认提醒跳过过去时刻不是写入失败');
      final ids = created.map((task) => task.id).toSet();
      expect(await remindersFor(fixture.database, ids), isEmpty);
    });
  });

  group('单条快速添加路径（widget 级）', () {
    Finder sheetMessage(Pattern text) {
      return find.descendant(
        of: find.byKey(const Key('todo-quick-add-sheet')),
        matching: find.textContaining(text),
        matchRoot: true,
      );
    }

    Future<List<TodoReminder>> remindersOf(AppDatabase db) =>
        db.select(db.todoReminders).get();

    Future<List<TodoTask>> tasksNamed(AppDatabase db, String title) =>
        (db.select(
          db.todoTasks,
        )..where((row) => row.title.equals(title))).get();

    Future<void> openSheet(
      WidgetTester tester,
      TodoVisualFixture fixture,
    ) async {
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

    Future<void> presetDefaults(
      TodoVisualFixture fixture,
      TaskCaptureDefaults defaults,
    ) async {
      final repo = fixture.container.read(
        taskCaptureDefaultsRepositoryProvider,
      );
      await repo!.save(defaults);
      // TaskQuickAddSheet 在保存时才读 get()，这里落库即可。
    }

    DateTime expectedTomorrowNine() {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    testWidgets('默认提前 30 分钟：提醒 = 识别时刻 − 30，任务 dueAt 不动', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await presetDefaults(
        fixture,
        const TaskCaptureDefaults(defaultReminderMinutes: 30),
      );
      await openSheet(tester, fixture);

      await tester.enterText(find.byType(TextField), '明天9点交报告');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskQuickAddSheet), findsNothing);
      final tasks = await tasksNamed(fixture.database, '明天9点交报告');
      expect(tasks, hasLength(1));
      expect(tasks.single.dueAt, expectedTomorrowNine());

      final reminders = await remindersOf(fixture.database);
      expect(reminders, hasLength(1));
      expect(
        reminders.single.remindAt,
        expectedTomorrowNine().subtract(const Duration(minutes: 30)),
      );
    });

    testWidgets('不提醒档（null）：提醒时刻仍是识别时刻（现状锁）', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await presetDefaults(fixture, const TaskCaptureDefaults());
      await openSheet(tester, fixture);

      await tester.enterText(find.byType(TextField), '明天9点交报告');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final reminders = await remindersOf(fixture.database);
      expect(reminders, hasLength(1));
      expect(reminders.single.remindAt, expectedTomorrowNine());
    });

    testWidgets('默认提前量把识别时刻推进过去：不建提醒，任务照建，无失败提示', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await presetDefaults(
        fixture,
        const TaskCaptureDefaults(defaultReminderMinutes: 60),
      );
      await openSheet(tester, fixture);

      await tester.enterText(find.byType(TextField), '今天0点30分取件');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskQuickAddSheet), findsNothing);
      final tasks = await tasksNamed(fixture.database, '今天0点30分取件');
      expect(tasks, hasLength(1));
      expect(tasks.single.dueAt, isNotNull);
      // 识别出的时刻 − 60 分钟 <= now ⇒ 一条提醒都不该建。
      expect(await remindersOf(fixture.database), isEmpty);
      expect(sheetMessage('提醒没建成'), findsNothing);
    });
  });

  group('设置页「默认提醒」档（AC-1）', () {
    Future<TodoVisualFixture> pumpSettings(WidgetTester tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: const MaterialApp(home: SettingsRoute()),
        ),
      );
      await tester.pumpAndSettle();
      return fixture;
    }

    Future<TaskCaptureDefaultsRepository?> defaultsRepo(
      TodoVisualFixture fixture,
    ) => Future.value(
      fixture.container.read(taskCaptureDefaultsRepositoryProvider),
    );

    testWidgets('进「新任务默认值」能看到「默认提醒」，选「提前 30 分钟」保存后回读一致', (tester) async {
      final fixture = await pumpSettings(tester);

      await tester.tap(find.text('新任务默认值'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-default-reminder')), findsOneWidget);

      // 默认档显示「不提醒」。
      expect(find.text('不提醒'), findsWidgets);

      await tester.tap(find.byKey(const Key('task-default-reminder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提前 30 分钟').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存默认值'));
      await tester.pumpAndSettle();
      expect(find.text('新任务默认值已保存，等待同步'), findsOneWidget);

      final saved = await (await defaultsRepo(fixture))!.get();
      expect(saved.defaultReminderMinutes, 30);
    });

    testWidgets('重进页面回读已保存的档位（回读一致性）', (tester) async {
      final fixture = await pumpSettings(tester);
      await (await defaultsRepo(fixture))!.save(
        const TaskCaptureDefaults(
          defaultListId: null,
          defaultPriority: 1,
          defaultReminderMinutes: 60,
        ),
      );

      await tester.tap(find.text('新任务默认值'));
      await tester.pumpAndSettle();

      // 回读后下拉当前档应是「提前 1 小时」。
      final dropdown = tester.widget<DropdownButtonFormField<int?>>(
        find.byKey(const Key('task-default-reminder')),
      );
      expect(dropdown.initialValue, 60);
    });
  });
}
