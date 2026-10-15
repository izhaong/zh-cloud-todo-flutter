import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

    await _setViewport(tester, const Size(900, 900));
    await _pumpAuthPage(tester);
    expect(find.byKey(const ValueKey('todo-auth-wide-layout')), findsOneWidget);
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

  testWidgets('密码登录暴露固定设备验收语义标识', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpAuthPage(tester);

    expect(find.bySemanticsIdentifier('todo_auth_mobile'), findsOneWidget);
    expect(find.bySemanticsIdentifier('todo_auth_password'), findsOneWidget);
    expect(find.bySemanticsIdentifier('todo_auth_submit'), findsOneWidget);

    semantics.dispose();
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

  testWidgets('密码登录需要双重验证时保留表单并携带动态码重试', (tester) async {
    final gateway = _FakeAuthGateway(requirePasswordTwoFactor: true);
    await _pumpAuthPage(tester, authGateway: gateway);

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '123456');
    await tester.tap(find.byKey(const ValueKey('todo-auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('todo-auth-two-factor-input')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '手机号'))
          .controller
          ?.text,
      '18800000000',
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '密码'))
          .controller
          ?.text,
      '123456',
    );

    await tester.enterText(
      find.byKey(const ValueKey('todo-auth-two-factor-input')),
      '654321',
    );
    await tester.tap(find.byKey(const ValueKey('todo-auth-submit')));
    await tester.pumpAndSettle();

    expect(gateway.lastPasswordTwoFactorCode, '654321');
  });

  testWidgets('短信登录需要双重验证时携带动态码重试', (tester) async {
    final gateway = _FakeAuthGateway(requireSmsTwoFactor: true);
    await _pumpAuthPage(tester, authGateway: gateway);

    await tester.tap(find.text('验证码'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号'),
      '18800000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '短信验证码'),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('todo-auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('todo-auth-two-factor-input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('todo-auth-two-factor-input')),
      '654321',
    );
    await tester.tap(find.byKey(const ValueKey('todo-auth-submit')));
    await tester.pumpAndSettle();

    expect(gateway.lastSmsTwoFactorCode, '654321');
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

  testWidgets('键盘 Tab 可以进入登录表单焦点顺序', (tester) async {
    await _pumpAuthPage(tester);
    FocusManager.instance.primaryFocus?.unfocus();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  // -------------------------------------------------------------------------
  // 模式切换的布局稳定性
  //
  // 用户反馈（Issue #650）：「切换密码或验证码时 登录高度会变 会弹」。
  // 根因：密码/验证码两种模式的字段集合不同（验证码模式多一个验证码框、少一行
  // 「注册 / 忘记密码」），条件渲染的 if 数量也不同，且 Column 直接换内容、
  // 没有任何尺寸过渡 ⇒ 卡片高度阶跃。
  //
  // 契约：**同一视口下，密码 ↔ 验证码切换后表单高度必须一致**。
  // -------------------------------------------------------------------------

  testWidgets('切密码↔验证码时登录卡片高度不变（不再「弹」）', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    await _pumpAuthPage(tester);

    final passwordHeight = tester.authCardHeight();

    await tester.tap(find.text('验证码'));
    await tester.pumpAndSettle();
    final smsHeight = tester.authCardHeight();

    expect(
      smsHeight,
      closeTo(passwordHeight, 1.0),
      reason: '密码 → 验证码后卡片高度必须保持一致（用户看到的「弹一下」就在这里）',
    );

    await tester.tap(find.text('密码'));
    await tester.pumpAndSettle();
    expect(
      tester.authCardHeight(),
      closeTo(passwordHeight, 1.0),
      reason: '验证码 → 密码回来时高度也要还原',
    );
  });

  testWidgets('窄屏同样保持模式切换高度稳定', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpAuthPage(tester);

    final passwordHeight = tester.authCardHeight();
    await tester.tap(find.text('验证码'));
    await tester.pumpAndSettle();

    expect(
      tester.authCardHeight(),
      closeTo(passwordHeight, 1.0),
      reason: '窄屏是用户最常遇到的登录形态，切换同样不能跳',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换模式不得改变外层滚动区高度（不引起整页重排）', (tester) async {
    await _setViewport(tester, const Size(1440, 900));
    await _pumpAuthPage(tester);

    final listFinder = find.byKey(const ValueKey('todo-auth-list'));
    final before = tester.getSize(listFinder);

    await tester.tap(find.text('验证码'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(listFinder).height,
      closeTo(before.height, 1.0),
      reason: '模式切换只应换字段内容，不应改变外层可用高度（否则整页重排）',
    );
  });
}

/// 取登录卡片（表单根 Material）的高度。
extension on WidgetTester {
  double authCardHeight() {
    final card = find.ancestor(
      of: find.byKey(const ValueKey('todo-auth-title')),
      matching: find.byType(Material),
    );
    return getSize(card.first).height;
  }
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
  _FakeAuthGateway({
    this.failPasswordLogin = false,
    this.requirePasswordTwoFactor = false,
    this.requireSmsTwoFactor = false,
  });

  final bool failPasswordLogin;
  final bool requirePasswordTwoFactor;
  final bool requireSmsTwoFactor;
  String? lastPasswordTwoFactorCode;
  String? lastSmsTwoFactorCode;

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
    String? twoFactorCode,
  }) async {
    if (failPasswordLogin) {
      throw Exception('internal-auth-error');
    }
    lastPasswordTwoFactorCode = twoFactorCode;
    if (requirePasswordTwoFactor && twoFactorCode == null) {
      throw const TodoAuthException('请输入双重验证动态码', code: 1099110104);
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
    String? twoFactorCode,
  }) async {
    lastSmsTwoFactorCode = twoFactorCode;
    if (requireSmsTwoFactor && twoFactorCode == null) {
      throw const TodoAuthException('请输入双重验证动态码', code: 1099110104);
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
