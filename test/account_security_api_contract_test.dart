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

  test('双重验证配置使用 setup 契约并解析密钥', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
                    'otpauthUri': 'otpauth://totp/zh-cloud',
                  },
                  'msg': '',
                },
              ),
            );
          },
        ),
      );
    final api = SecurityApi(ApiClient(dio: dio));

    final setup = await api.setupTwoFactor(currentCode: '654321');

    expect(captured?.path, '/app-api/todo/security/2fa/setup');
    expect(captured?.method, 'POST');
    expect(captured?.queryParameters, {'currentCode': '654321'});
    expect(setup.secret, 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP');
    expect(setup.otpauthUri, 'otpauth://totp/zh-cloud');
  });

  test('确认与关闭双重验证都通过查询参数提交当前动态码', () async {
    final captured = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
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

    expect(await api.confirmTwoFactor('123456'), isTrue);
    await api.disableTwoFactor('654321');

    expect(captured[0].path, '/app-api/todo/security/2fa/confirm');
    expect(captured[0].queryParameters, {'code': '123456'});
    expect(captured[1].path, '/app-api/todo/security/2fa/disable');
    expect(captured[1].queryParameters, {'code': '654321'});
  });
}
