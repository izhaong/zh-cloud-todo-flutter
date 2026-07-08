import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/app_dialog.dart';

/// Phase 4：品牌化弹窗系统测试。
void main() {
  Widget _app(Widget child) => MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppThemeExtension(AppColors.light)]),
        home: child,
      );

  testWidgets('confirm 弹窗显示标题/内容 + 两按钮 + 返回', (tester) async {
    var result = false;
    await tester.pumpWidget(_app(
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await AppDialog.confirm(
              ctx,
              title: '删除任务',
              content: '确认删除？',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('删除任务'), findsOneWidget);
    expect(find.text('确认删除？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);

    // 点击确认 → 返回 true
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('danger 按钮文字走 confirmLabel', (tester) async {
    var result = false;
    await tester.pumpWidget(_app(
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await AppDialog.confirm(
              ctx,
              title: 'x',
              confirmLabel: '删除',
              danger: true,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
