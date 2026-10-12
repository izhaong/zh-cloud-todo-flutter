import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/task_view_mode_tabs.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

/// M11-B3 c3 测试：四象限 Eisenhower 分类纯函数 + 视图 tab 渲染。
void main() {
  group('classifyEisenhower', () {
    final now = DateTime(2026, 6, 20, 12, 0, 0);

    TodoTask build({
      int priority = 0,
      DateTime? dueAt,
      bool completed = false,
    }) {
      return TodoTask(
        id: '1',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        title: 't',
        completed: completed,
        cancelled: false,
        priority: priority,
        isPinned: false,
        sortOrder: 0,
        startAt: null,
        endAt: null,
        dueAt: dueAt,
        updatedAt: now,
        createdAt: now,
      );
    }

    test('Q1: priority>=2 且 due 在 24h 内', () {
      final t = build(priority: 2, dueAt: now.add(const Duration(hours: 6)));
      expect(classifyEisenhower(t, now), Quadrant.q1);
    });

    test('Q1: priority>=2 且 due 已过期', () {
      final t = build(
        priority: 3,
        dueAt: now.subtract(const Duration(hours: 1)),
      );
      expect(classifyEisenhower(t, now), Quadrant.q1);
    });

    test('Q2: priority>=2 且 due > 24h', () {
      final t = build(priority: 2, dueAt: now.add(const Duration(days: 3)));
      expect(classifyEisenhower(t, now), Quadrant.q2);
    });

    test('Q2: priority>=2 且 无 due', () {
      final t = build(priority: 2);
      expect(classifyEisenhower(t, now), Quadrant.q2);
    });

    test('Q3: priority<2 且 due 在 24h 内', () {
      final t = build(priority: 1, dueAt: now.add(const Duration(hours: 2)));
      expect(classifyEisenhower(t, now), Quadrant.q3);
    });

    test('Q4: priority<2 且无 due', () {
      final t = build(priority: 0);
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });

    test('Q4: priority<2 且 due > 24h', () {
      final t = build(priority: 1, dueAt: now.add(const Duration(days: 5)));
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });

    test('Q4: 已完成任务', () {
      final t = build(priority: 2, dueAt: now, completed: true);
      expect(classifyEisenhower(t, now), Quadrant.q4);
    });
  });

  testWidgets('TaskViewModeTabs 渲染 5 个 tab 并触发 onChanged', (tester) async {
    TaskViewMode? changed;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TaskViewModeTabs(
              mode: TaskViewMode.list,
              onChanged: (m) => changed = m,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('列表'), findsWidgets);
    expect(find.text('看板'), findsOneWidget);
    expect(find.text('四象限'), findsOneWidget);

    // 点击"四象限"切换
    await tester.tap(find.text('四象限'));
    await tester.pumpAndSettle();
    expect(changed, TaskViewMode.eisenhower);
  });

  testWidgets('TaskViewModeTabs 只回调父组件且不直接写同步队列', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    TaskViewMode? changed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: TaskViewModeTabs(
              mode: TaskViewMode.list,
              onChanged: (mode) => changed = mode,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('看板'));
    await tester.pumpAndSettle();

    expect(changed, TaskViewMode.kanban);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  testWidgets('EisenhowerView 4 象限渲染', (tester) async {
    final now = DateTime(2026, 6, 20, 12, 0, 0);
    final tasks = <TodoTask>[
      TodoTask(
        id: '1',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        title: '紧急且重要',
        priority: 2,
        isPinned: false,
        sortOrder: 0,
        completed: false,
        cancelled: false,
        dueAt: now.add(const Duration(hours: 1)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: '2',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        title: '重要不紧急',
        priority: 3,
        isPinned: false,
        sortOrder: 0,
        completed: false,
        cancelled: false,
        dueAt: now.add(const Duration(days: 5)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: '3',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        title: '紧急不重要',
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        completed: false,
        cancelled: false,
        dueAt: now.add(const Duration(hours: 2)),
        updatedAt: now,
        createdAt: now,
      ),
      TodoTask(
        id: '4',
        listId: '1',
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        title: '不重要不紧急',
        priority: 0,
        isPinned: false,
        sortOrder: 0,
        completed: false,
        cancelled: false,
        updatedAt: now,
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EisenhowerView(tasks: tasks, now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Q1 · 重要且紧急'), findsOneWidget);
    expect(find.text('Q2 · 重要不紧急'), findsOneWidget);
    expect(find.text('Q3 · 紧急不重要'), findsOneWidget);
    expect(find.text('Q4 · 不紧急不重要'), findsOneWidget);

    // 计数
    for (final label in ['紧急且重要', '重要不紧急', '紧急不重要', '不重要不紧急']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('EisenhowerView 登录后按服务端默认规则分组', (tester) async {
    final now = DateTime(2026, 6, 20, 12);
    final task = TodoTask(
      id: 'local-101',
      serverId: 101,
      listId: '1',
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      title: '服务端任务',
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      completed: false,
      cancelled: false,
      updatedAt: now,
      createdAt: now,
    );
    const rule = QuadrantRuleDto(
      id: 7,
      name: '远端默认规则',
      type: QuadrantRuleType.priorityTime,
      isDefault: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_TestSessionController.new),
          quadrantRulesProvider.overrideWith((ref) async => const [rule]),
          quadrantBoardProvider(7).overrideWith(
            (ref) async => const {
              'Q1_URGENT_IMPORTANT': {101},
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EisenhowerView(tasks: [task], now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务端规则：远端默认规则'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quadrant-q1')),
        matching: find.text('服务端任务'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quadrant-q4')),
        matching: find.text('服务端任务'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'EisenhowerView dark quadrants keep title and body contrast at least 4.5',
    (tester) async {
      final now = DateTime(2026, 6, 20, 12);
      final tasks = _quadrantTasks(now);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AppThemeExtension(AppColors.dark)],
            ),
            home: Scaffold(
              body: EisenhowerView(tasks: tasks, now: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final quadrantContent = <String, String>{
        'Q1 · 重要且紧急': '紧急且重要',
        'Q2 · 重要不紧急': '重要不紧急',
        'Q3 · 紧急不重要': '紧急不重要',
        'Q4 · 不紧急不重要': '不重要不紧急',
      };
      final contrastRatios = <String, double>{};

      for (final entry in quadrantContent.entries) {
        final background = _visibleQuadrantBackground(tester, entry.key);
        final titleColor = tester
            .widget<Text>(find.text(entry.key))
            .style!
            .color!;
        final bodyColor = tester
            .widget<Text>(find.text(entry.value))
            .style!
            .color!;
        contrastRatios['${entry.key} title'] = _contrastRatio(
          titleColor,
          background,
        );
        contrastRatios['${entry.key} body'] = _contrastRatio(
          bodyColor,
          background,
        );
      }

      final unreadable = Map.fromEntries(
        contrastRatios.entries.where((entry) => entry.value < 4.5),
      );
      expect(
        unreadable,
        isEmpty,
        reason: '深色主题象限的普通文本对比度需 >= 4.5；实测 $contrastRatios',
      );
    },
  );
}

class _TestSessionController extends SessionController {
  @override
  TodoAuthSession? build() {
    return const TodoAuthSession(
      userId: 1,
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      tenantId: '1',
      mobile: '13800000000',
    );
  }
}

List<TodoTask> _quadrantTasks(DateTime now) {
  return [
    TodoTask(
      id: 'dark-q1',
      listId: '1',
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      title: '紧急且重要',
      priority: 2,
      isPinned: false,
      sortOrder: 0,
      completed: false,
      cancelled: false,
      dueAt: now.add(const Duration(hours: 1)),
      updatedAt: now,
      createdAt: now,
    ),
    TodoTask(
      id: 'dark-q2',
      listId: '1',
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      title: '重要不紧急',
      priority: 3,
      isPinned: false,
      sortOrder: 0,
      completed: false,
      cancelled: false,
      dueAt: now.add(const Duration(days: 5)),
      updatedAt: now,
      createdAt: now,
    ),
    TodoTask(
      id: 'dark-q3',
      listId: '1',
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      title: '紧急不重要',
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      completed: false,
      cancelled: false,
      dueAt: now.add(const Duration(hours: 2)),
      updatedAt: now,
      createdAt: now,
    ),
    TodoTask(
      id: 'dark-q4',
      listId: '1',
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      title: '不重要不紧急',
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      completed: false,
      cancelled: false,
      updatedAt: now,
      createdAt: now,
    ),
  ];
}

Color _visibleQuadrantBackground(WidgetTester tester, String title) {
  final surface = find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate(
      (widget) => widget is Material && widget.borderRadius != null,
    ),
  );
  expect(surface, findsOneWidget);
  return tester.widget<Material>(surface).color!;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
