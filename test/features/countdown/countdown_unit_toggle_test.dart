import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md:97》：「点击中间的天数，就能在**天、年、周**三种单位间快速切换」。
/// 桌面那一档（`:106`）是「点击倒数纪念日卡片上的天数」—— 本端只有列表卡片、没有详情页，
/// 所以按 `:106` 的落点做，详情页那一档另记欠账。
///
/// 用例只用「可见文案 + 读屏 label」这类公开 API，改实现不改测试；
/// 未实现时的失败信息应精确指向「点了没换单位」，不是编译错。
void main() {
  Future<void> pump(
    WidgetTester tester,
    List<CountdownDto> items, {
    Size? surface,
    double textScale = 1,
  }) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countdownsProvider.overrideWith((ref) => Future.value(items)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const CountdownPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CountdownDto item({
    required int id,
    required String title,
    required int days,
  }) {
    return CountdownDto(
      id: id,
      title: title,
      targetDate: DateTime(2026, 1, 1).add(Duration(days: days)),
      daysRemaining: days,
    );
  }

  testWidgets('倒数日卡片的天数可点击，切到「年」再切到「周」，第四次切回「天」', (tester) async {
    await pump(tester, [item(id: 1, title: '上线', days: 1095)]);
    // 正向对照：默认仍是原来的「天」档
    expect(find.text('还有 1095 天'), findsOneWidget);

    await tester.tap(find.text('还有 1095 天'));
    await tester.pump();
    expect(find.text('还有 3 年'), findsOneWidget);
    expect(find.text('还有 1095 天'), findsNothing);

    await tester.tap(find.text('还有 3 年'));
    await tester.pump();
    expect(find.text('还有 156 周'), findsOneWidget);

    await tester.tap(find.text('还有 156 周'));
    await tester.pump();
    expect(find.text('还有 1095 天'), findsOneWidget);
  });

  testWidgets('正数日（已过）同样按天·年·周切换，前缀保持「已」', (tester) async {
    await pump(tester, [item(id: 2, title: '恋爱纪念日', days: -2000)]);
    expect(find.text('已 2000 天'), findsOneWidget);

    await tester.tap(find.text('已 2000 天'));
    await tester.pump();
    expect(find.text('已 5 年'), findsOneWidget);

    await tester.tap(find.text('已 5 年'));
    await tester.pump();
    expect(find.text('已 285 周'), findsOneWidget);
  });

  testWidgets('单位切换按行独立：点一行不影响另一行', (tester) async {
    await pump(tester, [
      item(id: 1, title: '甲', days: 1095),
      item(id: 2, title: '乙', days: 30),
    ]);
    await tester.tap(find.text('还有 1095 天'));
    await tester.pump();
    expect(find.text('还有 3 年'), findsOneWidget);
    expect(find.text('还有 30 天'), findsOneWidget);
    expect(find.text('还有 4 周'), findsNothing);
  });

  testWidgets('天数块自身是读屏按钮，label 就是当前单位文案', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pump(tester, [item(id: 3, title: '生日', days: 1095)]);
      expect(
        find.bySemanticsLabel(RegExp('还有 1095 天')),
        findsOneWidget,
        reason: '未 ensureSemantics 时该 finder 恒空转，这里已开句柄',
      );
      final node = tester.getSemantics(
        find.byKey(const Key('todo-countdown-unit-3')),
      );
      expect(node.flagsCollection.isButton, isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320px + 1.3 倍字号下三种单位都能渲染且不溢出', (tester) async {
    await pump(
      tester,
      [item(id: 1, title: '一个比较长的倒数纪念日名称', days: 1095)],
      surface: const Size(320, 720),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('还有 1095 天'), findsOneWidget);

    await tester.tap(find.text('还有 1095 天'));
    await tester.pump();
    expect(find.text('还有 3 年'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('还有 3 年'));
    await tester.pump();
    expect(find.text('还有 156 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
