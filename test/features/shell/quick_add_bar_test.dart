import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';

void main() {
  testWidgets('QuickAddBar 提交文本并暴露快捷按钮', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension(AppColors.dark)],
        ),
        home: Scaffold(body: QuickAddBar(onSubmit: (text) => submitted = text)),
      ),
    );

    expect(find.byTooltip('日期'), findsOneWidget);
    expect(find.byTooltip('优先级'), findsOneWidget);
    expect(find.byTooltip('标签'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '写周报');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted, '写周报');
    expect(find.text('写周报'), findsNothing);
  });
}
