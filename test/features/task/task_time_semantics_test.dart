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

  testWidgets('detail creates an end reminder through reminder repository', (
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

    final createReminder = find.byKey(const Key('task-add-end-reminder'));
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
    expect(reminders.single.anchorType, 'END');
    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    expect(change.entity, 'reminder');
  });

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
    'detail queues an end-offset reminder and a persistent end reminder',
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
              reminder.anchorType == 'END' && reminder.offsetMinutes == 10,
        ),
        isTrue,
      );
      expect(
        reminders.any(
          (reminder) =>
              reminder.anchorType == 'END' &&
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
