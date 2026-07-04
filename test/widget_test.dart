import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/app.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';
import 'package:zh_cloud_todo_flutter/todo_member_auth_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('未登录时显示密码登录表单', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authGatewayProvider.overrideWithValue(_FakeAuthClient()),
        ],
        child: const TodoFlutterApp(),
      ),
    );
    await tester.pump();

    expect(find.text('密码登录'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '手机号'), findsOneWidget);
  });

  testWidgets('无效本地会话在校验后回到登录页', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zh_cloud_todo_flutter_session_v1': jsonEncode({
        'userId': 1,
        'accessToken': 'stale-token',
        'refreshToken': 'refresh',
        'mobile': '18800000000',
      }),
    });
    final fake = _FakeAuthClient(validateSessionResult: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authGatewayProvider.overrideWithValue(fake)],
        child: const TodoFlutterApp(),
      ),
    );
    await tester.pump();
    // 完成会话校验异步链路：一次 Future.microtask + SharedPreferences 写。
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('密码登录'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zh_cloud_todo_flutter_session_v1'), isNull);
  });
}

class _FakeAuthClient implements TodoMemberAuthGateway {
  _FakeAuthClient({this.validateSessionResult = true});

  final bool validateSessionResult;

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  }) async {
    return TodoAuthSession(
      userId: 1,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      mobile: mobile,
    );
  }

  @override
  Future<void> sendSmsCode({required String mobile, required int scene}) async {}

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  }) async {
    return TodoAuthSession(
      userId: 1,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
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
  Future<bool> validateSession(String accessToken) async {
    return validateSessionResult && accessToken.isNotEmpty;
  }

  @override
  Future<void> logout(String accessToken) async {}

  @override
  void close() {}
}
