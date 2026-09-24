import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';

Response<Map<String, dynamic>> _envelope(
  RequestOptions options,
  Object? data, {
  int code = 0,
  String msg = '',
}) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    data: {'code': code, 'data': data, 'msg': msg},
  );
}

Dio _stubDio(List<RequestOptions> requests, {int code = 0, String msg = ''}) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          if (path.endsWith('/countdown/list')) {
            return handler.resolve(
              _envelope(
                options,
                [
                  {
                    'id': 7,
                    'name': '发布日',
                    'targetDate': '2026-08-10',
                    'daysRemaining': 11,
                    'style': 3,
                    'showAge': true,
                  },
                ],
                code: code,
                msg: msg,
              ),
            );
          }
          return handler.resolve(
            _envelope(options, true, code: code, msg: msg),
          );
        },
      ),
    );
}

void main() {
  test(
    'countdown update PUTs the server update contract and nothing else',
    () async {
      final requests = <RequestOptions>[];
      await CountdownApi(_stubDio(requests)).update(
        id: 7,
        title: '发布日',
        targetDate: DateTime(2026, 8, 10),
        style: 3,
        showAge: true,
      );

      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/app-api/todo/countdown/update');
      expect(request.data, {
        'id': 7,
        'name': '发布日',
        'targetDate': '2026-08-10',
        'style': 3,
        'showAge': true,
      });
    },
  );

  test('countdown delete sends the id as a query parameter', () async {
    final requests = <RequestOptions>[];
    await CountdownApi(_stubDio(requests)).delete(7);

    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.path.endsWith('/countdown/delete'), isTrue);
    expect(request.queryParameters['id'], 7);
  });

  test('countdown update throws on a business error inside HTTP 200', () async {
    final requests = <RequestOptions>[];
    final api = CountdownApi(_stubDio(requests, code: 1, msg: '倒数纪念日不存在'));

    await expectLater(
      api.update(
        id: 7,
        title: '发布日',
        targetDate: DateTime(2026, 8, 10),
        style: 3,
        showAge: true,
      ),
      throwsA(
        isA<DioException>().having((e) => '${e.error}', '业务错误文案', '倒数纪念日不存在'),
      ),
    );
  });

  test('countdown delete throws on a business error inside HTTP 200', () async {
    final requests = <RequestOptions>[];
    final api = CountdownApi(_stubDio(requests, code: 1, msg: '倒数纪念日不存在'));

    await expectLater(
      api.delete(7),
      throwsA(
        isA<DioException>().having((e) => '${e.error}', '业务错误文案', '倒数纪念日不存在'),
      ),
    );
  });

  test(
    'countdown list parses style and showAge for the card to render',
    () async {
      final requests = <RequestOptions>[];
      final items = await CountdownApi(_stubDio(requests)).list();

      expect(requests.single.method, 'GET');
      expect(items.single.id, 7);
      expect(items.single.style, 3);
      expect(items.single.showAge, isTrue);
    },
  );
}
