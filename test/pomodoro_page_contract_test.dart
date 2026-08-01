import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/pomodoro/pomodoro_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  testWidgets('starting a pomodoro exposes active session actions', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自由'));
    await tester.pump();
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    expect(api.started, isTrue);
    expect(api.startedMode, 'FREE');
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('开始专注'), findsNothing);
  });

  testWidgets('uses service presets and submits custom minutes', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);

    expect(find.text('经典 25/5'), findsOneWidget);
    await tester.tap(find.text('自定义'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('pomodoro-custom-minutes')),
      '45',
    );
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    expect(api.startedMode, 'CUSTOM');
    expect(api.startedMinutes, 45);
  });

  testWidgets('only synced incomplete tasks can be associated', (tester) async {
    final api = _FakePomodoroApi();
    final now = DateTime(2026, 8, 2);
    final tasks = [
      _task(id: 'synced', serverId: 81, title: '同步任务', now: now),
      _task(
        id: 'completed',
        serverId: 82,
        title: '已完成任务',
        completed: true,
        now: now,
      ),
      _task(id: 'local', title: '未同步任务', now: now),
    ];
    await _pumpPage(tester, api: api, tasks: tasks);

    await tester.tap(find.byKey(const Key('pomodoro-task')));
    await tester.pumpAndSettle();
    expect(find.text('同步任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('未同步任务'), findsNothing);
    await tester.tap(find.text('同步任务'));
    await tester.pump();
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    expect(api.startedTaskId, 81);
  });

  testWidgets('keeps note and active session when completion fails', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('开始专注'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('pomodoro-remark')),
      '  完成初稿  ',
    );
    api.completeError = StateError('offline');

    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(find.textContaining('完成失败'), findsOneWidget);
    final note = tester.widget<TextField>(
      find.byKey(const Key('pomodoro-remark')),
    );
    expect(note.controller?.text, '  完成初稿  ');
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('开始专注'), findsNothing);
  });

  testWidgets(
    'successful completion submits trimmed note and client end time',
    (tester) async {
      final api = _FakePomodoroApi();
      await _pumpPage(tester, api: api);
      await tester.tap(find.text('开始专注'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('pomodoro-remark')),
        '  完成初稿  ',
      );

      await tester.tap(find.text('完成'));
      await tester.pump();

      expect(api.completedRemark, '完成初稿');
      expect(api.completedAt, isNotNull);
      expect(find.text('开始专注'), findsOneWidget);
      expect(find.text('取消'), findsNothing);
      expect(find.byKey(const Key('pomodoro-remark')), findsNothing);

      await tester.tap(find.text('开始专注'));
      await tester.pump();
      final note = tester.widget<TextField>(
        find.byKey(const Key('pomodoro-remark')),
      );
      expect(note.controller?.text, isEmpty);
    },
  );

  testWidgets('refreshes remote pause and completion every 15 seconds', (
    tester,
  ) async {
    final api = _FakePomodoroApi()
      ..activeResponses.addAll([
        PomodoroSessionDto(
          id: 51,
          mode: 'MODE_25_5',
          plannedMinutes: 25,
          status: 'RUNNING',
          startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        PomodoroSessionDto(
          id: 51,
          mode: 'MODE_25_5',
          plannedMinutes: 25,
          status: 'PAUSED',
          startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          pausedAt: DateTime.now(),
        ),
        null,
      ]);
    await _pumpPage(tester, api: api);
    expect(find.text('暂停'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text('已暂停'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text('开始专注'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    expect(api.activeCalls, 3);
  });

  testWidgets('preset failure is visible and retryable', (tester) async {
    final api = _FakePomodoroApi()..presetsError = StateError('offline');
    await _pumpPage(tester, api: api);

    expect(find.textContaining('专注模式加载失败'), findsOneWidget);
    api.presetsError = null;
    await tester.tap(find.text('重试加载模式'));
    await tester.pumpAndSettle();

    expect(find.text('经典 25/5'), findsOneWidget);
  });

  testWidgets('custom minutes enforce the 1 to 1440 boundary', (tester) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('自定义'));
    await tester.pump();
    final field = find.byKey(const Key('pomodoro-custom-minutes'));

    await tester.enterText(field, '0');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '开始专注'))
          .onPressed,
      isNull,
    );
    await tester.enterText(field, '1441');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '开始专注'))
          .onPressed,
      isNull,
    );
    await tester.enterText(field, '1440');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '开始专注'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('narrow layout does not overflow at 320 logical pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(tester, api: _FakePomodoroApi());

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakePomodoroApi api,
  List<TodoTask> tasks = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pomodoroApiProvider.overrideWithValue(api),
        allTasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
      ],
      child: const MaterialApp(home: PomodoroPage()),
    ),
  );
  await tester.pumpAndSettle();
}

TodoTask _task({
  required String id,
  required String title,
  required DateTime now,
  int? serverId,
  bool completed = false,
}) {
  return TodoTask(
    id: id,
    serverId: serverId,
    listId: 'inbox',
    title: title,
    completed: completed,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    allDay: false,
    fixedTimezone: false,
    updatedAt: now,
    createdAt: now,
  );
}

class _FakePomodoroApi extends PomodoroApi {
  _FakePomodoroApi() : super(Dio());

  bool started = false;
  String? startedMode;
  int? startedMinutes;
  int? startedTaskId;
  Object? presetsError;
  Object? completeError;
  String? completedRemark;
  DateTime? completedAt;
  int activeCalls = 0;
  final List<PomodoroSessionDto?> activeResponses = [];

  @override
  Future<List<PomodoroPresetDto>> presets() async {
    if (presetsError != null) throw presetsError!;
    return const [
      PomodoroPresetDto(
        mode: 'MODE_25_5',
        label: '经典 25/5',
        focusMinutes: 25,
        breakMinutes: 5,
      ),
      PomodoroPresetDto(
        mode: 'MODE_50_10',
        label: '长专注 50/10',
        focusMinutes: 50,
        breakMinutes: 10,
      ),
      PomodoroPresetDto(mode: 'FREE', label: '自由'),
      PomodoroPresetDto(mode: 'CUSTOM', label: '自定义'),
    ];
  }

  @override
  Future<PomodoroSessionDto> start({
    int? taskId,
    String mode = 'MODE_25_5',
    int? plannedMinutes,
  }) async {
    started = true;
    startedMode = mode;
    startedMinutes = plannedMinutes;
    startedTaskId = taskId;
    return PomodoroSessionDto(
      id: 41,
      taskId: taskId,
      mode: mode,
      plannedMinutes: plannedMinutes,
      status: 'RUNNING',
      startedAt: DateTime(2026, 7, 30, 9),
    );
  }

  @override
  Future<Map<String, dynamic>> stats({String period = 'week'}) async {
    return const {'totalSessions': 0, 'totalMinutes': 0};
  }

  @override
  Future<PomodoroSessionDto?> active() async {
    activeCalls++;
    if (activeResponses.isEmpty) return null;
    return activeResponses.removeAt(0);
  }

  @override
  Future<void> complete(int id, {String? remark, DateTime? clientEndAt}) async {
    if (completeError != null) throw completeError!;
    completedRemark = remark;
    completedAt = clientEndAt;
  }

  @override
  Future<void> pause(int id) async {}

  @override
  Future<void> resume(int id) async {}

  @override
  Future<void> cancel(int id) async {}
}
