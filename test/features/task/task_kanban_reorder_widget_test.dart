import 'package:drift/drift.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('桌面看板通过专用手柄真实拖拽并逐项入队', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpKanban(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragKanbanTaskBefore(
      tester,
      sourceTaskId: TodoVisualFixture.secondaryTodayTaskId,
      targetTaskId: TodoVisualFixture.longContentTaskId,
    );

    expect(repository.requests, hasLength(1));
    final requested = repository.requests.single;
    expect(
      requested.indexOf(TodoVisualFixture.secondaryTodayTaskId),
      lessThan(requested.indexOf(TodoVisualFixture.longContentTaskId)),
    );

    final tasks =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where(
                (row) =>
                    row.listId.equals(TodoVisualFixture.inboxListId) &
                    row.parentTaskId.isNull(),
              )
              ..orderBy([(row) => OrderingTerm(expression: row.sortOrder)]))
            .get();
    final tasksById = {for (final task in tasks) task.id: task};
    expect(
      tasksById[TodoVisualFixture.secondaryTodayTaskId]?.sortOrder,
      requested.indexOf(TodoVisualFixture.secondaryTodayTaskId),
    );
    expect(
      tasksById[TodoVisualFixture.longContentTaskId]?.sortOrder,
      requested.indexOf(TodoVisualFixture.longContentTaskId),
    );
    expect(
      tasks.indexWhere(
        (task) => task.id == TodoVisualFixture.secondaryTodayTaskId,
      ),
      lessThan(
        tasks.indexWhere(
          (task) => task.id == TodoVisualFixture.longContentTaskId,
        ),
      ),
    );

    final queued = await (fixture.database.select(
      fixture.database.todoSyncChanges,
    )..where((row) => row.entity.equals('task'))).get();
    expect(queued, hasLength(requested.length));
  });

  testWidgets('桌面看板只读排序恢复原顺序并显示明确原因', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpKanban(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(
          db,
          failure: StateError('当前清单为只读，无法修改任务'),
        );
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragKanbanTaskBefore(
      tester,
      sourceTaskId: TodoVisualFixture.secondaryTodayTaskId,
      targetTaskId: TodoVisualFixture.longContentTaskId,
    );

    expect(repository.requests, hasLength(1));
    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const Key('kanban-task-${TodoVisualFixture.longContentTaskId}'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const Key(
                  'kanban-task-${TodoVisualFixture.secondaryTodayTaskId}',
                ),
              ),
            )
            .dy,
      ),
    );
  });
}

class _RecordingTaskViewActionRepository extends TaskViewActionRepository {
  _RecordingTaskViewActionRepository(AppDatabase db, {this.failure})
    : super(db, SyncChangeQueue(db));

  final Object? failure;
  final List<List<String>> requests = [];

  @override
  Future<void> reorderListTasks(List<String> taskIds) async {
    requests.add(List<String>.of(taskIds));
    final error = failure;
    if (error != null) throw error;
    await super.reorderListTasks(taskIds);
  }
}

Future<TodoVisualFixture> _pumpKanban(
  WidgetTester tester, {
  required List<Override> Function(AppDatabase database) overridesBuilder,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
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
        home: const Scaffold(
          body: TasksByListPage(
            initialListId: TodoVisualFixture.inboxListId,
            lockedListId: true,
            hideAppBar: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(find.byKey(const Key('todo-view-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(TaskViewMode.kanban.label).last);
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _dragKanbanTaskBefore(
  WidgetTester tester, {
  required String sourceTaskId,
  required String targetTaskId,
}) async {
  final source = find.byKey(Key('kanban-task-$sourceTaskId'));
  final target = find.byKey(Key('kanban-task-$targetTaskId'));
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  final columnScrollable = find
      .descendant(
        of: find.byKey(const ValueKey('col-todo')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(source, 100, scrollable: columnScrollable);
  await tester.pumpAndSettle();
  final handle = find.descendant(of: source, matching: find.byTooltip('拖动排序'));
  expect(handle, findsOneWidget);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(handle));
  await mouse.down(tester.getCenter(handle));
  await tester.pump();
  await mouse.moveBy(const Offset(0, -40));
  await tester.pump(const Duration(milliseconds: 100));
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 400));
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}
