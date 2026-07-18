import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';

void main() {
  test('session validation sends its persisted token before session state restores',
      () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['Authorization'], 'Bearer persisted-token');
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
  });

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
