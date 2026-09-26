import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

const _taskId = TodoVisualFixture.pinnedTaskId;

Future<void> _openScheduleOptions(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('task-schedule-options')));
  await tester.pumpAndSettle();
}

Future<void> _closeScheduleOptions(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('task-schedule-close')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'detail completes a task only through the repository outbox contract',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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

      await tester.tap(find.byTooltip('勾选完成'));
      await tester.pumpAndSettle();

      final task = await fixture.container
          .read(taskRepositoryProvider)!
          .getById(_taskId);
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(task?.completed, isTrue);
      expect(task?.completedAt, isNotNull);
      expect(change.entity, 'task');
      expect(payload['status'], 'DONE');
      expect(payload['completedAt'], isNotNull);
    },
  );

  testWidgets(
    'detail saves all-day and fixed timezone through task repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(taskRepositoryProvider)!;

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

      await _openScheduleOptions(tester);

      final allDay = find.byKey(const Key('task-all-day'));
      final fixedTimezone = find.byKey(const Key('task-fixed-timezone'));
      final detailScroll = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(allDay, 160, scrollable: detailScroll);
      await tester.ensureVisible(allDay);
      await tester.pumpAndSettle();
      await tester.tap(allDay);
      await tester.scrollUntilVisible(
        fixedTimezone,
        160,
        scrollable: detailScroll,
      );
      await tester.ensureVisible(fixedTimezone);
      await tester.pumpAndSettle();
      await tester.tap(fixedTimezone);
      await _closeScheduleOptions(tester);
      await tester.drag(detailScroll, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final task = await repository.getById(_taskId);
      expect(task?.allDay, isTrue);
      expect(task?.fixedTimezone, isTrue);
      expect(task?.timeZone, 'Asia/Shanghai');
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      final payload =
          jsonDecode(changes.last.payloadJson) as Map<String, dynamic>;
      expect(payload['allDay'], isTrue);
      expect(payload['fixedTimezone'], isTrue);
      expect(payload['timeZone'], 'Asia/Shanghai');
    },
  );

  testWidgets(
    'detail renders a fixed timezone due time as its configured wall clock',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((task) => task.id.equals(_taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(DateTime.utc(2026, 7, 11, 16, 30)),
          timeZone: const Value('America/Los_Angeles'),
          fixedTimezone: const Value(true),
          timeMode: const Value(1),
        ),
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

      expect(
        find.text('2026-07-11 09:30 (America/Los_Angeles 固定时区)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'detail fixed timezone picker round-trips the configured wall clock',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final originalDueAt = DateTime.utc(2026, 7, 11, 16, 30);
      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((task) => task.id.equals(_taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(originalDueAt),
          timeZone: const Value('America/Los_Angeles'),
          fixedTimezone: const Value(true),
          timeMode: const Value(1),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
            home: const Scaffold(
              body: TaskDetailPane(taskId: _taskId, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openScheduleOptions(tester);

      await tester.tap(find.byKey(const Key('task-due-at')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('09'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await _closeScheduleOptions(tester);
      final detailScroll = find.byType(Scrollable).last;
      await tester.drag(detailScroll, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final task = await fixture.container
          .read(taskRepositoryProvider)!
          .getById(_taskId);
      expect(task?.dueAt?.isAtSameMomentAs(originalDueAt), isTrue);
    },
  );

  testWidgets(
    'detail all-day picker saves a pure date without opening time picker',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((task) => task.id.equals(_taskId))).write(
        TodoTasksCompanion(
          dueAt: Value(DateTime(2026, 7, 11)),
          allDay: const Value(true),
          timeZone: const Value('America/Los_Angeles'),
          fixedTimezone: const Value(true),
          timeMode: const Value(1),
        ),
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
      await _openScheduleOptions(tester);

      await tester.tap(find.byKey(const Key('task-due-at')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('15').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);

      await _closeScheduleOptions(tester);
      final detailScroll = find.byType(Scrollable).last;
      await tester.drag(detailScroll, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final task = await fixture.container
          .read(taskRepositoryProvider)!
          .getById(_taskId);
      expect(task?.dueAt, DateTime(2026, 7, 15));
      expect(task?.dueAt?.isUtc, isFalse);
      expect(task?.allDay, isTrue);
      expect(task?.fixedTimezone, isTrue);
      final payload =
          jsonDecode(
                (await fixture.database
                        .select(fixture.database.todoSyncChanges)
                        .get())
                    .last
                    .payloadJson,
              )
              as Map<String, dynamic>;
      expect(
        DateTime.fromMillisecondsSinceEpoch(payload['dueAt'] as int),
        DateTime(2026, 7, 15),
      );
      expect(payload['allDay'], isTrue);
    },
  );

  testWidgets('detail creates a due reminder through reminder repository', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

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

    await _openScheduleOptions(tester);

    final createReminder = find.byKey(const Key('task-add-due-reminder'));
    await tester.scrollUntilVisible(
      createReminder,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(createReminder);
    await tester.pumpAndSettle();

    final reminders = await fixture.database
        .select(fixture.database.todoReminders)
        .get();
    expect(reminders, hasLength(1));
    expect(reminders.single.taskId, _taskId);
    expect(reminders.single.anchorType, 'DUE');
    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    expect(change.entity, 'reminder');
  });

  testWidgets(
    'detail creates an end-time reminder through reminder repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final endAt = DateTime(2026, 7, 11, 11, 30);
      await (fixture.database.update(fixture.database.todoTasks)
            ..where((task) => task.id.equals(_taskId)))
          .write(TodoTasksCompanion(endAt: Value(endAt)));

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
      await _openScheduleOptions(tester);

      final createReminder = find.byKey(const Key('task-add-end-reminder'));
      await tester.scrollUntilVisible(
        createReminder,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(createReminder);
      await tester.pumpAndSettle();
      await tester.tap(createReminder);
      await tester.pumpAndSettle();

      final reminder = await fixture.database
          .select(fixture.database.todoReminders)
          .getSingle();
      expect(reminder.taskId, _taskId);
      expect(reminder.anchorType, 'END');
      expect(reminder.remindAt, endAt);
    },
  );

  testWidgets('detail displays a retryable reminder sync state', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    final reminder = await fixture.container
        .read(reminderRepositoryProvider)!
        .create(taskId: _taskId, fireAt: DateTime(2026, 7, 11, 10));
    await (fixture.database.update(
      fixture.database.todoSyncChanges,
    )..where((change) => change.entityLocalId.equals(reminder.id))).write(
      const TodoSyncChangesCompanion(
        status: Value('retryable'),
        attemptCount: Value(2),
      ),
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
    await _openScheduleOptions(tester);

    final reminderList = find.byKey(const Key('task-reminders'));
    await tester.scrollUntilVisible(
      reminderList,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final reminderTile = find.byKey(ValueKey('task-reminder-${reminder.id}'));
    await tester.ensureVisible(reminderTile);
    await tester.pumpAndSettle();
    expect(find.text('同步失败，等待重试（已尝试 2 次）'), findsOneWidget);
    expect(
      find.byKey(ValueKey('task-reminder-retry-${reminder.id}')),
      findsOneWidget,
    );
  });

  testWidgets(
    'detail creates an absolute reminder through reminder repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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
      await _openScheduleOptions(tester);

      final addReminder = find.byKey(const Key('task-add-absolute-reminder'));
      await tester.scrollUntilVisible(
        addReminder,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(addReminder);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final reminder = await fixture.database
          .select(fixture.database.todoReminders)
          .getSingle();
      expect(reminder.taskId, _taskId);
      expect(reminder.anchorType, 'ABSOLUTE');
      expect(reminder.offsetMinutes, isNull);
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .single;
      expect(change.entity, 'reminder');
    },
  );

  testWidgets(
    'detail queues a due-offset reminder and a persistent due reminder',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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
      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final beforeDue = find.byKey(const Key('task-add-before-due-reminder'));
      await tester.scrollUntilVisible(beforeDue, 160, scrollable: detailScroll);
      await tester.tap(beforeDue);
      await tester.pumpAndSettle();

      final persistent = find.byKey(
        const Key('task-add-persistent-end-reminder'),
      );
      await tester.scrollUntilVisible(
        persistent,
        160,
        scrollable: detailScroll,
      );
      await tester.tap(persistent);
      await tester.pumpAndSettle();

      final reminders = await fixture.database
          .select(fixture.database.todoReminders)
          .get();
      expect(reminders, hasLength(2));
      expect(
        reminders.any(
          (reminder) =>
              reminder.anchorType == 'DUE' && reminder.offsetMinutes == 10,
        ),
        isTrue,
      );
      expect(
        reminders.any(
          (reminder) =>
              reminder.anchorType == 'DUE' &&
              reminder.persistent &&
              reminder.intervalMinutes == 30,
        ),
        isTrue,
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        changes.where((change) => change.entity == 'reminder'),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'detail edits an existing reminder anchor and persistent settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final dueAt = DateTime(2026, 7, 12, 10);
      await (fixture.database.update(fixture.database.todoTasks)
            ..where((task) => task.id.equals(_taskId)))
          .write(TodoTasksCompanion(dueAt: Value(dueAt)));
      final repository = fixture.container.read(reminderRepositoryProvider)!;
      final reminder = await repository.create(
        taskId: _taskId,
        fireAt: DateTime(2026, 7, 11, 9, 10),
        timeZone: 'Asia/Shanghai',
        fixedTimezone: true,
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
      await _openScheduleOptions(tester);

      final reminderList = find.byKey(const Key('task-reminders'));
      await tester.scrollUntilVisible(
        reminderList,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      final editReminder = find.byKey(
        ValueKey('task-reminder-edit-${reminder.id}'),
      );
      await tester.ensureVisible(editReminder);
      await tester.pumpAndSettle();
      await tester.tap(editReminder);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-reminder-anchor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('截止时').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-reminder-offset-minutes')),
        '15',
      );
      await tester.tap(find.byKey(const Key('task-reminder-persistent')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-reminder-interval-minutes')),
        '20',
      );
      await tester.tap(find.byKey(const Key('task-reminder-save')));
      await tester.pumpAndSettle();

      expect(find.text('截止前 15 分钟'), findsOneWidget);
      expect(find.text('持续提醒，每 20 分钟'), findsOneWidget);
      final updated = await fixture.database
          .select(fixture.database.todoReminders)
          .getSingle();
      expect(updated.id, reminder.id);
      expect(updated.anchorType, 'DUE');
      expect(updated.offsetMinutes, 15);
      expect(updated.remindAt, DateTime(2026, 7, 12, 9, 45));
      expect(updated.persistent, isTrue);
      expect(updated.intervalMinutes, 20);
      expect(updated.timeZone, 'Asia/Shanghai');
      expect(updated.fixedTimezone, isTrue);

      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(change.entity, 'reminder');
      expect(change.entityLocalId, reminder.id);
      expect(payload['anchorType'], 'DUE');
      expect(payload['offsetMinutes'], 15);
      expect(payload['persistent'], isTrue);
      expect(payload['intervalMinutes'], 20);
      expect(payload['timeZone'], 'Asia/Shanghai');
      expect(payload['fixedTimezone'], isTrue);
    },
  );

  testWidgets('detail edits an existing absolute reminder time', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
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
    await _openScheduleOptions(tester);

    final reminderList = find.byKey(const Key('task-reminders'));
    await tester.scrollUntilVisible(
      reminderList,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final editReminder = find.byKey(
      ValueKey('task-reminder-edit-${reminder.id}'),
    );
    await tester.ensureVisible(editReminder);
    await tester.pumpAndSettle();
    await tester.tap(editReminder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-reminder-fire-at')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-reminder-save')));
    await tester.pumpAndSettle();

    final updated = await fixture.database
        .select(fixture.database.todoReminders)
        .getSingle();
    expect(updated.id, reminder.id);
    expect(updated.anchorType, 'ABSOLUTE');
    expect(updated.remindAt, DateTime(2026, 7, 12, 9, 10));
    expect(updated.timeZone, isNull);
    expect(updated.fixedTimezone, isFalse);
  });

  testWidgets(
    'detail exposes start and end time editing through task repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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

      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final start = find.byKey(const Key('task-start-at'));
      final end = find.byKey(const Key('task-end-at'));
      await tester.scrollUntilVisible(start, 160, scrollable: detailScroll);
      expect(start, findsOneWidget);
      await tester.scrollUntilVisible(end, 160, scrollable: detailScroll);
      expect(end, findsOneWidget);
    },
  );

  testWidgets(
    'detail clears a persisted time range and records a local outbox update',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(taskRepositoryProvider)!;

      await (fixture.database.update(
        fixture.database.todoTasks,
      )..where((task) => task.id.equals(_taskId))).write(
        TodoTasksCompanion(
          startAt: Value(DateTime(2026, 7, 11, 9)),
          endAt: Value(DateTime(2026, 7, 11, 10)),
        ),
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

      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final clearStart = find.byKey(const Key('task-clear-start-at'));
      final clearEnd = find.byKey(const Key('task-clear-end-at'));
      await tester.scrollUntilVisible(
        clearStart,
        160,
        scrollable: detailScroll,
      );
      await tester.tap(clearStart);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(clearEnd, 160, scrollable: detailScroll);
      await tester.tap(clearEnd);
      await tester.pumpAndSettle();
      await _closeScheduleOptions(tester);
      await tester.drag(detailScroll, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final task = await repository.getById(_taskId);
      expect(task?.startAt, isNull);
      expect(task?.endAt, isNull);
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['startAt'], isNull);
      expect(payload['endAt'], isNull);
    },
  );

  testWidgets(
    'detail saves a weekly repeat rule through the repeat repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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

      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final repeatRule = find.byKey(const Key('task-repeat-rule'));
      await tester.scrollUntilVisible(
        repeatRule,
        160,
        scrollable: detailScroll,
      );
      await tester.ensureVisible(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-repeat-frequency-weekly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-repeat-save')));
      await tester.pumpAndSettle();

      final rules = await fixture.database
          .select(fixture.database.todoRepeatRules)
          .get();
      expect(rules, hasLength(1));
      expect(rules.single.taskId, _taskId);
      expect(rules.single.freq, 'WEEKLY');
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      expect(change.entity, 'repeat_rule');
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['frequency'], 'weekly');
      expect(payload['repeatMode'], 'ON_DUE');
    },
  );

  testWidgets(
    'detail saves two selected repeat dates without another end boundary',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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
      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final repeatRule = find.byKey(const Key('task-repeat-rule'));
      await tester.scrollUntilVisible(
        repeatRule,
        160,
        scrollable: detailScroll,
      );
      await tester.ensureVisible(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('task-repeat-mode-on_selected_dates')),
      );
      await tester.pumpAndSettle();

      final addDate = find.byKey(const Key('task-repeat-selected-date-add'));
      expect(addDate, findsOneWidget);
      expect(find.byKey(const Key('task-repeat-end-until')), findsNothing);
      await tester.tap(addDate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(addDate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-repeat-save')));
      await tester.pumpAndSettle();

      final rule = await fixture.database
          .select(fixture.database.todoRepeatRules)
          .getSingle();
      expect(rule.freq, 'CUSTOM');
      expect(rule.repeatMode, 'ON_SELECTED_DATES');
      expect(rule.byDay, isNull);
      expect(rule.until, isNull);
      expect(rule.countLimit, isNull);
      expect(rule.selectedDatesJson, '["2026-07-15","2026-07-20"]');
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['selectedDates'], ['2026-07-15', '2026-07-20']);
    },
  );

  testWidgets(
    'detail edits selected repeat dates with deletion and deduplication',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await fixture.container
          .read(repeatRuleRepositoryProvider)!
          .save(
            taskId: _taskId,
            frequency: 'CUSTOM',
            startAt: DateTime(2026, 7, 11, 9, 30),
            repeatMode: 'ON_SELECTED_DATES',
            selectedDates: [
              DateTime(2026, 7, 20),
              DateTime(2026, 7, 15),
              DateTime(2026, 7, 20),
            ],
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
      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final repeatRule = find.byKey(const Key('task-repeat-rule'));
      await tester.scrollUntilVisible(
        repeatRule,
        160,
        scrollable: detailScroll,
      );
      await tester.ensureVisible(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(repeatRule);
      await tester.pumpAndSettle();

      final selectedDateChips = tester
          .widgetList<InputChip>(find.byType(InputChip))
          .toList();
      expect(selectedDateChips.map((chip) => (chip.label as Text).data), [
        '2026-07-15',
        '2026-07-20',
      ]);

      final date15 = find.byKey(
        const Key('task-repeat-selected-date-2026-07-15'),
      );
      expect(find.byTooltip('删除 2026-07-15'), findsOneWidget);
      tester.widget<InputChip>(date15).onDeleted!.call();
      await tester.pumpAndSettle();
      expect(date15, findsNothing);

      final addDate = find.byKey(const Key('task-repeat-selected-date-add'));
      await tester.tap(addDate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);

      await tester.tap(addDate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-repeat-save')));
      await tester.pumpAndSettle();

      final rule = await fixture.database
          .select(fixture.database.todoRepeatRules)
          .getSingle();
      expect(rule.selectedDatesJson, '["2026-07-20","2026-07-25"]');
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['selectedDates'], ['2026-07-20', '2026-07-25']);
    },
  );

  testWidgets('detail can change a selected-date rule back to due mode', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await fixture.container
        .read(repeatRuleRepositoryProvider)!
        .save(
          taskId: _taskId,
          frequency: 'CUSTOM',
          startAt: DateTime(2026, 7, 11, 9, 30),
          repeatMode: 'ON_SELECTED_DATES',
          selectedDates: [DateTime(2026, 7, 15), DateTime(2026, 7, 20)],
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
    await _openScheduleOptions(tester);

    final detailScroll = find.byType(Scrollable).last;
    final repeatRule = find.byKey(const Key('task-repeat-rule'));
    await tester.scrollUntilVisible(repeatRule, 160, scrollable: detailScroll);
    await tester.ensureVisible(repeatRule);
    await tester.pumpAndSettle();
    await tester.tap(repeatRule);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('task-repeat-selected-date-2026-07-15')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('task-repeat-mode-on_due')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rule = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .getSingle();
    expect(rule.repeatMode, 'ON_DUE');
    expect(rule.selectedDatesJson, isNull);
    expect(rule.byDay, isNotNull);
    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['selectedDates'], isNull);
  });

  testWidgets(
    'detail saves a repeat count limit through the repeat repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

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
      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final repeatRule = find.byKey(const Key('task-repeat-rule'));
      await tester.scrollUntilVisible(
        repeatRule,
        160,
        scrollable: detailScroll,
      );
      await tester.ensureVisible(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(repeatRule);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-repeat-end-count')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('task-repeat-count')), '3');
      await tester.tap(find.byKey(const Key('task-repeat-save')));
      await tester.pumpAndSettle();

      final rule = await fixture.database
          .select(fixture.database.todoRepeatRules)
          .getSingle();
      expect(rule.countLimit, 3);
      expect(rule.until, isNull);
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
      expect(payload['countLimit'], 3);
      expect(payload['untilAt'], isNull);
    },
  );

  testWidgets('detail saves a repeat end date as an inclusive day boundary', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

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
    await _openScheduleOptions(tester);

    final detailScroll = find.byType(Scrollable).last;
    final repeatRule = find.byKey(const Key('task-repeat-rule'));
    await tester.scrollUntilVisible(repeatRule, 160, scrollable: detailScroll);
    await tester.ensureVisible(repeatRule);
    await tester.pumpAndSettle();
    await tester.tap(repeatRule);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-end-until')));
    await tester.pumpAndSettle();
    final untilDate = find.byKey(const Key('task-repeat-until-date'));
    await tester.ensureVisible(untilDate);
    await tester.pumpAndSettle();
    await tester.tap(untilDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('18').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rule = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .getSingle();
    expect(rule.until, DateTime(2026, 7, 18, 23, 59, 59));
    expect(rule.countLimit, isNull);
    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['untilAt'], '2026-07-18T23:59:59.000');
    expect(payload['countLimit'], isNull);
  });

  testWidgets('detail shows a recoverable error for an invalid time range', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await (fixture.database.update(
      fixture.database.todoTasks,
    )..where((task) => task.id.equals(_taskId))).write(
      TodoTasksCompanion(
        startAt: Value(DateTime(2026, 7, 11, 10)),
        endAt: Value(DateTime(2026, 7, 11, 9)),
      ),
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

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
  });

  testWidgets(
    'detail lists and removes a local reminder through its repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(reminderRepositoryProvider)!;
      final first = await repository.create(
        taskId: _taskId,
        fireAt: DateTime(2026, 7, 11, 9, 10),
      );
      await repository.create(
        taskId: _taskId,
        fireAt: DateTime(2026, 7, 11, 9, 20),
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

      await _openScheduleOptions(tester);

      final reminderList = find.byKey(const Key('task-reminders'));
      await tester.scrollUntilVisible(
        reminderList,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(reminderList);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('task-reminder-${first.id}')), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('task-reminder-remove-${first.id}')),
      );
      await tester.pumpAndSettle();

      final reminders = await fixture.database
          .select(fixture.database.todoReminders)
          .get();
      expect(reminders, hasLength(1));
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      expect(change.entity, 'reminder');
      expect(jsonDecode(change.payloadJson), containsPair('id', first.id));
    },
  );

  testWidgets(
    'detail skips the current repeat occurrence through its repository',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(repeatRuleRepositoryProvider)!;
      await repository.save(
        taskId: _taskId,
        frequency: 'WEEKLY',
        startAt: DateTime(2026, 7, 11, 9),
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

      await _openScheduleOptions(tester);

      final detailScroll = find.byType(Scrollable).last;
      final skip = find.byKey(const Key('task-repeat-skip'));
      await tester.scrollUntilVisible(skip, 160, scrollable: detailScroll);
      await tester.ensureVisible(skip);
      await tester.drag(detailScroll, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pumpAndSettle();

      final skips = await fixture.database
          .select(fixture.database.todoRepeatSkips)
          .get();
      expect(skips, hasLength(1));
      final change =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      expect(change.entity, 'repeat_skip');

      final localSkip = await fixture.database
          .select(fixture.database.todoRepeatSkips)
          .getSingle();
      await (fixture.database.update(fixture.database.todoRepeatSkips)
            ..where((row) => row.id.equals(localSkip.id)))
          .write(const TodoRepeatSkipsCompanion(serverId: Value(702)));
      await (fixture.database.update(fixture.database.todoSyncChanges)
            ..where((row) => row.entity.equals('repeat_skip')))
          .write(const TodoSyncChangesCompanion(status: Value('synced')));

      final catchup = find.byKey(const Key('task-repeat-catchup'));
      await tester.ensureVisible(catchup);
      await tester.tap(catchup);
      await tester.pumpAndSettle();

      expect(
        await fixture.database.select(fixture.database.todoRepeatSkips).get(),
        isEmpty,
      );
      final catchupChange =
          (await fixture.database
                  .select(fixture.database.todoSyncChanges)
                  .get())
              .last;
      expect(catchupChange.entity, 'repeat_occurrence_action');
    },
  );

  testWidgets(
    'detail skips a materialized repeat instance through its template rule',
    (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(repeatRuleRepositoryProvider)!;
      final occurrenceAt = DateTime(2026, 7, 18, 9);
      final rule = await repository.save(
        taskId: _taskId,
        frequency: 'WEEKLY',
        startAt: DateTime(2026, 7, 11, 9),
      );
      await fixture.database
          .into(fixture.database.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'materialized-repeat-instance',
              listId: TodoVisualFixture.inboxListId,
              title: '完成后生成的下一次',
              dueAt: Value(occurrenceAt),
              repeatParentTaskId: const Value(_taskId),
              repeatRuleId: Value(rule.id),
              repeatOccurrenceAt: Value(occurrenceAt),
              updatedAt: occurrenceAt,
              createdAt: occurrenceAt,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TaskDetailPane(
                taskId: 'materialized-repeat-instance',
                embedded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openScheduleOptions(tester);
      final detailScroll = find.byType(Scrollable).last;
      final skip = find.byKey(const Key('task-repeat-skip'));
      await tester.scrollUntilVisible(skip, 160, scrollable: detailScroll);
      await tester.ensureVisible(skip);
      await tester.drag(detailScroll, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pumpAndSettle();

      final skipEntry = await fixture.database
          .select(fixture.database.todoRepeatSkips)
          .getSingle();
      expect(skipEntry.repeatRuleId, rule.id);
      expect(skipEntry.taskId, _taskId);
      expect(skipEntry.occurrenceDate, occurrenceAt);
    },
  );
}
