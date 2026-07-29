import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('修改密码使用 member user update-password 契约', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': true, 'msg': ''},
              ),
            );
          },
        ),
      );
    final api = SecurityApi(ApiClient(dio: dio));

    await api.changePassword(code: '123456', password: 'new-password');

    expect(captured?.path, '/app-api/todo-member/user/update-password');
    expect(captured?.method, 'PUT');
    expect(captured?.data, {'code': '123456', 'password': 'new-password'});
  });
}
