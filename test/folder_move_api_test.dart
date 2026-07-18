import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('folder move-list sends the server listIds contract', () async {
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': 2},
              ),
            );
          },
        ),
      );

    await FolderApi(
      ApiClient(dio: dio),
    ).moveLists(listServerIds: const [101, 102], folderServerId: 88);

    expect(request?.method, 'POST');
    expect(
      request?.uri.toString(),
      'https://todo.test/app-api/todo/folder/move-list',
    );
    expect(request?.data, {
      'listIds': [101, 102],
      'folderId': 88,
    });
  });
}
