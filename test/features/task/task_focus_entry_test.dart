import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/pomodoro/pomodoro_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

void main() {
  testWidgets('task list menus open pomodoro only for synced active tasks', (
    tester,
  ) async {
    const serverId = 71;
    final api = _FocusEntryPomodoroApi();

    await _pumpTaskRow(
      tester,
      task: _task(id: 'desktop-active', serverId: serverId),
      api: api,
      desktopMode: true,
    );
    await _openDesktopContextMenu(tester);

    expect(find.text('开始专注'), findsOneWidget);
    await tester.tap(find.text('开始专注'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PomodoroPage>(find.byType(PomodoroPage)).taskId,
      serverId,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _pumpTaskRow(
      tester,
      task: _task(id: 'mobile-active', serverId: serverId),
      api: api,
      width: 320,
    );
    await tester.drag(find.byType(TaskRowHost), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('开始专注'), findsOneWidget);
    await tester.tap(find.text('开始专注'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PomodoroPage>(find.byType(PomodoroPage)).taskId,
      serverId,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    for (final task in [
      _task(id: 'local-task'),
      _task(id: 'completed-task', serverId: serverId, completed: true),
      _task(id: 'cancelled-task', serverId: serverId, cancelled: true),
    ]) {
      await _pumpTaskRow(tester, task: task, api: api, width: 320);
      await tester.drag(find.byType(TaskRowHost), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('开始专注'), findsNothing);
      expect(find.text('删除'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('task detail menu forwards synced active task to pomodoro', (
    tester,
  ) async {
    const serverId = 91;
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (_) => [
        pomodoroApiProvider.overrideWithValue(_FocusEntryPomodoroApi()),
      ],
    );
    addTearDown(fixture.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(serverId)));

    await _pumpTaskDetail(
      tester,
      container: fixture.container,
      taskId: TodoVisualFixture.todayTaskId,
      size: const Size(320, 844),
    );
    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    expect(find.text('开始专注'), findsOneWidget);
    await tester.tapAt(const Offset(4, 500));
    await tester.pumpAndSettle();

    await _pumpTaskDetail(
      tester,
      container: fixture.container,
      taskId: TodoVisualFixture.secondaryTodayTaskId,
      size: const Size(320, 844),
    );
    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    expect(find.text('开始专注'), findsNothing);
    await tester.tapAt(const Offset(4, 500));
    await tester.pumpAndSettle();

    final observer = _RouteRecorder();
    await _pumpTaskDetail(
      tester,
      container: fixture.container,
      taskId: TodoVisualFixture.todayTaskId,
      embedded: true,
      size: const Size(760, 900),
      observer: observer,
    );
    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    expect(find.text('开始专注'), findsOneWidget);
    await tester.tap(find.text('开始专注'));
    final route = observer.lastPushed;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    final page = (route! as MaterialPageRoute<dynamic>).builder(
      tester.element(find.byType(TaskDetailPane)),
    );
    expect(page, isA<PomodoroPage>());
    expect((page as PomodoroPage).taskId, serverId);
  });
}

Future<void> _pumpTaskDetail(
  WidgetTester tester, {
  required ProviderContainer container,
  required String taskId,
  required Size size,
  bool embedded = false,
  NavigatorObserver? observer,
}) async {
  tester.view.physicalSize = size;
  final detail = TaskDetailPane(taskId: taskId, embedded: embedded);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: embedded ? Scaffold(body: detail) : detail,
        navigatorObservers: observer == null ? const [] : [observer],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RouteRecorder extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

Future<void> _pumpTaskRow(
  WidgetTester tester, {
  required TodoTask task,
  required PomodoroApi api,
  bool desktopMode = false,
  double width = 640,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagRepositoryProvider.overrideWithValue(null),
        taskRepositoryProvider.overrideWithValue(null),
        pomodoroApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: TaskRowHost(
              task: task,
              desktopMode: desktopMode,
              enableSwipeGestures: !desktopMode,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDesktopContextMenu(WidgetTester tester) async {
  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  addTearDown(mouse.removePointer);
  await mouse.addPointer();
  await mouse.moveTo(tester.getCenter(find.byType(TaskRowHost)));
  await tester.pump();
  await mouse.down(tester.getCenter(find.byType(TaskRowHost)));
  await mouse.up();
  await tester.pumpAndSettle();
}

TodoTask _task({
  required String id,
  int? serverId,
  bool completed = false,
  bool cancelled = false,
}) {
  final now = DateTime(2026, 8, 2, 10);
  return TodoTask(
    id: id,
    serverId: serverId,
    listId: 'inbox',
    title: id,
    completed: completed,
    cancelled: cancelled,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    updatedAt: now,
    createdAt: now,
  );
}

class _FocusEntryPomodoroApi extends PomodoroApi {
  _FocusEntryPomodoroApi() : super(Dio());

  @override
  Future<List<PomodoroPresetDto>> presets() async {
    return const [
      PomodoroPresetDto(
        mode: 'MODE_25_5',
        label: '经典 25/5',
        focusMinutes: 25,
        breakMinutes: 5,
      ),
    ];
  }

  @override
  Future<PomodoroSessionDto?> active() async => null;

  @override
  Future<List<PomodoroSessionDto>> page({
    String? status,
    int pageNo = 1,
    int pageSize = 20,
  }) async => const [];

  @override
  Future<PomodoroStatsDto> stats({String period = 'week'}) async {
    return const PomodoroStatsDto.empty();
  }

  @override
  Future<List<PomodoroTimelineDto>> timeline({required DateTime date}) async {
    return const [];
  }

  @override
  Future<List<PomodoroTimerDto>> timers({bool archived = false}) async {
    return const [];
  }
}
