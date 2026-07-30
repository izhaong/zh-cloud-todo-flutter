import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('checklist API matches the JDK 25 backend contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': options.method == 'GET'
                      ? [
                          {
                            'id': 71,
                            'parentTaskId': 12,
                            'title': '已有事项',
                            'completed': false,
                          },
                        ]
                      : options.path.endsWith('/create')
                      ? 77
                      : true,
                },
              ),
            );
          },
        ),
      );
    final api = ChecklistApi(ApiClient(dio: dio));

    final items = await api.list(12);
    final id = await api.create(
      taskId: 12,
      name: '准备材料',
      assigneeUserId: 99,
      sortOrder: 3,
    );
    await api.update(77, name: '确认材料', done: true);
    await api.delete(77);

    expect(items.single.id, 71);
    expect(items.single.taskId, '12');
    expect(items.single.title, '已有事项');
    expect(id, 77);
    expect(requests[0].method, 'GET');
    expect(requests[0].path, '/app-api/todo/task-hierarchy/checklist');
    expect(requests[0].queryParameters, {'taskId': 12});
    expect(requests[1].method, 'POST');
    expect(requests[1].path, '/app-api/todo/task-hierarchy/checklist/create');
    expect(requests[1].data, {
      'taskId': 12,
      'name': '准备材料',
      'assigneeUserId': 99,
      'sortOrder': 3,
    });
    expect(requests[2].method, 'PUT');
    expect(requests[2].path, '/app-api/todo/task-hierarchy/checklist/update');
    expect(requests[2].data, {'id': 77, 'name': '确认材料', 'done': true});
    expect(requests[3].method, 'DELETE');
    expect(requests[3].path, '/app-api/todo/task-hierarchy/checklist/delete');
    expect(requests[3].queryParameters, {'id': 77});
    expect(requests[3].data, isNull);
  });
}
