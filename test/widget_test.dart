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
    expect(find.text('清单'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('同步队列'), findsOneWidget);
  });
}
