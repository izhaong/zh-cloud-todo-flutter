import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
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
    expect(find.byKey(const Key('pomodoro-custom-minutes')), findsNothing);
    await tester.tap(find.text('开始专注'));
    await tester.pump();

    expect(api.started, isTrue);
    expect(api.startedMode, 'FREE');
    expect(api.startedMinutes, isNull);
    expect(find.text('00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
    expect(find.text('调整专注时间'), findsNothing);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('开始专注'), findsNothing);
  });

  testWidgets('stopwatch restores and counts elapsed focus time', (
    tester,
  ) async {
    final now = DateTime.now();
    final api = _FakePomodoroApi()
      ..activeResponses.addAll([
        PomodoroSessionDto(
          id: 71,
          mode: 'FREE',
          status: 'RUNNING',
          startedAt: now.subtract(const Duration(minutes: 3)),
        ),
        PomodoroSessionDto(
          id: 71,
          mode: 'FREE',
          status: 'PAUSED',
          startedAt: now.subtract(const Duration(minutes: 10)),
          pausedAt: now.subtract(const Duration(minutes: 5)),
          pausedSeconds: 120,
        ),
      ]);
    await _pumpPage(tester, api: api);

    expect(find.text('03:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:01'), findsOneWidget);

    await tester.pump(const Duration(seconds: 14));
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:00'), findsOneWidget);
  });

  testWidgets('pomodoro restoration continues to count down', (tester) async {
    final api = _FakePomodoroApi()
      ..activeResponses.add(
        PomodoroSessionDto(
          id: 72,
          mode: 'MODE_25_5',
          plannedMinutes: 25,
          status: 'RUNNING',
          startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      );
    await _pumpPage(tester, api: api);

    expect(find.text('22:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('21:59'), findsOneWidget);
  });

  testWidgets('stopwatch pause freezes and resume continues counting', (
    tester,
  ) async {
    final api = _FakePomodoroApi();
    await _pumpPage(tester, api: api);
    await tester.tap(find.text('自由'));
    await tester.pump();
    await tester.tap(find.text('开始专注'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:01'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);
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
      final initialTimelineRequests = api.timelineDates.length;
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
      expect(api.timelineDates.length, greaterThan(initialTimelineRequests));
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

  testWidgets('pending timeline does not block periodic active sync', (
    tester,
  ) async {
    final timelineResponse = Completer<List<PomodoroTimelineDto>>();
    final api = _FakePomodoroApi()
      ..timelineHandler = (_) => timelineResponse.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pump();

    expect(api.activeCalls, 1);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(api.activeCalls, 2);
    timelineResponse.complete(const []);
    await tester.pump();
  });

  testWidgets(
    'timer cards start a server timer without blocking session sync',
    (tester) async {
      final api = _FakePomodoroApi()
        ..timerValues = const [
          PomodoroTimerDto(id: 10, name: '晨间阅读', mode: 'FREE', habitId: 20),
        ];
      await _pumpPage(
        tester,
        api: api,
        habits: [HabitDto(id: 20, name: '阅读')],
      );

      expect(find.text('常用专注'), findsOneWidget);
      expect(find.text('晨间阅读'), findsOneWidget);
      expect(find.text('关联习惯：阅读'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('开始晨间阅读，正计时'));
      await tester.pump();

      expect(api.startedTimerIds, [10]);
      await tester.scrollUntilVisible(
        find.text('暂停'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('暂停'), findsOneWidget);
    },
  );

  testWidgets('pending timer list does not block periodic active sync', (
    tester,
  ) async {
    final timerResponse = Completer<List<PomodoroTimerDto>>();
    final api = _FakePomodoroApi()..timersHandler = (_) => timerResponse.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pump();

    expect(api.activeCalls, 1);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(api.activeCalls, 2);
    timerResponse.complete(const []);
    await tester.pump();
  });

  testWidgets('failed timer start keeps the last successful timer list', (
    tester,
  ) async {
    final api = _FakePomodoroApi()
      ..timerValues = const [
        PomodoroTimerDto(
          id: 10,
          name: '深度工作',
          mode: 'CUSTOM',
          focusMinutes: 45,
        ),
      ]
      ..timerStartError = StateError('offline');
    await _pumpPage(tester, api: api);

    await tester.tap(find.bySemanticsLabel('开始深度工作，45 分钟'));
    await tester.pump();

    expect(find.text('深度工作'), findsOneWidget);
    expect(find.textContaining('计时器启动失败'), findsOneWidget);
  });

  testWidgets(
    'timer editor validates modes associations and lifecycle actions',
    (tester) async {
      final api = _FakePomodoroApi();
      await _pumpPage(
        tester,
        api: api,
        habits: [HabitDto(id: 20, name: '阅读')],
      );

      await tester.tap(find.byTooltip('新增常用专注计时器'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存计时器'));
      await tester.pump();
      expect(find.text('名称需为 1–64 个字符'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-name')),
        List.filled(65, '字').join(),
      );
      await tester.tap(find.text('保存计时器'));
      await tester.pump();
      expect(find.text('名称需为 1–64 个字符'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-name')),
        '  最小番茄  ',
      );
      await tester.tap(find.byKey(const Key('pomodoro-timer-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义番茄').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-minutes')),
        '0',
      );
      await tester.tap(find.text('保存计时器'));
      await tester.pump();
      expect(find.text('分钟数必须在 1–1440 之间'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-minutes')),
        '1',
      );
      await tester.tap(find.byKey(const Key('pomodoro-timer-association')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('习惯：阅读').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存计时器'));
      await tester.pumpAndSettle();

      expect(api.lastCreatedTimerName, '最小番茄');
      expect(api.lastCreatedTimerMode, 'CUSTOM');
      expect(api.lastCreatedTimerMinutes, 1);
      expect(api.lastCreatedTimerHabitId, 20);
      expect(api.lastCreatedTimerTaskId, isNull);
      expect(find.text('最小番茄'), findsOneWidget);

      await tester.tap(find.byTooltip('新增常用专注计时器'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-name')),
        '最大番茄',
      );
      await tester.tap(find.byKey(const Key('pomodoro-timer-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义番茄').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-minutes')),
        '1441',
      );
      await tester.tap(find.text('保存计时器'));
      await tester.pump();
      expect(find.text('分钟数必须在 1–1440 之间'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-minutes')),
        '1440',
      );
      await tester.tap(find.text('保存计时器'));
      await tester.pumpAndSettle();
      expect(api.lastCreatedTimerMinutes, 1440);

      await tester.tap(find.byTooltip('新增常用专注计时器'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-name')),
        '自由写作',
      );
      await tester.tap(find.byKey(const Key('pomodoro-timer-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('正计时').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pomodoro-timer-minutes')), findsNothing);
      await tester.tap(find.text('保存计时器'));
      await tester.pumpAndSettle();
      expect(api.lastCreatedTimerMode, 'FREE');
      expect(api.lastCreatedTimerMinutes, isNull);
    },
  );

  testWidgets(
    'timer edit archive restore and delete preserve confirmed state',
    (tester) async {
      final api = _FakePomodoroApi()
        ..timerValues = const [
          PomodoroTimerDto(
            id: 10,
            name: '深度工作',
            mode: 'CUSTOM',
            focusMinutes: 45,
          ),
        ];
      await _pumpPage(tester, api: api);

      await tester.tap(find.byKey(const Key('pomodoro-timer-menu-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pomodoro-timer-name')),
        '深度写作',
      );
      await tester.tap(find.text('保存计时器'));
      await tester.pumpAndSettle();
      expect(api.lastUpdatedTimerName, '深度写作');
      expect(find.text('深度写作'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pomodoro-timer-menu-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档'));
      await tester.pumpAndSettle();
      expect(find.textContaining('历史专注记录会保留'), findsOneWidget);
      await tester.tap(find.text('确认归档'));
      await tester.pumpAndSettle();
      expect(api.archivedTimerActions, [(10, true)]);
      expect(find.text('深度写作'), findsNothing);

      await tester.tap(find.byTooltip('查看已归档计时器'));
      await tester.pumpAndSettle();
      expect(find.text('深度写作'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pomodoro-timer-menu-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();
      expect(find.textContaining('历史专注记录会保留'), findsOneWidget);
      await tester.tap(find.text('确认恢复'));
      await tester.pumpAndSettle();
      expect(api.archivedTimerActions.last, (10, false));

      await tester.tap(find.byTooltip('查看使用中的计时器'));
      await tester.pumpAndSettle();
      api.timerDeleteError = StateError('offline');
      await tester.tap(find.byKey(const Key('pomodoro-timer-menu-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('历史专注记录会保留'), findsOneWidget);
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(find.text('深度写作'), findsOneWidget);
      expect(find.textContaining('计时器删除失败'), findsOneWidget);
    },
  );

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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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

  testWidgets('switches among day week and month statistics', (tester) async {
    final api = _FakePomodoroApi()
      ..statsByPeriod['week'] = _stats(totalMinutes: 70, days: 7)
      ..statsByPeriod['month'] = _stats(totalMinutes: 300, days: 30);
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(api.statsPeriods, ['week']);
    await tester.tap(find.text('30 天'));
    await tester.pump();

    expect(api.statsPeriods.last, 'month');
    expect(
      find.descendant(
        of: find.byKey(const Key('pomodoro-stats-total-minutes')),
        matching: find.text('300'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('older statistics response cannot replace selected period', (
    tester,
  ) async {
    final week = Completer<PomodoroStatsDto>();
    final month = Completer<PomodoroStatsDto>();
    final api = _FakePomodoroApi()
      ..statsHandler = (period) =>
          period == 'month' ? month.future : week.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('30 天'));
    await tester.pump();

    month.complete(_stats(totalMinutes: 300, days: 30));
    await tester.pump();
    week.complete(_stats(totalMinutes: 70, days: 7));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('pomodoro-stats-total-minutes')),
        matching: find.text('300'),
      ),
      findsOneWidget,
    );
    expect(find.text('70'), findsNothing);
  });

  testWidgets('slow period switch labels retained statistics source', (
    tester,
  ) async {
    final month = Completer<PomodoroStatsDto>();
    final api = _FakePomodoroApi()
      ..statsByPeriod['week'] = _stats(totalMinutes: 70, days: 7);
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    api.statsHandler = (_) => month.future;

    await tester.tap(find.text('30 天'));
    await tester.pump();

    expect(find.text('正在加载 30 天，暂显示 7 天结果'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pomodoro-stats-total-minutes')),
        matching: find.text('70'),
      ),
      findsOneWidget,
    );

    month.complete(_stats(totalMinutes: 300, days: 30));
    await tester.pump();
    expect(
      find.byKey(const Key('pomodoro-stats-data-period-note')),
      findsNothing,
    );
  });

  testWidgets('statistics failure keeps last success and retries', (
    tester,
  ) async {
    final api = _FakePomodoroApi()
      ..statsByPeriod['week'] = _stats(totalMinutes: 70, days: 7);
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    api.statsError = StateError('offline');

    await tester.tap(find.text('今天'));
    await tester.pump();

    expect(find.textContaining('统计加载失败'), findsOneWidget);
    expect(find.text('暂未更新到今天，暂显示 7 天结果'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pomodoro-stats-total-minutes')),
        matching: find.text('70'),
      ),
      findsOneWidget,
    );

    api.statsError = null;
    api.statsByPeriod['day'] = _stats(totalMinutes: 25, days: 1);
    await tester.tap(find.text('重试加载统计'));
    await tester.pump();

    expect(api.statsPeriods.last, 'day');
    expect(find.textContaining('统计加载失败'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('pomodoro-stats-total-minutes')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('first statistics failure does not invent zero metrics', (
    tester,
  ) async {
    final api = _FakePomodoroApi()..statsError = StateError('offline');
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('统计加载失败'), findsOneWidget);
    expect(
      find.byKey(const Key('pomodoro-stats-total-sessions')),
      findsNothing,
    );
    expect(find.byKey(const Key('pomodoro-stats-total-minutes')), findsNothing);
    expect(find.text('重试加载统计'), findsOneWidget);
  });

  testWidgets('trend bars expose date and minute semantics', (tester) async {
    final api = _FakePomodoroApi()
      ..statsByPeriod['week'] = const PomodoroStatsDto(
        totalSessions: 1,
        totalMinutes: 45,
        bestHour: '09:00',
        sessionTrend: [PomodoroDailyStatsDto(date: '2026-08-02', count: 1)],
        minutesTrend: [PomodoroDailyStatsDto(date: '2026-08-02', count: 45)],
      );
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.bySemanticsLabel('2026-08-02 专注 45 分钟'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-08-02 专注日历 45 分钟'), findsOneWidget);
  });

  testWidgets(
    'year statistics use month labels and task distribution semantics',
    (tester) async {
      final api = _FakePomodoroApi()
        ..statsByPeriod['year'] = const PomodoroStatsDto(
          totalSessions: 3,
          totalMinutes: 90,
          bestHour: '09:00',
          sessionTrend: [
            PomodoroDailyStatsDto(date: '2025-09', count: 1),
            PomodoroDailyStatsDto(date: '2026-08', count: 2),
          ],
          minutesTrend: [
            PomodoroDailyStatsDto(date: '2025-09', count: 30),
            PomodoroDailyStatsDto(date: '2026-08', count: 60),
          ],
          taskDistribution: [
            PomodoroTaskDistributionDto(
              taskId: 101,
              taskTitle: '工作报告',
              minutes: 60,
              sessions: 2,
            ),
            PomodoroTaskDistributionDto(
              taskTitle: '未分类',
              minutes: 30,
              sessions: 1,
            ),
          ],
        );
      await _pumpPage(tester, api: api);
      await tester.scrollUntilVisible(
        find.byKey(const Key('pomodoro-stats-section')),
        240,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('12 个月'));
      await tester.pump();

      expect(api.statsPeriods.last, 'year');
      expect(find.text('25/09'), findsOneWidget);
      expect(find.text('26/08'), findsOneWidget);
      expect(find.text('月均专注'), findsOneWidget);
      expect(find.text('专注日历'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pomodoro-task-distribution-semantics-101')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.bySemanticsLabel('工作报告，专注 60 分钟，2 次会话'), findsOneWidget);
      expect(find.bySemanticsLabel('未分类，专注 30 分钟，1 次会话'), findsOneWidget);
    },
  );

  testWidgets('older timeline response cannot replace selected date', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final previous = today.subtract(const Duration(days: 1));
    final todayResponse = Completer<List<PomodoroTimelineDto>>();
    final previousResponse = Completer<List<PomodoroTimelineDto>>();
    final api = _FakePomodoroApi()
      ..timelineHandler = (date) => DateUtils.isSameDay(date, previous)
          ? previousResponse.future
          : todayResponse.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-timeline-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('pomodoro-timeline-previous')));
    await tester.pump();
    previousResponse.complete([
      _timeline(id: 72, date: previous, title: '昨日专注'),
    ]);
    await tester.pump();
    todayResponse.complete([_timeline(id: 71, date: today, title: '今日旧响应')]);
    await tester.pump();

    expect(find.text('昨日专注'), findsOneWidget);
    expect(find.text('今日旧响应'), findsNothing);
  });

  testWidgets('timeline failure keeps last success and retries selected date', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final previous = today.subtract(const Duration(days: 1));
    final api = _FakePomodoroApi()
      ..timelineByDate[_dateKey(today)] = [
        _timeline(id: 71, date: today, title: '今日专注'),
      ];
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-timeline-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    api.timelineError = StateError('offline');

    await tester.tap(find.byKey(const Key('pomodoro-timeline-previous')));
    await tester.pump();

    expect(find.textContaining('时间轴加载失败'), findsOneWidget);
    expect(find.text('今日专注'), findsOneWidget);
    expect(
      find.byKey(const Key('pomodoro-timeline-data-date-note')),
      findsOneWidget,
    );

    api.timelineError = null;
    api.timelineByDate[_dateKey(previous)] = [
      _timeline(id: 72, date: previous, title: '昨日重试成功'),
    ];
    await tester.scrollUntilVisible(
      find.text('重试加载时间轴'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.text('重试加载时间轴'));
    await tester.pump();

    expect(api.timelineDates.last, previous);
    expect(find.text('昨日重试成功'), findsOneWidget);
    expect(find.textContaining('时间轴加载失败'), findsNothing);
    expect(
      find.byKey(const Key('pomodoro-timeline-data-date-note')),
      findsNothing,
    );
  });

  testWidgets('timeline items expose time task minutes and mode semantics', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final api = _FakePomodoroApi()
      ..timelineByDate[_dateKey(today)] = [
        _timeline(id: 73, date: today, title: '工作报告'),
      ];
    await _pumpPage(tester, api: api);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pomodoro-timeline-73')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('09:00–09:25，工作报告，专注 25 分钟，经典 25/5'),
      findsOneWidget,
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
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pomodoro-stats-section')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}

PomodoroStatsDto _stats({required int totalMinutes, required int days}) {
  return PomodoroStatsDto(
    totalSessions: days,
    totalMinutes: totalMinutes,
    bestHour: '09:00',
    sessionTrend: List.generate(
      days,
      (index) => PomodoroDailyStatsDto(
        date: '2026-08-${(index + 1).toString().padLeft(2, '0')}',
        count: 1,
      ),
    ),
    minutesTrend: List.generate(
      days,
      (index) => PomodoroDailyStatsDto(
        date: '2026-08-${(index + 1).toString().padLeft(2, '0')}',
        count: totalMinutes ~/ days,
      ),
    ),
  );
}

PomodoroTimelineDto _timeline({
  required int id,
  required DateTime date,
  required String title,
}) {
  return PomodoroTimelineDto(
    id: id,
    taskTitle: title,
    mode: 'MODE_25_5',
    startedAt: DateTime(date.year, date.month, date.day, 9),
    endedAt: DateTime(date.year, date.month, date.day, 9, 25),
    actualMinutes: 25,
  );
}

String _dateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakePomodoroApi api,
  List<TodoTask> tasks = const [],
  List<HabitDto> habits = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pomodoroApiProvider.overrideWithValue(api),
        allTasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
        myHabitsProvider.overrideWith((ref) async => habits),
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
  Object? statsError;
  Object? timelineError;
  Future<PomodoroStatsDto> Function(String period)? statsHandler;
  Future<List<PomodoroTimelineDto>> Function(DateTime date)? timelineHandler;
  PomodoroStatsDto statsValue = const PomodoroStatsDto.empty();
  final Map<String, PomodoroStatsDto> statsByPeriod = {};
  final List<String> statsPeriods = [];
  final List<DateTime> timelineDates = [];
  final Map<String, List<PomodoroTimelineDto>> timelineByDate = {};
  String? completedRemark;
  DateTime? completedAt;
  int activeCalls = 0;
  int pageCalls = 0;
  List<int> adjustDeltas = [];
  List<int> backfillMinutes = [];
  List<(int, int)> updatedDurations = [];
  List<PomodoroSessionDto> records = [];
  final List<PomodoroSessionDto?> activeResponses = [];
  List<PomodoroTimerDto> timerValues = const [];
  Future<List<PomodoroTimerDto>> Function(bool archived)? timersHandler;
  Object? timerStartError;
  Object? timerDeleteError;
  final List<int> startedTimerIds = [];
  final List<(int, bool)> archivedTimerActions = [];
  String? lastCreatedTimerName;
  String? lastCreatedTimerMode;
  int? lastCreatedTimerMinutes;
  int? lastCreatedTimerTaskId;
  int? lastCreatedTimerHabitId;
  String? lastUpdatedTimerName;

  @override
  Future<List<PomodoroTimerDto>> timers({bool archived = false}) async {
    final handler = timersHandler;
    if (handler != null) return handler(archived);
    return timerValues.where((timer) => timer.archived == archived).toList();
  }

  @override
  Future<PomodoroSessionDto> startTimer(int id) async {
    if (timerStartError != null) throw timerStartError!;
    startedTimerIds.add(id);
    final timer = timerValues.singleWhere((value) => value.id == id);
    return PomodoroSessionDto(
      id: 41,
      timerId: id,
      taskId: timer.taskId,
      habitId: timer.habitId,
      mode: timer.mode,
      plannedMinutes: timer.focusMinutes,
      status: 'RUNNING',
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<int> createTimer({
    required String name,
    required String mode,
    int? focusMinutes,
    int? taskId,
    int? habitId,
    int sortOrder = 0,
  }) async {
    lastCreatedTimerName = name;
    lastCreatedTimerMode = mode;
    lastCreatedTimerMinutes = focusMinutes;
    lastCreatedTimerTaskId = taskId;
    lastCreatedTimerHabitId = habitId;
    final id = timerValues.isEmpty
        ? 10
        : timerValues.map((timer) => timer.id).reduce((a, b) => a > b ? a : b) +
              1;
    timerValues = [
      ...timerValues,
      PomodoroTimerDto(
        id: id,
        name: name,
        mode: mode,
        focusMinutes: focusMinutes,
        taskId: taskId,
        habitId: habitId,
        sortOrder: sortOrder,
      ),
    ];
    return id;
  }

  @override
  Future<void> updateTimer(
    int id, {
    required String name,
    required String mode,
    int? focusMinutes,
    int? taskId,
    int? habitId,
    int sortOrder = 0,
  }) async {
    lastUpdatedTimerName = name;
    timerValues = timerValues
        .map(
          (timer) => timer.id == id
              ? PomodoroTimerDto(
                  id: id,
                  name: name,
                  mode: mode,
                  focusMinutes: focusMinutes,
                  taskId: taskId,
                  habitId: habitId,
                  sortOrder: sortOrder,
                  archived: timer.archived,
                )
              : timer,
        )
        .toList();
  }

  @override
  Future<void> setTimerArchived(int id, bool archived) async {
    archivedTimerActions.add((id, archived));
    timerValues = timerValues
        .map(
          (timer) => timer.id == id
              ? PomodoroTimerDto(
                  id: timer.id,
                  name: timer.name,
                  mode: timer.mode,
                  focusMinutes: timer.focusMinutes,
                  taskId: timer.taskId,
                  habitId: timer.habitId,
                  sortOrder: timer.sortOrder,
                  archived: archived,
                )
              : timer,
        )
        .toList();
  }

  @override
  Future<void> deleteTimer(int id) async {
    if (timerDeleteError != null) throw timerDeleteError!;
    timerValues = timerValues.where((timer) => timer.id != id).toList();
  }

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
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<PomodoroStatsDto> stats({String period = 'week'}) async {
    statsPeriods.add(period);
    if (statsError != null) throw statsError!;
    final handler = statsHandler;
    if (handler != null) return handler(period);
    return statsByPeriod[period] ?? statsValue;
  }

  @override
  Future<List<PomodoroTimelineDto>> timeline({required DateTime date}) async {
    final normalized = DateUtils.dateOnly(date);
    timelineDates.add(normalized);
    if (timelineError != null) throw timelineError!;
    final handler = timelineHandler;
    if (handler != null) return handler(normalized);
    return timelineByDate[_dateKey(normalized)] ?? const [];
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
