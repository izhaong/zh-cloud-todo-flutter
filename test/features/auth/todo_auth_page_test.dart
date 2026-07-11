import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';
import 'package:zh_cloud_todo_flutter/todo_auth_page.dart';

void main() {
  testWidgets('宽屏展示 Todo 品牌面板与登录表单', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    await _pumpAuthPage(tester);

    expect(find.byKey(const ValueKey('todo-auth-wide-layout')), findsOneWidget);
    expect(find.text('把今天安排得更清楚'), findsOneWidget);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('todo-auth-password-visibility')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('todo-auth-wide-layout')))
          .center
          .dy,
      closeTo(450, 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏在 390 与 320 宽度使用无溢出的单栏布局', (tester) async {
    for (final width in [390.0, 320.0]) {
      await _setViewport(tester, Size(width, 800));
      await _pumpAuthPage(tester);

      expect(
        find.byKey(const ValueKey('todo-auth-compact-layout')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('todo-auth-wide-layout')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('密码按钮切换可见状态并提供自动填充提示', (tester) async {
    await _pumpAuthPage(tester);

    final passwordFinder = find.widgetWithText(TextFormField, '密码');
    final editableFinder = find.descendant(
      of: passwordFinder,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editableFinder).obscureText, isTrue);
    expect(
      tester.widget<EditableText>(editableFinder).autofillHints,
      contains(AutofillHints.password),
    );

    await tester.tap(
      find.byKey(const ValueKey('todo-auth-password-visibility')),
    );
    await tester.pump();

    expect(tester.widget<EditableText>(editableFinder).obscureText, isFalse);
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
  });

  testWidgets('四种认证模式使用面向用户的文案', (tester) async {
    await _pumpAuthPage(tester);

    expect(find.text('登录后继续安排任务与日程'), findsOneWidget);

    await tester.tap(find.text('验证码'));
    await tester.pump();
    expect(find.text('输入手机号，我们会发送登录验证码'), findsOneWidget);

    await tester.tap(find.text('密码'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('todo-auth-register-link')));
    await tester.pump();
    expect(find.text('创建 Todo 账号'), findsOneWidget);
    expect(find.text('验证手机号后即可开始使用'), findsOneWidget);

    await tester.tap(find.text('返回密码登录'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('todo-auth-forgot-password-link')),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('todo-auth-title'))).data,
      '重置密码',
    );
    expect(find.text('验证手机号并设置新密码'), findsOneWidget);
  });

  testWidgets('未知登录异常显示可操作提示且不暴露异常对象', (tester) async {
    final semantics = tester.ensureSemantics();
    await _setViewport(tester, const Size(800, 1000));
    await _pumpAuthPage(
      tester,
      authGateway: _FakeAuthGateway(failPasswordLogin: true),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '123456');
    await tester.tap(find.byKey(const ValueKey('todo-auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法完成请求，请稍后重试'), findsOneWidget);
    expect(find.textContaining('internal-auth-error'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('todo-auth-message'))),
      matchesSemantics(label: '错误：暂时无法完成请求，请稍后重试', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('深色主题与 200% 文本缩放在最小宽度保持可用', (tester) async {
    await _setViewport(tester, const Size(320, 1000));
    await _pumpAuthPage(
      tester,
      themeMode: ThemeMode.dark,
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('todo-auth-compact-layout')),
      findsOneWidget,
    );
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.byTooltip('显示密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpAuthPage(
  WidgetTester tester, {
  AuthGateway? authGateway,
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(
          authGateway ?? _FakeAuthGateway(),
        ),
        sessionStoreProvider.overrideWithValue(_MemorySessionStore()),
      ],
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const TodoAuthPage(),
      ),
    ),
  );
  await tester.pump();
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.failPasswordLogin = false});

  final bool failPasswordLogin;

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  }) async {
    if (failPasswordLogin) {
      throw Exception('internal-auth-error');
    }
    return TodoAuthSession(
      userId: 1,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tenantId: '1',
      mobile: mobile,
    );
  }

  @override
  Future<void> sendSmsCode({
    required String mobile,
    required int scene,
  }) async {}

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  }) async => TodoAuthSession(
    userId: 1,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    tenantId: '1',
    mobile: mobile,
  );

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {}

  @override
  Future<bool> validateSession(String accessToken) async => true;

  @override
  Future<void> logout(String accessToken) async {}

  @override
  void close() {}
}

class _MemorySessionStore extends SessionStore {
  TodoAuthSession? session;

  @override
  Future<TodoAuthSession?> readSession() async => session;

  @override
  Future<void> writeSession(TodoAuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clearSession() async {
    session = null;
  }
}
