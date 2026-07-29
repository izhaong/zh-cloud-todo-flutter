import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

const _taskId = TodoVisualFixture.metadataTaskId;
const _taskTitle = '准备项目周会材料';

void main() {
  testWidgets('changing workspace mode preserves a valid task selection', (
    tester,
  ) async {
    await _pumpWorkspace(tester);

    await _tapListTask(tester, _taskId);
    expect(_detailText(_taskTitle), findsOneWidget);

    await _switchWorkspaceMode(tester, TaskViewMode.kanban);

    expect(_detailText(_taskTitle), findsOneWidget);
    expect(_detailTextContaining('选择任务'), findsNothing);
  });

  testWidgets(
    'changing workspace mode persists the preference before queuing sync',
    (tester) async {
      final fixture = await _pumpWorkspace(tester);

      await _switchWorkspaceMode(tester, TaskViewMode.kanban);

      final preferences = await fixture.database
          .select(fixture.database.todoViewPreferences)
          .get();
      final preference = preferences
          .where(
            (row) =>
                row.sourceType == 'task_view' &&
                row.sourceKey == 'tasks_by_list',
          )
          .firstOrNull;
      final queued = await (fixture.database.select(
        fixture.database.todoSyncChanges,
      )..where((row) => row.entity.equals('view_preference'))).get();

      expect(preference, isNotNull);
      expect(preference!.valueJson, contains('"viewType":"kanban"'));
      expect(queued, hasLength(1));
      expect(queued.single.entityLocalId, preference.id);
    },
  );

  testWidgets('workspace restores the persisted mode after remount', (
    tester,
  ) async {
    final fixture = await _pumpWorkspace(tester);
    await _switchWorkspaceMode(tester, TaskViewMode.kanban);
    expect(find.text('未开始'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未开始'), findsOneWidget);
    expect(find.byKey(const Key('task-list-reorderable')), findsNothing);
  });

  for (final mode in const [
    TaskViewMode.kanban,
    TaskViewMode.timeline,
    TaskViewMode.eisenhower,
    TaskViewMode.calendar,
  ]) {
    testWidgets(
      '${mode.label} task selection stays in the fixed workspace detail',
      (tester) async {
        await _pumpWorkspace(tester);
        await _switchWorkspaceMode(tester, mode);
        if (mode == TaskViewMode.calendar) {
          await _switchCalendarToList(tester);
        }

        final task = _contentText(_taskTitle);
        expect(task, findsOneWidget);
        final transientRouteBaseline = find
            .byType(ModalBarrier)
            .evaluate()
            .length;
        await tester.ensureVisible(task);
        await tester.tap(task);
        await tester.pumpAndSettle();

        final actual = (
          additionalTransientRoutes:
              find.byType(ModalBarrier).evaluate().length -
              transientRouteBaseline,
          fixedDetailMatches: _detailText(_taskTitle).evaluate().length,
        );
        expect(
          actual,
          equals((additionalTransientRoutes: 0, fixedDetailMatches: 1)),
          reason:
              'clicking a ${mode.label} task must update HomeShell selection '
              'without opening a dialog or sheet',
        );
      },
    );
  }
}

Future<TodoVisualFixture> _pumpWorkspace(WidgetTester tester) {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const HomeShell(),
  );
}

Future<void> _tapListTask(WidgetTester tester, String taskId) async {
  final surface = find.byKey(Key('task-row-surface-$taskId'));
  expect(surface, findsOneWidget);
  await tester.ensureVisible(surface);
  await tester.tap(surface);
  await tester.pumpAndSettle();
}

Future<void> _switchWorkspaceMode(
  WidgetTester tester,
  TaskViewMode mode,
) async {
  await tester.tap(find.byKey(const Key('todo-view-menu')));
  await tester.pumpAndSettle();
  final menuLabel = find.text(mode.label).last;
  await tester.tap(menuLabel);
  await tester.pumpAndSettle();
  expect(find.byType(PopupMenuItem<TaskViewMode>), findsNothing);
}

Future<void> _switchCalendarToList(WidgetTester tester) async {
  final listMode = find.descendant(
    of: find.byKey(const Key('todo-content')),
    matching: find.text('列表'),
  );
  expect(listMode, findsOneWidget);
  await tester.tap(listMode);
  await tester.pumpAndSettle();
}

Finder _contentText(String text) {
  return find.descendant(
    of: find.byKey(const Key('todo-content')),
    matching: find.text(text),
  );
}

Finder _detailText(String text) {
  return find.descendant(
    of: find.byKey(const Key('todo-detail')),
    matching: find.text(text),
  );
}

Finder _detailTextContaining(String text) {
  return find.descendant(
    of: find.byKey(const Key('todo-detail')),
    matching: find.textContaining(text),
  );
}
