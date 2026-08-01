import 'dart:async';

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

  testWidgets('active duration changes only after adjust succeeds', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('pomodoro-adjust-plus')));
    await tester.pump();
    expect(api.adjustDeltas, [5]);
    expect(find.text('30:00'), findsOneWidget);

    api.adjustError = StateError('offline');
    await tester.tap(find.byKey(const Key('pomodoro-adjust-minus')));
    await tester.pump();
    expect(find.textContaining('调整失败'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
  });

  testWidgets('periodic sync cannot overwrite an in-flight adjustment', (
    tester,
  ) async {
    final completer = Completer<int>();
    final api = _FakePomodoroApi()..adjustCompleter = completer;
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('pomodoro-adjust-plus')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(api.activeCalls, 1);

    completer.complete(30);
    await tester.pumpAndSettle();
    expect(find.text('29:45'), findsOneWidget);
  });

  testWidgets('shows real records and appends five minutes', (tester) async {
    final api = _FakePomodoroApi()
      ..records = [
        PomodoroSessionDto(
          id: 61,
          taskId: 81,
          mode: 'CUSTOM',
          plannedMinutes: 40,
          actualMinutes: 40,
          status: 'COMPLETED',
          startedAt: DateTime(2026, 8, 2, 9),
          endedAt: DateTime(2026, 8, 2, 9, 40),
          remark: '完成评审',
        ),
      ];
    await _pumpPage(
      tester,
      api: api,
      tasks: [
        _task(
          id: 'synced',
          serverId: 81,
          title: '发布准备',
          now: DateTime(2026, 8, 2),
        ),
      ],
    );

    expect(find.text('完成评审'), findsOneWidget);
    expect(find.textContaining('发布准备'), findsOneWidget);
    api.pageError = StateError('refresh offline');
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-record-add-61')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pomodoro-record-add-61')));
    await tester.pump();

    expect(api.updatedDurations, [(61, 45)]);
    expect(api.pageCalls, greaterThanOrEqualTo(2));
    expect(find.text('完成评审'), findsOneWidget);
    expect(find.textContaining('40 分钟'), findsOneWidget);
    expect(find.textContaining('记录加载失败'), findsOneWidget);
  });

  testWidgets('edits completed record duration within bounds', (tester) async {
    final api = _FakePomodoroApi()
      ..records = [
        PomodoroSessionDto(
          id: 65,
          mode: 'CUSTOM',
          actualMinutes: 40,
          status: 'COMPLETED',
          remark: '需要校准',
        ),
      ];
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-record-edit-65')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pomodoro-record-edit-65')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pomodoro-record-duration')),
      '55',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(api.updatedDurations, [(65, 55)]);
    expect(find.textContaining('55 分钟'), findsOneWidget);
  });

  testWidgets('backfill accepts the zero-minute lower boundary', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('新增记录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pomodoro-backfill-minutes')),
      '0',
    );
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(api.backfillMinutes, [0]);
    expect(find.text('新增专注记录'), findsNothing);
  });

  testWidgets('backfill failure keeps dialog input for retry', (tester) async {
    final api = _FakePomodoroApi()..backfillError = StateError('offline');
    await _pumpPage(tester, api: api);

    await tester.tap(find.text('新增记录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pomodoro-backfill-minutes')),
      '40',
    );
    await tester.enterText(
      find.byKey(const Key('pomodoro-backfill-remark')),
      '保留这段文字',
    );
    await tester.tap(find.text('保存记录'));
    await tester.pump();

    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pomodoro-backfill-remark')))
          .controller
          ?.text,
      '保留这段文字',
    );
  });

  testWidgets('delete failure keeps confirmed record visible', (tester) async {
    final api = _FakePomodoroApi()
      ..deleteError = StateError('offline')
      ..records = [
        PomodoroSessionDto(
          id: 62,
          mode: 'MODE_25_5',
          actualMinutes: 25,
          status: 'COMPLETED',
          startedAt: DateTime(2026, 8, 2, 10),
          endedAt: DateTime(2026, 8, 2, 10, 25),
          remark: '不能丢失',
        ),
      ];
    await _pumpPage(tester, api: api);

    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-record-delete-62')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pomodoro-record-delete-62')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pump();

    expect(find.textContaining('删除失败'), findsOneWidget);
    expect(find.text('不能丢失'), findsOneWidget);
  });

  testWidgets('record load failure is retryable', (tester) async {
    final api = _FakePomodoroApi()..pageError = StateError('offline');
    await _pumpPage(tester, api: api);

    expect(find.textContaining('记录加载失败'), findsOneWidget);
    api.pageError = null;
    api.records = [
      PomodoroSessionDto(
        id: 63,
        mode: 'FREE',
        actualMinutes: 18,
        status: 'COMPLETED',
        remark: '重试成功',
      ),
    ];
    await tester.tap(find.text('重试加载记录'));
    await tester.pumpAndSettle();

    expect(find.text('重试成功'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('新增记录'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增记录'));
    await tester.pumpAndSettle();
    expect(find.text('新增专注记录'), findsOneWidget);
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
  Object? adjustError;
  Completer<int>? adjustCompleter;
  Object? backfillError;
  Object? updateDurationError;
  Object? deleteError;
  Object? pageError;
  String? completedRemark;
  DateTime? completedAt;
  int activeCalls = 0;
  int pageCalls = 0;
  List<int> adjustDeltas = [];
  List<int> backfillMinutes = [];
  List<(int, int)> updatedDurations = [];
  List<PomodoroSessionDto> records = [];
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

  @override
  Future<int> adjust(int id, {required int deltaMinutes}) async {
    if (adjustError != null) throw adjustError!;
    final pending = adjustCompleter;
    if (pending != null) return pending.future;
    adjustDeltas.add(deltaMinutes);
    final current = startedMinutes ?? 25;
    startedMinutes = current + deltaMinutes;
    return startedMinutes!;
  }

  @override
  Future<int> backfill({
    int? taskId,
    required String mode,
    required int actualMinutes,
    required DateTime startedAt,
    required DateTime endedAt,
    String? remark,
  }) async {
    if (backfillError != null) throw backfillError!;
    backfillMinutes.add(actualMinutes);
    return 64;
  }

  @override
  Future<List<PomodoroSessionDto>> page({
    String? status,
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    pageCalls++;
    if (pageError != null) throw pageError!;
    return records;
  }

  @override
  Future<void> updateDuration(int id, {required int actualMinutes}) async {
    if (updateDurationError != null) throw updateDurationError!;
    updatedDurations.add((id, actualMinutes));
    records = records
        .map(
          (record) => record.id == id
              ? record.copyWith(actualMinutes: actualMinutes)
              : record,
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteRecord(int id) async {
    if (deleteError != null) throw deleteError!;
    records = records.where((record) => record.id != id).toList();
  }
}
