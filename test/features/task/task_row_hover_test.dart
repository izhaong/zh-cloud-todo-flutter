import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  testWidgets('desktop pin, drag, and more actions are contextual', (
    tester,
  ) async {
    await _pumpHost(tester);

    expect(find.byTooltip('置顶'), findsNothing);
    expect(find.byTooltip('更多'), findsNothing);
    expect(find.byTooltip('拖动排序'), findsNothing);

    final mouse = await _hoverTaskRow(tester);
    addTearDown(mouse.removePointer);

    expect(find.byTooltip('置顶'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsOneWidget);
  });

  testWidgets('desktop hover adds only the weak row background', (
    tester,
  ) async {
    await _pumpHost(tester);

    final surface = find.byKey(const Key('task-row-surface-task-1'));
    expect(surface, findsOneWidget);
    expect(_surfaceColor(tester, surface), Colors.transparent);

    final mouse = await _hoverTaskRow(tester);
    addTearDown(mouse.removePointer);

    expect(_surfaceColor(tester, surface), const Color(0xFFF7F7F7));
  });

  testWidgets('keyboard focus reveals actions with a visible outline', (
    tester,
  ) async {
    await _pumpHost(tester);

    final focus = tester.widget<Focus>(
      find.byKey(const Key('task-row-focus-task-1')),
    );
    focus.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    expect(focus.focusNode!.hasFocus, isTrue);
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).focused, isTrue);
    expect(find.byTooltip('置顶'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsOneWidget);
    final surface = find.byKey(const Key('task-row-surface-task-1'));
    expect(surface, findsOneWidget);
    final decoration = tester.widget<AnimatedContainer>(surface).decoration;
    final border = (decoration as BoxDecoration).border as Border;
    expect(border.top.color, AppColors.light.accent);
  });

  testWidgets('selected host uses the selected background and reports taps', (
    tester,
  ) async {
    String? selectedTaskId;
    await _pumpHost(
      tester,
      selected: true,
      onTaskSelected: (taskId) => selectedTaskId = taskId,
    );

    final selected = find.byKey(const Key('task-row-selected-task-1'));
    expect(selected, findsOneWidget);
    final surface = find.descendant(
      of: selected,
      matching: find.byKey(const Key('task-row-surface-task-1')),
    );
    expect(surface, findsOneWidget);
    expect(_surfaceColor(tester, surface), const Color(0xFFF2F2F2));

    await tester.tap(selected);
    await tester.pump();

    expect(selectedTaskId, 'task-1');
    expect(find.byType(TaskDetailPage), findsNothing);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  bool selected = false,
  ValueChanged<String>? onTaskSelected,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await db
      .into(db.todoTasks)
      .insert(
        TodoTasksCompanion.insert(
          id: 'task-1',
          listId: 'list-1',
          title: '任务',
          updatedAt: DateTime(2026, 7, 8, 9),
          createdAt: DateTime(2026, 7, 8, 9),
        ),
      );
  final task = await db.select(db.todoTasks).getSingle();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tagRepositoryProvider.overrideWith((ref) => null),
      taskRepositoryProvider.overrideWith((ref) => null),
    ],
  );
  addTearDown(container.dispose);

  late Widget host;
  if (selected) {
    expect(
      () {
        host =
            Function.apply(TaskRowHost.new, const [], {
                  #task: task,
                  #selected: true,
                  #onTap: onTaskSelected,
                  #desktopMode: true,
                  #enableSwipeGestures: false,
                  #reorderIndex: 0,
                })
                as Widget;
      },
      returnsNormally,
      reason: 'TaskRowHost must expose selected and onTap inputs',
    );
  } else {
    host = TaskRowHost(
      task: task,
      desktopMode: true,
      enableSwipeGestures: false,
      reorderIndex: 0,
    );
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(body: SizedBox(width: 640, child: host)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _hoverTaskRow(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer();
  await mouse.moveTo(tester.getCenter(find.byType(TaskRowHost)));
  await tester.pumpAndSettle();
  return mouse;
}

Color? _surfaceColor(WidgetTester tester, Finder finder) {
  final widget = tester.widget<AnimatedContainer>(finder);
  return (widget.decoration as BoxDecoration?)?.color;
}
