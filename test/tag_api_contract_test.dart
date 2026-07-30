import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('tag binding API matches the JDK 25 backend contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': options.method == 'POST' ? 2 : true},
              ),
            );
          },
        ),
      );
    final api = TagApi(ApiClient(dio: dio));

    final boundCount = await api.taskBind(
      taskId: 42,
      tagServerIds: const [7, 8],
    );
    await api.taskUnbind(taskId: 42, tagServerId: 7);

    expect(boundCount, 2);
    expect(requests[0].method, 'POST');
    expect(requests[0].path, '/app-api/todo/tag/task-bind');
    expect(requests[0].data, {
      'taskId': 42,
      'tagIds': [7, 8],
    });
    expect(requests[1].method, 'DELETE');
    expect(requests[1].path, '/app-api/todo/tag/task-unbind');
    expect(requests[1].data, {'taskId': 42, 'tagId': 7});
  });
}
