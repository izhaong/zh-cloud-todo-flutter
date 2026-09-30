import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

final _now = DateTime(2026, 6, 15, 12);

/// 日程模式只渲染锚点当天，任务必须落在这一天。
final _anchorDay = DateTime(2026, 6, 15, 9);

TodoTask _task({required String id, required bool completed, DateTime? dueAt}) {
  return TodoTask(
    id: id,
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    title: '任务 $id',
    completed: completed,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    startAt: null,
    endAt: null,
    dueAt: dueAt ?? DateTime(2026, 6, 20, 9),
    updatedAt: _now,
    createdAt: _now,
  );
}

/// 写偏好失败时页面必须保持已生效的状态并给出提示，因此需要一个会抛的仓储。
class _ThrowingRepository extends TaskViewActionRepository {
  _ThrowingRepository(super.db, super.queue);

  @override
  Future<void> saveCalendarDisplay({
    required String viewMode,
    required bool showCompletedTasks,
    required bool showHeatmap,
  }) async {
    throw Exception('离线写入失败');
  }
}

/// 偏好读取挂起时用户可能已经动过视图；用于验证迟到的旧值不回滚新操作。
class _SlowRepository extends TaskViewActionRepository {
  _SlowRepository(super.db, super.queue);

  final Completer<void> release = Completer<void>();

  @override
  Future<TaskWorkspacePreference> getCalendarDisplay() async {
    await release.future;
    return const TaskWorkspacePreference(
      viewType: 'month',
      showCompletedTasks: false,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required TaskViewActionRepository? repository,
  List<TodoTask> tasks = const [],
  Size? surface,
  double textScale = 1.0,
  bool filterCompleted = true,
  Object? viewKey,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskViewActionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            // 不传 key 时第二次 pump 会复用同一个 State，initState 不重跑，
            // 「恢复」路径根本不会执行 —— 验恢复必须换 key 强制重建。
            body: CalendarView(
              key: viewKey == null ? null : ValueKey<Object>(viewKey),
              tasks: tasks,
              now: _now,
              filterCompleted: filterCompleted,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleShowCompleted(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calendar-display-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calendar-show-completed')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('已完成任务默认不出现在日历，开启「显示已完成」后出现', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      _task(id: 'a', completed: false),
      _task(id: 'b', completed: true),
    ];
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );

    // 月模式当天只显示未完成的那一条。
    expect(find.text('1 项'), findsOneWidget);

    await _toggleShowCompleted(tester);
    expect(find.text('2 项'), findsOneWidget);
  });

  testWidgets('开关与视图模式同行持久化：重进页面恢复，且写开关不会改掉视图模式', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    final tasks = [
      _task(id: 'a', completed: false),
      _task(id: 'b', completed: true),
    ];
    await _pump(tester, repository: repository, tasks: tasks);

    await _toggleShowCompleted(tester);
    expect(find.text('2 项'), findsOneWidget);
    // 单写开关时偏好层会把缺失的 viewType 兜底成 list，这里必须仍是月模式。
    final saved = await repository.getCalendarDisplay();
    expect(saved.viewType, 'month');
    expect(saved.showCompletedTasks, isTrue);

    // 换 key 强制重建 State，否则验的是内存态而不是恢复路径。
    await _pump(
      tester,
      repository: repository,
      tasks: tasks,
      viewKey: 'reloaded',
    );
    expect(find.text('2 项'), findsOneWidget);
  });

  testWidgets('切到日程模式后再写开关，两个字段一起落库并在重进时恢复', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'a', completed: true, dueAt: _anchorDay)],
    );

    await tester.tap(find.text('日程'));
    await tester.pumpAndSettle();
    await _toggleShowCompleted(tester);

    final saved = await repository.getCalendarDisplay();
    expect(saved.viewType, 'agenda');
    expect(saved.showCompletedTasks, isTrue);

    // 日程模式只渲染锚点当天，已完成项在开启后应直接出现在这一天上。
    // 换 key 强制重建 State：这条断言只有在恢复路径真的执行时才成立。
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'a', completed: true, dueAt: _anchorDay)],
      viewKey: 'reloaded',
    );
    expect(find.text('2026 年 6 月 15 日'), findsOneWidget);
    expect(find.text('任务 a'), findsOneWidget);
  });

  testWidgets('写偏好失败时保留已生效的开关状态并提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      _task(id: 'a', completed: false),
      _task(id: 'b', completed: true),
    ];
    await _pump(
      tester,
      repository: _ThrowingRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );

    await _toggleShowCompleted(tester);

    expect(find.text('2 项'), findsOneWidget);
    expect(find.textContaining('日历显示设置保存失败'), findsOneWidget);
  });

  testWidgets('未配置仓储时开关仍然生效，只是不持久化', (tester) async {
    final tasks = [
      _task(id: 'a', completed: false),
      _task(id: 'b', completed: true),
    ];
    await _pump(tester, repository: null, tasks: tasks);

    expect(find.text('1 项'), findsOneWidget);
    await _toggleShowCompleted(tester);
    expect(find.text('2 项'), findsOneWidget);
  });

  testWidgets('宿主自行决定已完成显隐时，日历不再叠加过滤也不给空操作入口', (tester) async {
    // 未启用语义树时 bySemanticsLabel 恒 0 命中，这条断言会空转 —— 必须开语义再断言。
    final handle = tester.ensureSemantics();
    // 清单页的日历由清单筛选决定：这里直接验证宿主传参后的两条契约。
    await _pump(
      tester,
      repository: null,
      tasks: [
        _task(id: 'a', completed: false),
        _task(id: 'b', completed: true),
      ],
      filterCompleted: false,
    );

    // 已完成项没有被隐藏（否则清单筛「只看已完成」切到日历会被叠成空列表）。
    expect(find.text('2 项'), findsOneWidget);
    // 「显示已完成」在这个上下文里改了也没有可见效果，入口不得渲染。
    expect(find.byKey(const Key('calendar-display-settings')), findsNothing);
    expect(find.bySemanticsLabel('显示设置'), findsNothing);
    handle.dispose();
  });

  testWidgets('偏好读取在途时用户已切换视图，迟到的旧值不得回滚', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _SlowRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'a', completed: true, dueAt: _anchorDay)],
    );

    // 恢复请求仍挂着，用户先把视图切到日程。
    await tester.tap(find.text('日程'));
    await tester.pump();
    expect(find.text('2026 年 6 月 15 日'), findsOneWidget);

    // 迟到的旧偏好（month）到达后不得覆盖用户刚做的那次切换。
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('2026 年 6 月 15 日'), findsOneWidget);
    expect(find.text('2026 年 6 月'), findsNothing);
  });

  testWidgets('320px 与 1.3 倍字体下入口与开关无溢出且可读屏', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: [_task(id: 'a', completed: false)],
      surface: const Size(320, 700),
      textScale: 1.3,
    );

    expect(
      find.bySemanticsLabel('显示设置'),
      findsOneWidget,
      reason: '入口必须有独立可读屏语义，不能只有一个图标',
    );

    await tester.tap(find.byKey(const Key('calendar-display-settings')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('显示已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);

    handle.dispose();
  });
}
