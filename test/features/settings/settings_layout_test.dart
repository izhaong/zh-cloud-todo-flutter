import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';

import '../../support/todo_visual_fixture.dart';

/// 设置页的版式契约：尾部控件同一条竖线、同组条目同在一张卡里。
///
/// 两条都是「看着能忍，量出来不对」的那类问题——肉眼很难说清是几像素，
/// 所以这里按渲染出来的几何断言，而不是比对截图。
Future<TodoVisualFixture> _pumpSettings(WidgetTester tester) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
  );
  addTearDown(fixture.dispose);
  tester.view.physicalSize = const Size(1440, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: const SettingsRoute(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  testWidgets('四个开关与所有 trailing 文案 / 箭头落在同一条竖线上', (tester) async {
    await _pumpSettings(tester);

    final edges = <String, double>{};
    for (final label in const ['时区', '显示农历', '显示节假日调休', '显示习惯打卡']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(SwitchListTile),
      );
      expect(tile, findsOneWidget, reason: '$label 应是一行开关');
      final switchFinder = find.descendant(
        of: tile,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget, reason: '$label 行里应有一枚开关');
      edges[label] = tester.getRect(switchFinder).right;
    }

    for (final entry in edges.entries) {
      expect(
        entry.value,
        closeTo(edges.values.first, 0.5),
        reason: '${entry.key} 的开关与其它开关不在同一条竖线上',
      );
    }

    // 与其它卡片的 trailing 文案（显示 / 开启）和箭头同线：
    // 「时区」原来自带 horizontal 12 的内边距，比这些都右出 12px。
    final trailingTexts = <double>[
      for (final label in const ['显示', '开启'])
        for (final element in find.text(label).evaluate())
          (element.renderObject! as RenderBox).localToGlobal(
            Offset.zero,
          ).dx +
              (element.renderObject! as RenderBox).size.width,
    ];
    expect(trailingTexts, isNotEmpty);
    for (final right in trailingTexts) {
      expect(right, closeTo(edges.values.first, 0.5));
    }

    final chevrons = <double>[
      for (final element in find.byIcon(Icons.chevron_right).evaluate())
        (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx +
            (element.renderObject! as RenderBox).size.width,
    ];
    expect(chevrons, isNotEmpty);
    for (final right in chevrons) {
      expect(right, closeTo(edges.values.first, 0.5));
    }
  });

  testWidgets('「标签」与「过滤器」同属一张卡（智能清单成组）', (tester) async {
    await _pumpSettings(tester);

    final tagsCard = find.ancestor(
      of: find.byKey(const Key('todo-settings-show-tags')),
      matching: find.byType(AppCard),
    );
    final filtersCard = find.ancestor(
      of: find.byKey(const Key('todo-settings-show-filters')),
      matching: find.byType(AppCard),
    );
    expect(tagsCard, findsOneWidget);
    expect(filtersCard, findsOneWidget);
    expect(
      identical(
        tagsCard.evaluate().single.widget,
        filtersCard.evaluate().single.widget,
      ),
      isTrue,
      reason: '两行拆成两张卡时中间的卡间距比同卡行距大一截，与其它分组不一致',
    );
  });
}
