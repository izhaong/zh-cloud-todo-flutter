import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, double width) async {
    tester.binding.window.physicalSizeTestValue = Size(width, 900);
    tester.binding.window.devicePixelRatioTestValue = 1;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AppThemeExtension(AppColors.dark)],
          ),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('1440 桌面渲染 rail + sidebar + content + detail', (tester) async {
    await pumpShell(tester, 1440);
    expect(find.byKey(const Key('ticktick-rail')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-content')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-detail-panel')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-mobile-nav')), findsNothing);
    expect(find.byType(QuickAddBar), findsOneWidget);
  });

  testWidgets('1200 宽度保留 rail + sidebar + content，详情进抽屉', (tester) async {
    await pumpShell(tester, 1200);
    expect(find.byKey(const Key('ticktick-rail')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-content')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-detail-panel')), findsNothing);
    expect(find.byType(QuickAddBar), findsOneWidget);
  });

  testWidgets('820 宽度侧栏收起为 drawer', (tester) async {
    await pumpShell(tester, 820);
    expect(find.byKey(const Key('ticktick-rail')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-content')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-detail-panel')), findsNothing);
    expect(find.byType(QuickAddBar), findsOneWidget);
    await tester.tap(find.byTooltip('菜单'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('智能清单'), findsWidgets);
  });

  testWidgets('390 移动端使用 bottom nav + drawer', (tester) async {
    await pumpShell(tester, 390);
    expect(find.byKey(const Key('ticktick-rail')), findsNothing);
    expect(find.byKey(const Key('ticktick-mobile-nav')), findsOneWidget);
    expect(find.byKey(const Key('ticktick-detail-panel')), findsNothing);
    expect(find.byType(QuickAddBar), findsNothing);
    await tester.tap(find.byTooltip('菜单'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('智能清单'), findsWidgets);
  });
}
