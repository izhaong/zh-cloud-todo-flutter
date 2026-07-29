import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/features/account/account_security_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  testWidgets('绑定认证器并确认动态码后才显示双重验证已开启', (tester) async {
    final requests = <RequestOptions>[];
    await _pumpPage(tester, requests: requests, enabled: false);

    await tester.tap(
      find.byKey(const ValueKey('account-security-two-factor-switch')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('two-factor-setup-secret')),
      findsOneWidget,
    );
    expect(find.text('JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP'), findsOneWidget);
    expect(find.byKey(const ValueKey('two-factor-setup-uri')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('two-factor-code-input')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('two-factor-code-confirm')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('account-security-two-factor-switch')),
    );
    expect(toggle.value, isTrue);
    expect(find.text('已开启双重验证'), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.path.endsWith('/security/2fa/confirm') &&
            request.queryParameters['code'] == '123456',
      ),
      isTrue,
    );
  });

  testWidgets('关闭双重验证必须提交当前动态码', (tester) async {
    final requests = <RequestOptions>[];
    await _pumpPage(tester, requests: requests, enabled: true);

    await tester.tap(
      find.byKey(const ValueKey('account-security-two-factor-switch')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('关闭双重验证'), findsOneWidget);
    expect(find.byKey(const ValueKey('two-factor-setup-secret')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('two-factor-code-input')),
      '654321',
    );
    await tester.tap(find.byKey(const ValueKey('two-factor-code-confirm')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('account-security-two-factor-switch')),
    );
    expect(toggle.value, isFalse);
    expect(
      requests.any(
        (request) =>
            request.path.endsWith('/security/2fa/disable') &&
            request.queryParameters['code'] == '654321',
      ),
      isTrue,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<RequestOptions> requests,
  required bool enabled,
}) async {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final dynamic data;
          if (options.path.endsWith('/security/2fa/status')) {
            data = enabled;
          } else if (options.path.endsWith('/security/2fa/setup')) {
            data = {
              'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
              'otpauthUri': 'otpauth://totp/zh-cloud',
            };
          } else if (options.path.endsWith('/security/export/list')) {
            data = <dynamic>[];
          } else {
            data = true;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {'code': 0, 'data': data, 'msg': ''},
            ),
          );
        },
      ),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoApiProvider.overrideWithValue(TodoRestApi(ApiClient(dio: dio))),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const AccountSecurityPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
