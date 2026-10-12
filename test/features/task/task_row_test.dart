import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';

void main() {
  final base = TaskRowData(
    id: 'plain',
    title: '整理今天的工作',
    completed: false,
    isPinned: false,
    priority: 0,
    dueAt: null,
    subtaskCount: 0,
    tagNames: const [],
  );

  group('DateBadge', () {
    test('无截止日期 → none', () {
      expect(base.badge(DateTime(2026, 7, 8)), DateBadge.none);
    });

    test('已完成 → none（忽略 dueAt）', () {
      final data = base.copyWith(completed: true, dueAt: DateTime(2026, 7, 7));
      expect(data.badge(DateTime(2026, 7, 8)), DateBadge.none);
    });

    test('逾期 → overdue', () {
      final data = base.copyWith(dueAt: DateTime(2026, 7, 7, 23));
      expect(data.badge(DateTime(2026, 7, 8)), DateBadge.overdue);
    });

    test('今天 → today', () {
      final data = base.copyWith(dueAt: DateTime(2026, 7, 8, 9));
      expect(data.badge(DateTime(2026, 7, 8)), DateBadge.today);
    });

    test('明天 → future', () {
      final data = base.copyWith(dueAt: DateTime(2026, 7, 9, 9));
      expect(data.badge(DateTime(2026, 7, 8)), DateBadge.future);
    });
  });

  testWidgets('plain task is a flat 44px row without AppCard', (tester) async {
    await _pumpRow(tester, data: base);

    expect(find.byType(AppCard), findsNothing);
    expect(tester.getSize(find.byType(TaskRow)).height, 44);
  });

  testWidgets('metadata task uses the fixed 58px row density', (tester) async {
    await _pumpRow(
      tester,
      data: base.copyWith(
        dueAt: DateTime(2032, 1, 15, 11),
        subtaskCount: 2,
        tagNames: const ['评审'],
      ),
      now: DateTime(2032, 1, 15, 9),
    );

    expect(tester.getSize(find.byType(TaskRow)).height, 58);
  });

  testWidgets('task checkbox keeps an 18px visual inside a 36px hit target', (
    tester,
  ) async {
    await _pumpRow(tester, data: base);

    final visual = find.descendant(
      of: find.byType(AppCheckbox),
      matching: find.byType(AnimatedContainer),
    );
    expect(visual, findsOneWidget);
    expect(tester.getSize(visual), const Size.square(18));
    expect(
      tester.getSize(find.byType(AppCheckbox)).shortestSide,
      greaterThanOrEqualTo(36),
    );
  });

  testWidgets('task checkbox exposes checked semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpRow(tester, data: base.copyWith(completed: true));

      final semanticFinder = find.byKey(const Key('app-checkbox-semantics'));
      expect(semanticFinder, findsOneWidget);
      final semanticCheckbox = tester.widget<Semantics>(semanticFinder);
      expect(semanticCheckbox.properties.checked, isTrue);
      expect(semanticCheckbox.properties.enabled, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('task checkbox disables its fill animation for reduced motion', (
    tester,
  ) async {
    await _pumpRow(tester, data: base, disableAnimations: true);

    final visual = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AppCheckbox),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(visual.duration, Duration.zero);
  });

  testWidgets('date copy is derived from the injected fixed clock', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      data: base.copyWith(dueAt: DateTime(2032, 1, 15, 11)),
      now: DateTime(2032, 1, 15, 9),
    );

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('1/15'), findsNothing);
  });
}

Future<void> _pumpRow(
  WidgetTester tester, {
  required TaskRowData data,
  DateTime? now,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: const [AppThemeExtension(AppColors.light)],
      ),
      builder: (context, child) {
        final media = MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations);
        return MediaQuery(data: media, child: child!);
      },
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: TaskRow(
              data: data,
              now: now,
              onToggleComplete: _noop,
              onTap: _noop,
              onPin: _noop,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop() {}

extension on TaskRowData {
  TaskRowData copyWith({
    bool? completed,
    DateTime? dueAt,
    int? subtaskCount,
    List<String>? tagNames,
  }) => TaskRowData(
    id: id,
    title: title,
    completed: completed ?? this.completed,
    isPinned: isPinned,
    priority: priority,
    dueAt: dueAt ?? this.dueAt,
    subtaskCount: subtaskCount ?? this.subtaskCount,
    tagNames: tagNames ?? this.tagNames,
    listColor: listColor,
  );
}
