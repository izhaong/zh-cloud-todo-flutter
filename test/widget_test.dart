import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zh_cloud_todo_flutter/main.dart';

void main() {
  testWidgets('renders core dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    expect(find.text('zh-cloud todo'), findsOneWidget);
    expect(find.text('移动端核心闭环'), findsOneWidget);
    expect(find.text('日历'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('同步队列'), findsOneWidget);
  });

  testWidgets('switches calendar views', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('日历').last);
    await tester.pumpAndSettle();
    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(find.text('当前视图：周'), findsOneWidget);

    await tester.tap(find.text('月').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：月'), findsOneWidget);

    await tester.tap(find.text('日程').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：日程'), findsOneWidget);
  });
}
