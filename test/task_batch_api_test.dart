import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test(
    'batch update sends frozen idempotent contract and decodes item results',
    () async {
      RequestOptions? request;
      final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': [
                      {'taskId': 101, 'status': 'success'},
                      {
                        'taskId': 102,
                        'status': 'failed',
                        'errorCode': 'TODO_TASK_NOT_EXISTS',
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );

      final results = await TodoRestApi(ApiClient(dio: dio)).taskBatch.update(
        const TodoTaskBatchUpdateRequest(
          taskIds: [101, 102],
          priority: 3,
          completed: true,
          isPinned: true,
          deviceId: 'flutter-b3-test',
          clientMutationId: 'batch-mutation-1',
        ),
      );

      expect(request?.method, 'PUT');
      expect(
        request?.uri.toString(),
        'https://todo.test/app-api/todo/task/batch-update',
      );
      expect(request?.data, {
        'taskIds': [101, 102],
        'priority': 3,
        'completed': true,
        'isPinned': true,
        'deviceId': 'flutter-b3-test',
        'clientMutationId': 'batch-mutation-1',
      });
      expect(results.map((item) => item.status), ['success', 'failed']);
      expect(results.map((item) => item.taskId), [101, 102]);
      expect(results.last.errorCode, 'TODO_TASK_NOT_EXISTS');
    },
  );
}
