import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';

void main() {
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
