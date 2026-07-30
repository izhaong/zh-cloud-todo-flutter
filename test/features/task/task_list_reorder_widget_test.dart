import 'package:drift/drift.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('桌面列表真实拖拽可重排合成收集箱并逐项入队', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    final fixture = await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragTaskAfter(
      tester,
      sourceTaskId: TodoVisualFixture.pinnedTaskId,
      targetTaskId: TodoVisualFixture.todayTaskId,
    );

    expect(repository.requests, hasLength(1));
    final requested = repository.requests.single;
    expect(
      requested.indexOf(TodoVisualFixture.todayTaskId),
      lessThan(requested.indexOf(TodoVisualFixture.pinnedTaskId)),
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
    expect(tasks[0].id, TodoVisualFixture.todayTaskId);
    expect(tasks[1].id, TodoVisualFixture.pinnedTaskId);

    final queued = await (fixture.database.select(
      fixture.database.todoSyncChanges,
    )..where((row) => row.entity.equals('task'))).get();
    expect(queued, hasLength(requested.length));
  });

  testWidgets('桌面列表只读拖拽回滚顺序并显示明确原因', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(
          db,
          failure: StateError('当前清单为只读，无法修改任务'),
        );
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    await _dragTaskAfter(
      tester,
      sourceTaskId: TodoVisualFixture.pinnedTaskId,
      targetTaskId: TodoVisualFixture.todayTaskId,
    );

    expect(repository.requests, hasLength(1));
    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const Key('task-row-surface-${TodoVisualFixture.pinnedTaskId}'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const Key('task-row-surface-${TodoVisualFixture.todayTaskId}'),
              ),
            )
            .dy,
      ),
    );
  });

  testWidgets('桌面智能清单不提供结构重排容器和拖拽入口', (tester) async {
    late final _RecordingTaskViewActionRepository repository;
    await _pumpList(
      tester,
      initialListId: null,
      overridesBuilder: (db) {
        repository = _RecordingTaskViewActionRepository(db);
        return [taskViewActionRepositoryProvider.overrideWithValue(repository)];
      },
    );

    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byTooltip('拖动排序'), findsNothing);
    expect(repository.requests, isEmpty);
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

Future<TodoVisualFixture> _pumpList(
  WidgetTester tester, {
  String? initialListId = TodoVisualFixture.inboxListId,
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
        home: Scaffold(
          body: TasksByListPage(
            initialListId: initialListId,
            lockedListId: true,
            hideAppBar: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return fixture;
}

Future<void> _dragTaskAfter(
  WidgetTester tester, {
  required String sourceTaskId,
  required String targetTaskId,
}) async {
  final source = find.byKey(Key('task-row-surface-$sourceTaskId'));
  final target = find.byKey(Key('task-row-surface-$targetTaskId'));
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  await tester.ensureVisible(source);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(source));
  await tester.pump();

  final handle = find.byTooltip('拖动排序');
  expect(handle, findsOneWidget);
  await mouse.moveTo(tester.getCenter(handle));
  await mouse.down(tester.getCenter(handle));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target) + const Offset(0, 24));
  await tester.pump(const Duration(milliseconds: 500));
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}
