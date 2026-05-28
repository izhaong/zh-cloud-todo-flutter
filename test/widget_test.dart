import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/main.dart';
import 'package:zh_cloud_todo_flutter/todo_member_auth_client.dart';

void main() {
  testWidgets('renders calendar base and efficiency entry', (tester) async {
    SharedPreferences.setMockInitialValues(_signedInState());
    await tester.pumpWidget(TodoFlutterApp(authClient: _FakeAuthClient()));
    await tester.pumpAndSettle();

    expect(find.text('zh-cloud todo'), findsOneWidget);
    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(find.text('打开效率工具'), findsOneWidget);
    expect(find.text('当前视图：周'), findsOneWidget);
  });

  testWidgets('opens efficiency tools and updates local state', (tester) async {
    SharedPreferences.setMockInitialValues(_signedInState());
    await tester.pumpWidget(TodoFlutterApp(authClient: _FakeAuthClient()));
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
    SharedPreferences.setMockInitialValues(_signedInState());
    await tester.pumpWidget(TodoFlutterApp(authClient: _FakeAuthClient()));
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
    SharedPreferences.setMockInitialValues(_signedInState());
    await tester.pumpWidget(TodoFlutterApp(authClient: _FakeAuthClient()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('月').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：月'), findsOneWidget);

    await tester.tap(find.text('日程').last);
    await tester.pumpAndSettle();
    expect(find.text('当前视图：日程'), findsOneWidget);
  });

  testWidgets('password login enters todo home and persists token', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authClient = _FakeAuthClient();
    await tester.pumpWidget(TodoFlutterApp(authClient: authClient));
    await tester.pumpAndSettle();

    expect(find.text('Todo 账号入口'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '123456');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(authClient.passwordLoginCount, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('zh_cloud_todo_flutter_state_v2'),
      contains('access-token'),
    );
  });

  testWidgets('register uses sms code flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authClient = _FakeAuthClient();
    await tester.pumpWidget(TodoFlutterApp(authClient: authClient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();
    expect(find.text('注册 Todo 账号'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('登录验证码已发送'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '短信验证码'), '9999');
    await tester.tap(find.text('注册并登录'));
    await tester.pumpAndSettle();

    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(authClient.sentScenes, [1]);
    expect(authClient.smsLoginCount, 1);
  });

  testWidgets('sms login enters todo home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authClient = _FakeAuthClient();
    await tester.pumpWidget(TodoFlutterApp(authClient: authClient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('验证码'));
    await tester.pumpAndSettle();
    expect(find.text('短信验证码登录'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '短信验证码'), '9999');
    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();

    expect(find.text('日历 / 日程入口'), findsOneWidget);
    expect(authClient.sentScenes, [1]);
    expect(authClient.smsLoginCount, 1);
  });

  testWidgets('forgot password resets and returns to password login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authClient = _FakeAuthClient();
    await tester.pumpWidget(TodoFlutterApp(authClient: authClient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('忘记密码'));
    await tester.pumpAndSettle();
    expect(find.text('找回密码'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '新密码'), '654321');
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('重置密码验证码已发送'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '短信验证码'), '9999');
    final resetButton = find.byWidgetPredicate(
      (widget) =>
          widget is FilledButton &&
          widget.key == const ValueKey('todo-auth-submit'),
    );
    await tester.drag(
      find.byKey(const ValueKey('todo-auth-list')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('密码已重置，请使用新密码登录'), findsOneWidget);
    expect(authClient.sentScenes, [4]);
    expect(authClient.resetPasswordCount, 1);
  });
}

Map<String, Object> _signedInState() => {
  'zh_cloud_todo_flutter_state_v2':
      '{"authSession":{"userId":1,"accessToken":"access-token","refreshToken":"refresh-token","mobile":"18800000000"},"activeTab":"日历","calendarView":"周"}',
};

class _FakeAuthClient implements TodoMemberAuthGateway {
  int passwordLoginCount = 0;
  int smsLoginCount = 0;
  int resetPasswordCount = 0;
  int logoutCount = 0;
  final sentScenes = <int>[];

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  }) async {
    passwordLoginCount += 1;
    return _session(mobile);
  }

  @override
  Future<void> sendSmsCode({required String mobile, required int scene}) async {
    sentScenes.add(scene);
  }

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  }) async {
    smsLoginCount += 1;
    return _session(mobile);
  }

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {
    resetPasswordCount += 1;
  }

  @override
  Future<void> logout(String accessToken) async {
    logoutCount += 1;
  }

  @override
  void close() {}

  TodoAuthSession _session(String mobile) => TodoAuthSession(
    userId: 1,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    mobile: mobile,
  );
}
