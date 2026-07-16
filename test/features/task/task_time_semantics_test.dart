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

void main() {
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

      final allDay = find.byKey(const Key('task-all-day'));
      final fixedTimezone = find.byKey(const Key('task-fixed-timezone'));
      final detailScroll = find.byType(Scrollable).first;
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

    final createReminder = find.byKey(const Key('task-add-end-reminder'));
    await tester.scrollUntilVisible(
      createReminder,
      160,
      scrollable: find.byType(Scrollable).first,
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

      final detailScroll = find.byType(Scrollable).first;
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

      final detailScroll = find.byType(Scrollable).first;
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

      final detailScroll = find.byType(Scrollable).first;
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
}
