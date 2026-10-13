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

/// 嘀嗒《02-功能指南/02-日历/03-年视图：查看年度任务完成情况.md》「热力图显示」一节：
/// `:74`「年视图支持以热力图方式展示任务完成频率」、`:76`「默认情况下，热力图为关闭状态，
/// 可在显示设置中手动开启」、`:80`（mobile tab）/`:87`（desktop tab）
/// 「显示设置 → 样式 → 热力图 → 显示「热力图」」、`:98`「颜色越深，代表当天完成的任务越多」。
const _heatmapLabel = '热力图';
const _styleGroupLabel = '样式';

/// 日格 key 形态由实现约定：`calendar-year-day-<yyyy-MM-dd>`。
Key _dayKey(DateTime d) => Key(
  'calendar-year-day-'
  '${d.year.toString().padLeft(4, '0')}-'
  '${d.month.toString().padLeft(2, '0')}-'
  '${d.day.toString().padLeft(2, '0')}',
);

TodoTask _completedOn(DateTime day, int n, {String tag = 'a'}) {
  return TodoTask(
    id: '$tag-$n-${day.millisecondsSinceEpoch}',
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    timeMode: 0,
    title: '任务 $tag-$n',
    completed: true,
    cancelled: false,
    priority: 0,
    isPinned: false,
    sortOrder: 0,
    dueAt: day,
    completedAt: day,
    updatedAt: day,
    createdAt: day,
  );
}

/// 写偏好失败时界面必须保留已生效的热力图，因此需要一个会抛的仓储。
class _ThrowingRepository extends TaskViewActionRepository {
  _ThrowingRepository(super.db, super.queue);

  @override
  Future<void> saveCalendarDisplay({
    required String viewMode,
    required bool showCompletedTasks,
    required bool showHeatmap,
    String colorBy = 'priority',
  }) async {
    throw Exception('离线写入失败');
  }
}

/// 偏好读取挂起时用户可能已经拨了开关；用于验证迟到的旧值不回滚新操作。
class _SlowRepository extends TaskViewActionRepository {
  _SlowRepository(super.db, super.queue);

  final Completer<void> release = Completer<void>();

