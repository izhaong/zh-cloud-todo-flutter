import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/features/account/change_password_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

void main() {
  testWidgets('发送修改密码验证码使用会员场景 3', (tester) async {
    final gateway = _FakeAuthGateway();
    await _pumpPage(tester, gateway: gateway);

    await tester.tap(find.byKey(const ValueKey('change-password-send-code')));
    await tester.pump();

    expect(gateway.sentScenes, [3]);
  });

  testWidgets('密码不一致时阻止提交并显示字段错误', (tester) async {
    final requests = <RequestOptions>[];
    await _pumpPage(tester, requests: requests);

    await tester.enterText(
      find.byKey(const ValueKey('change-password-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-new')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-confirm')),
      'another-password',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.path.endsWith('/user/update-password'),
      ),
      isEmpty,
    );
  });

  testWidgets('验证码和新密码有效时完成修改', (tester) async {
    final requests = <RequestOptions>[];
    await _pumpPage(tester, requests: requests);

    await tester.enterText(
      find.byKey(const ValueKey('change-password-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-new')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-confirm')),
      'new-password',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    final request = requests.singleWhere(
      (item) => item.path.endsWith('/user/update-password'),
    );
    expect(request.data, {'code': '123456', 'password': 'new-password'});
    expect(find.text('密码已修改'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  _FakeAuthGateway? gateway,
  List<RequestOptions>? requests,
}) async {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests?.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {'code': 0, 'data': true, 'msg': ''},
            ),
          );
        },
      ),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(gateway ?? _FakeAuthGateway()),
        todoApiProvider.overrideWithValue(TodoRestApi(ApiClient(dio: dio))),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const ChangePasswordPage(),
      ),
    ),
  );
  await tester.pump();
}

class _FakeAuthGateway implements AuthGateway {
  final List<int> sentScenes = [];

  @override
  Future<void> sendSmsCode({required String mobile, required int scene}) async {
    sentScenes.add(scene);
  }

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
    String? twoFactorCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
    String? twoFactorCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(String accessToken) async {}

  @override
  Future<bool> validateSession(String accessToken) async => true;

  @override
  void close() {}
}
