import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test(
    'task completion actions submit id as the JDK 25 request parameter',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: const {'code': 0, 'data': true},
                ),
              );
            },
          ),
        );
      final api = TaskRestApi(ApiClient(dio: dio));

      await api.complete(201);
      await api.uncomplete(202);

      expect(requests.map((request) => request.path), [
        '/app-api/todo/task/complete',
        '/app-api/todo/task/uncomplete',
      ]);
      expect(requests.map((request) => request.queryParameters), [
        {'id': 201},
        {'id': 202},
      ]);
      expect(requests.map((request) => request.data), everyElement(isNull));
    },
  );
}
