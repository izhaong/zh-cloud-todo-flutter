import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

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
                row.sourceKey == 'list:${TodoVisualFixture.inboxListId}',
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

  testWidgets('workspace view mode is isolated by list source', (tester) async {
    await _pumpWorkspace(tester);

    await _switchWorkspaceMode(tester, TaskViewMode.kanban);
    expect(find.text('未开始'), findsOneWidget);

    final personalList = find.byKey(
      const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
    );
    await tester.scrollUntilVisible(
      personalList,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('todo-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(personalList);
    await tester.pumpAndSettle();

    // 钉任务列表自己的滚动视图：侧栏标签分节（specs/088）也有一个
    // ReorderableListView，按类型数会数到 2。
    expect(find.byKey(const Key('todo-task-list-scroll')), findsOneWidget);
    expect(find.text('未开始'), findsNothing);

    await _switchWorkspaceMode(tester, TaskViewMode.timeline);
    final inbox = find.byKey(const Key('todo-sidebar-row-inbox'));
    await tester.scrollUntilVisible(
      inbox,
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('todo-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(inbox);
    await tester.pumpAndSettle();

    expect(find.text('未开始'), findsOneWidget);
    expect(find.byKey(const ValueKey('col-todo')), findsOneWidget);
  });

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

  testWidgets('stale A restore cannot overwrite the latest A after A-B-A', (
    tester,
  ) async {
    late final _DelayedTaskViewActionRepository repository;
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
      overridesBuilder: (db) {
        repository = _DelayedTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = TodoVisualViewports.wide;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.pump();
    final firstInboxRestore = repository.takeRequest(
      'list:${TodoVisualFixture.inboxListId}',
    );

    final personalList = find.byKey(
      const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
    );
    await tester.scrollUntilVisible(
      personalList,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('todo-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(personalList);
    await tester.pump();
    repository.takeRequest('list:${TodoVisualFixture.personalListId}');

    final inbox = find.byKey(const Key('todo-sidebar-row-inbox'));
    await tester.scrollUntilVisible(
      inbox,
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('todo-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(inbox);
    await tester.pump();
    final latestInboxRestore = repository.takeRequest(
      'list:${TodoVisualFixture.inboxListId}',
    );

    latestInboxRestore.complete('kanban');
    await tester.pump();
    expect(find.text('未开始'), findsOneWidget);

    firstInboxRestore.complete('timeline');
    await tester.pump();
    expect(find.text('未开始'), findsOneWidget);
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

class _DelayedTaskViewActionRepository extends TaskViewActionRepository {
  _DelayedTaskViewActionRepository(AppDatabase db)
    : super(db, SyncChangeQueue(db));

  final Map<String, List<Completer<String?>>> _requests = {};

  @override
  Future<TaskWorkspacePreference> getTaskWorkspacePreference({
    required String sourceKey,
  }) async {
    final completer = Completer<String?>();
    _requests.putIfAbsent(sourceKey, () => []).add(completer);
    return TaskWorkspacePreference(viewType: await completer.future);
  }

  @override
  Future<void> saveTaskWorkspaceViewMode({
    required String sourceKey,
    required String viewType,
  }) async {}

  Completer<String?> takeRequest(String sourceKey) {
    final requests = _requests[sourceKey];
    expect(
      requests,
      isNotNull,
      reason: 'missing restore request for $sourceKey',
    );
    expect(
      requests,
      isNotEmpty,
      reason: 'missing restore request for $sourceKey',
    );
    return requests!.removeAt(0);
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
