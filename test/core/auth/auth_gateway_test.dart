import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';

void main() {
  test('登录业务错误保留后端错误码供二次验证流程识别', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: const {
                  'code': 1099110104,
                  'data': null,
                  'msg': '请输入双重验证动态码',
                },
              ),
            );
          },
        ),
      );
    final gateway = AuthGatewayImpl(ApiClient(dio: dio), tenantId: '1');

    await expectLater(
      gateway.passwordLogin(mobile: '18800000000', password: '123456'),
      throwsA(
        isA<TodoAuthException>()
            .having((error) => error.code, 'code', 1099110104)
            .having((error) => error.message, 'message', '请输入双重验证动态码'),
      ),
    );
  });

  test('密码与短信登录按需提交双重验证动态码', () async {
    final captured = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: const {
                  'code': 0,
                  'data': {
                    'userId': 1,
                    'accessToken': 'access',
                    'refreshToken': 'refresh',
                  },
                },
              ),
            );
          },
        ),
      );
    final gateway = AuthGatewayImpl(ApiClient(dio: dio), tenantId: '1');

    await gateway.passwordLogin(
      mobile: '18800000000',
      password: '123456',
      twoFactorCode: '111111',
    );
    await gateway.smsLogin(
      mobile: '18800000000',
      code: '222222',
      twoFactorCode: '333333',
    );

    expect(captured[0].data, {
      'mobile': '18800000000',
      'password': '123456',
      'terminal': '30',
      'twoFactorCode': '111111',
    });
    expect(captured[1].data, {
      'mobile': '18800000000',
      'code': '222222',
      'terminal': '30',
      'twoFactorCode': '333333',
    });
  });

  test(
    'session validation sends its persisted token before session state restores',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(
                options.headers['Authorization'],
                'Bearer persisted-token',
              );
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: const {'code': 0, 'data': {}},
                ),
              );
            },
          ),
        );
      final gateway = AuthGatewayImpl(
        // bootstrap constructs the gateway while sessionProvider is still null.
        ApiClient(dio: dio, tokenProvider: () => ''),
        tenantId: '1',
      );

      await expectLater(gateway.validateSession('persisted-token'), completes);
    },
  );

  test(
    'session validation exposes a network failure to the session controller',
    () {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            ),
          ),
        );
      final gateway = AuthGatewayImpl(
        ApiClient(dio: dio, tokenProvider: () => 'persisted-access-token'),
        tenantId: '1',
      );

      expect(
        () => gateway.validateSession('persisted-access-token'),
        throwsA(isA<DioException>()),
      );
    },
  );
}
