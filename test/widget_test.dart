import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/main.dart';

void main() {
  testWidgets('renders calendar base and efficiency entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    expect(find.text('zh-cloud todo'), findsOneWidget);
    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(find.text('打开效率工具'), findsOneWidget);
    expect(find.text('当前视图：周'), findsOneWidget);
  });

  testWidgets('opens efficiency tools and updates local state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('效率').last);
    await tester.pumpAndSettle();

    expect(find.text('效率工具'), findsOneWidget);
    expect(find.text('四象限'), findsWidgets);
    expect(find.text('番茄'), findsWidgets);
    expect(find.text('习惯'), findsOneWidget);
    expect(find.text('倒数纪念日'), findsOneWidget);
    expect(find.text('基础统计'), findsOneWidget);

    await tester.tap(find.text('开始专注').last);
    await tester.pump();
    expect(find.text('暂停专注'), findsOneWidget);
    await tester.tap(find.text('暂停专注').last);
    await tester.pump();
    expect(find.text('开始专注'), findsOneWidget);

    await tester.tap(find.text('打卡首习惯').last);
    await tester.pumpAndSettle();
    expect(find.text('撤销首习惯'), findsOneWidget);
  });

  testWidgets('opens system entries and updates local state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('系统').last);
    await tester.pumpAndSettle();

    expect(find.text('桌面与系统入口'), findsOneWidget);
    expect(find.text('小组件'), findsWidgets);
    expect(find.text('桌面便签'), findsWidgets);
    expect(find.text('快捷入口'), findsWidgets);
    expect(find.text('系统分享'), findsWidgets);
    expect(find.text('导入入口'), findsWidgets);

    await tester.tap(find.text('新增桌面便签').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加导入记录').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('模拟系统分享').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('已接收系统分享'), 260);
    expect(find.textContaining('已接收系统分享'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('桌面便签 3'), 260);
    expect(find.text('桌面便签 3'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('导入入口 3'), 260);
    expect(find.text('导入入口 3'), findsOneWidget);
  });

  testWidgets('switches calendar views', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoFlutterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('月').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：月'), findsOneWidget);

    await tester.tap(find.text('日程').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：日程'), findsOneWidget);
  });
}