  @override
  Future<TaskWorkspacePreference> getCalendarDisplay() async {
    await release.future;
    return const TaskWorkspacePreference(
      viewType: 'year',
      showCompletedTasks: false,
      showHeatmap: false,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required TaskViewActionRepository? repository,
  List<TodoTask> tasks = const [],
  Size? surface,
  double textScale = 1.0,
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
            // 「恢复」路径不会执行 —— 验恢复必须换 key 强制重建。
            body: CalendarView(
              key: viewKey == null ? null : ValueKey<Object>(viewKey),
              tasks: tasks,
              now: DateTime(2026, 6, 15, 12),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('年'));
  await tester.pumpAndSettle();
}

Future<void> _toggleHeatmap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calendar-display-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calendar-show-heatmap')));
  await tester.pumpAndSettle();
}

/// 日格的着色浓度：key 挂在 `Semantics` 上（读屏语义与着色必须同属一个节点），
/// 所以取它内部那层 `Container` 的 `BoxDecoration.color` 的 alpha。
double? _cellFill(WidgetTester tester, DateTime day) {
  final found = find.byKey(_dayKey(day));
  if (found.evaluate().isEmpty) return null;
  final cell = find.descendant(of: found, matching: find.byType(Container));
  final decoration =
      tester.widget<Container>(cell).decoration as BoxDecoration?;
  return decoration?.color?.a;
}

void main() {
  group('calendarHeatmapLevel 纯函数（:98 颜色越深=当天完成越多）', () {
    test('完成数为 0 时是最浅档', () {
      expect(calendarHeatmapLevel(0, 5), 0);
    });

    test('档位在 0..4 内且随完成数单调不减', () {
      var previous = -1;
      for (var n = 0; n <= 20; n++) {
        final level = calendarHeatmapLevel(n, 20);
        expect(level, inInclusiveRange(0, 4), reason: 'n=$n 越界');
        expect(
          level,
          greaterThanOrEqualTo(previous),
          reason: 'n=$n 比 n=${n - 1} 还浅，单调性破了',
        );
        previous = level;
      }
    });

    test('当天完成数达到当年最大值时落在最深档', () {
      expect(calendarHeatmapLevel(20, 20), 4);
    });

    test('最大值≤0 时不抛（只有 0 完成的一年不能让除零炸掉）', () {
      expect(calendarHeatmapLevel(0, 0), 0);
      expect(calendarHeatmapLevel(3, 0), greaterThan(0));
    });

    test('稀疏年份不把唯一一次完成画成最深档', () {
      // 全年只有 1 项完成 ⇒ 那一天是「相对最忙」，但画成满格会读成「绝对很多」。
      expect(calendarHeatmapLevel(1, 1), lessThan(4));
      // 分母下限之外，达到下限的年份仍应能画到最深档。
      expect(calendarHeatmapLevel(4, 4), 4);
    });
  });

  testWidgets('默认关闭：年视图仍是 12 个月的月卡，没有按日格', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 3; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );

    // :76「默认情况下，热力图为关闭状态」⇒ 不开就没有日格。
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsNothing);
    // 正向对照：同一份数据下月卡是真的在（否则上面那条 0 命中是假阴性）。
    expect(find.text('3 月'), findsOneWidget);
    expect(find.textContaining('项任务'), findsWidgets);
  });

  testWidgets('显示设置里有「样式」分组与「热力图」开关，且默认是关', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: [],
    );
    await tester.tap(find.byKey(const Key('calendar-display-settings')));
    await tester.pumpAndSettle();

    expect(find.text(_styleGroupLabel), findsOneWidget);
    expect(find.text(_heatmapLabel), findsOneWidget);
    final switchWidget = tester.widget<SwitchListTile>(
      find.byKey(const Key('calendar-show-heatmap')),
    );
    expect(switchWidget.value, isFalse, reason: ':76 默认关闭');
    // 「显示已完成」是相邻的另一面，不能被这次改动搬走或改名。
    expect(find.byKey(const Key('calendar-show-completed')), findsOneWidget);
  });

  testWidgets('开启后出现按日热力格，深浅随当天完成数单调变深', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // 3/5 完成 3 项、3/6 完成 2 项、3/7 完成 1 项、3/8 完成 0 项。
    final tasks = <TodoTask>[
      for (var i = 0; i < 3; i++)
        _completedOn(DateTime(2026, 3, 5, 9), i, tag: 'a'),
      for (var i = 0; i < 2; i++)
        _completedOn(DateTime(2026, 3, 6, 9), i, tag: 'b'),
      _completedOn(DateTime(2026, 3, 7, 9), 0, tag: 'c'),
    ];
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    await _toggleHeatmap(tester);

    final d5 = DateTime(2026, 3, 5);
    final d6 = DateTime(2026, 3, 6);
    final d7 = DateTime(2026, 3, 7);
    final d8 = DateTime(2026, 3, 8);
    for (final d in [d5, d6, d7, d8]) {
      expect(find.byKey(_dayKey(d)), findsOneWidget, reason: '$d 该有一格');
    }
    final o5 = _cellFill(tester, d5)!;
    final o6 = _cellFill(tester, d6)!;
    final o7 = _cellFill(tester, d7)!;
    final o8 = _cellFill(tester, d8)!;
    // :98「颜色越深，代表当天完成的任务越多」
    expect(o8, lessThan(o7), reason: '0 项应比 1 项浅');
    expect(o7, lessThan(o6), reason: '1 项应比 2 项浅');
    expect(o6, lessThan(o5), reason: '2 项应比 3 项浅');
  });

  testWidgets('每个日格有独立读屏语义（日期 + 当天完成数）', (tester) async {
    final handle = tester.ensureSemantics();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    await _toggleHeatmap(tester);

    // 量带 key 节点自己的 label，不用全树 bySemanticsLabel（会被旁侧 Text 满足）。
    final semantics = tester.getSemantics(
      find.byKey(_dayKey(DateTime(2026, 3, 5))),
    );
    expect(semantics.label, contains('3 月 5 日'));
    expect(semantics.label, contains('2'));
    handle.dispose();
  });

  testWidgets('开关关掉 ⇒ 回到月卡，不留半截热力图', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    await _pump(tester, repository: repository, tasks: tasks);
    await _toggleHeatmap(tester);
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);

    await _toggleHeatmap(tester);
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsNothing);
    expect(find.text('3 月'), findsOneWidget);
    final saved = await repository.getCalendarDisplay();
    expect(saved.showHeatmap, isFalse);
  });

  testWidgets('热力图偏好落库、不改掉视图模式，重进工作区仍是开启态', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    await _pump(tester, repository: repository, tasks: tasks);
    await _toggleHeatmap(tester);

    // 模式与开关必须成对写：只写开关会把 viewType 兜底改掉用户刚选的「年」。
    final saved = await repository.getCalendarDisplay();
    expect(saved.viewType, 'year');
    expect(saved.showHeatmap, isTrue);

    // 换 key 强制重建 State：这条断言只有在恢复路径真的执行时才成立。
    await _pump(
      tester,
      repository: repository,
      tasks: tasks,
      viewKey: 'reloaded',
    );
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);
  });

  testWidgets('存盘失败时热力图仍留在界面上，并给可见提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    await _pump(
      tester,
      repository: _ThrowingRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
    );
    await _toggleHeatmap(tester);

    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);
    expect(find.textContaining('日历显示设置保存失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未配置仓储时开关仍然生效，只是不持久化', (tester) async {
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    await _pump(tester, repository: null, tasks: tasks);
    await _toggleHeatmap(tester);

    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('偏好读取在途时用户已开启热力图，迟到的旧值不得回滚', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _SlowRepository(db, SyncChangeQueue(db));
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    await _pump(tester, repository: repository, tasks: tasks);
    await _toggleHeatmap(tester);
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);

    // 迟到的旧偏好（showHeatmap: false）到达后不得关掉刚开的热力图。
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_dayKey(DateTime(2026, 3, 5))), findsOneWidget);
  });

  testWidgets('热力图数的是完成频率，不跟「显示已完成」一起被滤空', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = [
      for (var i = 0; i < 2; i++) _completedOn(DateTime(2026, 3, 5, 9), i),
    ];
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    await _pump(tester, repository: repository, tasks: tasks);
    // 「显示已完成」保持默认关闭 —— 月卡里看不到这两条已完成任务。
    expect(find.text('3 月'), findsOneWidget);
    await _toggleHeatmap(tester);

    // 若热力图沿用被过滤后的列表，这里会是全年的最浅档，功能看起来就是坏的。
    expect(_cellFill(tester, DateTime(2026, 3, 5)), greaterThan(0));
  });

  testWidgets('320px + 1.3 倍字号下开启热力图不溢出，且 12 月的日格真的被构建', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = <TodoTask>[
      for (var m = 1; m <= 12; m++)
        for (var i = 0; i < m; i++)
          _completedOn(DateTime(2026, m, 3, 9), i, tag: 'm$m'),
    ];
    await _pump(
      tester,
      repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
      tasks: tasks,
      surface: const Size(320, 700),
      textScale: 1.3,
    );
    await _toggleHeatmap(tester);

    expect(tester.takeException(), isNull);
    // 日格确实画出来了（不是"因为懒加载没建到所以没溢出"的假绿），
    // 且必须包含滚出视口的 12 月 —— 热力图排布不得依赖懒加载可见性。
    expect(find.byKey(_dayKey(DateTime(2026, 12, 3))), findsOneWidget);
    expect(find.byKey(_dayKey(DateTime(2026, 1, 3))), findsOneWidget);
  });
}
