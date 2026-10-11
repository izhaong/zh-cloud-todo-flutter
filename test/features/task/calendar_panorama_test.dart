import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

final _now = DateTime(2026, 6, 15, 12);

/// 列表档「下拉展开日历全景」（嘀嗒《08-常见问题》:168，矩阵 #29）。
/// 判据源：`todo/99_参考资料/dida365-help-center/02-功能指南/02-日历/08-常见问题.md`
/// `:167`「日历列表视图，不能看到完整的日历吗？」
/// `:168`「在列表视图，手指按住第一排日历，向下拉，即可展开一个小的日历全景。」
Future<void> _pump(
  WidgetTester tester, {
  Size? surface,
  double textScale = 1.0,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskViewActionRepositoryProvider.overrideWithValue(null)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: CalendarView(tasks: const [], now: _now),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('列表'));
  await tester.pumpAndSettle();
}

bool _expandedLabel(WidgetTester tester) {
  return tester
          .getSemantics(find.byKey(const Key('calendar-list-panorama-toggle')))
          .getSemanticsData()
          .label ==
      '收起日历全景';
}

void main() {
  testWidgets('列表档默认收起：只有第一排日历，没有全景', (tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('calendar-list-panorama')), findsNothing);
    expect(
      find.byKey(const Key('calendar-list-panorama-toggle')),
      findsOneWidget,
    );
    // 收起态的读屏 label 是「展开日历全景」，而不是「收起」。
    expect(_expandedLabel(tester), isFalse);
  });

  testWidgets('点读屏按钮展开全景，再点收起', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    await tester.tap(find.byKey(const Key('calendar-list-panorama-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-list-panorama')), findsOneWidget);
    expect(_expandedLabel(tester), isTrue);
    // 全景是同屏展开的月网格，表头周序字形必须出现。
    expect(find.text('一'), findsWidgets);

    await tester.tap(find.byKey(const Key('calendar-list-panorama-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-list-panorama')), findsNothing);
    expect(_expandedLabel(tester), isFalse);
    handle.dispose();
  });

  testWidgets('在第一排日历上向下拉展开、向上拉收起（嘀嗒 :168 字面手势）', (tester) async {
    await _pump(tester);

    await tester.fling(
      find.byKey(const Key('calendar-list-panorama-toggle')),
      const Offset(0, 200),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-list-panorama')), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('calendar-list-panorama-toggle')),
      const Offset(0, -200),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-list-panorama')), findsNothing);
  });

  testWidgets('点全景里的某天：锚点切到那天并收起全景，读屏选中态跟走', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    await tester.tap(find.byKey(const Key('calendar-list-panorama-toggle')));
    await tester.pumpAndSettle();

    // 2026-06-15（周一）所在周的锚点日是 15，全景网格里有 20 号。
    await tester.tap(find.byKey(const Key('calendar-day-2026-6-20')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-list-panorama')), findsNothing);
    final dayData = tester
        .getSemantics(find.byKey(const Key('calendar-strip-day-2026-6-20')))
        .getSemanticsData();
    expect(dayData.label, '6月20日');
    expect(dayData.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('320px + 1.3 倍字号：展开全景不溢出', (tester) async {
    await _pump(tester, surface: const Size(320, 844), textScale: 1.3);

    await tester.tap(find.byKey(const Key('calendar-list-panorama-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-list-panorama')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
