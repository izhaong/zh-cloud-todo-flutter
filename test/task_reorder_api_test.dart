import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('task reorder sends listId and explicit sort-order items', () async {
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': true},
              ),
            );
          },
        ),
      );

    await TaskRestApi(ApiClient(dio: dio)).reorder(
      listId: 88,
      items: const [
        TodoTaskReorderItem(id: 102, sortOrder: 0),
        TodoTaskReorderItem(id: 101, sortOrder: 1),
      ],
    );

    expect(request?.method, 'PUT');
    expect(
      request?.uri.toString(),
      'https://todo.test/app-api/todo/task/reorder',
    );
    expect(request?.data, {
      'listId': 88,
      'items': [
        {'id': 102, 'sortOrder': 0},
        {'id': 101, 'sortOrder': 1},
      ],
    });
  });
}
