import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/app.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

void main() {
  testWidgets('未登录时显示密码登录表单', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          authGatewayProvider.overrideWithValue(_FakeAuthClient()),
        ],
        child: const TodoFlutterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '手机号'), findsOneWidget);
  });

  testWidgets('无效本地会话在校验后回到登录页', (tester) async {
    final sessionStore = _FakeSessionStore(
      const TodoAuthSession(
        userId: 1,
        accessToken: 'stale-token',
        refreshToken: 'refresh',
        tenantId: '1',
        mobile: '18800000000',
      ),
    );
    final fake = _FakeAuthClient(validateSessionResult: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(sessionStore),
          authGatewayProvider.overrideWithValue(fake),
        ],
        child: const TodoFlutterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(sessionStore.cleared, isTrue);
  });

  // Issue #471：没挂 flutter_localizations 时框架自带文案是英文，
  // web 实测在语义树里读到 button "Back" 与 button "Show menu"。
  testWidgets('框架自带文案解析成中文（MaterialLocalizations 走 zh）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          authGatewayProvider.overrideWithValue(_FakeAuthClient()),
        ],
        child: const TodoFlutterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final context = tester.element(find.text('欢迎回来'));
    final material = MaterialLocalizations.of(context);
    expect(material.backButtonTooltip, '返回');
    expect(material.showMenuTooltip, '显示菜单');
    expect(material.closeButtonTooltip, '关闭');
    expect(Localizations.localeOf(context), const Locale('zh'));
  });
}

class _FakeAuthClient implements AuthGateway {
  _FakeAuthClient({this.validateSessionResult = true});

  final bool validateSessionResult;

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
    String? twoFactorCode,
  }) async {
    return const TodoAuthSession(
      userId: 1,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tenantId: '1',
      mobile: '',
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
    return const TodoAuthSession(
      userId: 1,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tenantId: '1',
      mobile: '',
    );
  }

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {}

  @override
  Future<bool> validateSession(String accessToken) async {
    return validateSessionResult && accessToken.isNotEmpty;
  }

  @override
  Future<void> logout(String accessToken) async {}

  @override
  void close() {}
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore([this.stored]);

  TodoAuthSession? stored;
  bool cleared = false;

  @override
  Future<TodoAuthSession?> readSession() async => stored;

  @override
  Future<void> writeSession(TodoAuthSession session) async {
    stored = session;
  }

  @override
  Future<void> clearSession() async {
    stored = null;
    cleared = true;
  }
}
