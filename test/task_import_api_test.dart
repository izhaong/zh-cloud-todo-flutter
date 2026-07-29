import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('任务导入提交稳定请求号、目标清单与归一化任务', () async {
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
                    'batchId': 91,
                    'requestId': 'request-stable',
                    'source': 'PORTABLE_JSON',
                    'targetListId': 12,
                    'status': 'COMPLETED',
                    'importedCount': 1,
                    'rolledBackCount': 0,
                    'idempotentReplay': false,
                    'createTime': '2026-07-30T08:00:00',
                    'updateTime': '2026-07-30T08:00:00',
                  },
                  'msg': '',
                },
              ),
            );
          },
        ),
      );
    final api = TodoTaskImportApi(ApiClient(dio: dio));
    final task = PortableTaskImportTask(
      sourceTaskId: 'source-1',
      title: '准备周报',
      description: '汇总本周进度',
      dueAt: DateTime(2026, 7, 31, 18),
      priority: 3,
      completed: false,
    );

    final batch = await api.importTasks(
      requestId: 'request-stable',
      targetListId: 12,
      tasks: [task],
    );

    expect(captured?.path, '/app-api/todo/import-health/tasks');
    expect(captured?.method, 'POST');
    expect(captured?.data, {
      'requestId': 'request-stable',
      'source': 'PORTABLE_JSON',
      'targetListId': 12,
      'tasks': [
        {
          'sourceTaskId': 'source-1',
          'title': '准备周报',
          'description': '汇总本周进度',
          'dueAt': '2026-07-31T18:00:00.000',
          'priority': 3,
          'completed': false,
        },
      ],
    });
    expect(batch.batchId, 91);
    expect(batch.status, 'COMPLETED');
    expect(batch.importedCount, 1);
    expect(batch.idempotentReplay, isFalse);
  });

  test('任务导入批次查询与回滚使用当前后端契约', () async {
    final captured = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
            final data = options.path.endsWith('/rollback')
                ? {
                    'batchId': 91,
                    'requestId': 'request-stable',
                    'source': 'PORTABLE_JSON',
                    'targetListId': 12,
                    'status': 'ROLLED_BACK',
                    'importedCount': 2,
                    'rolledBackCount': 2,
                    'idempotentReplay': false,
                  }
                : [
                    {
                      'batchId': 91,
                      'requestId': 'request-stable',
                      'source': 'PORTABLE_JSON',
                      'targetListId': 12,
                      'status': 'COMPLETED',
                      'importedCount': 2,
                      'rolledBackCount': 0,
                      'idempotentReplay': false,
                    },
                  ];
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': data, 'msg': ''},
              ),
            );
          },
        ),
      );
    final api = TodoTaskImportApi(ApiClient(dio: dio));

    final batches = await api.listBatches();
    final rolledBack = await api.rollback(91);

    expect(captured[0].path, '/app-api/todo/import-health/task-batches');
    expect(captured[0].method, 'GET');
    expect(captured[1].path, '/app-api/todo/import-health/rollback');
    expect(captured[1].method, 'POST');
    expect(captured[1].queryParameters, {'batchId': 91});
    expect(batches.single.importedCount, 2);
    expect(rolledBack.status, 'ROLLED_BACK');
    expect(rolledBack.rolledBackCount, 2);
  });

  test('相同请求并发处理中保留业务码供界面提示重试', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'code': TodoTaskImportApi.busyCode,
                'data': null,
                'msg': '相同导入请求正在处理中，请稍后重试',
              },
            ),
          ),
        ),
      );
    final api = TodoTaskImportApi(ApiClient(dio: dio));

    await expectLater(
      api.importTasks(
        requestId: 'request-stable',
        targetListId: 12,
        tasks: const [PortableTaskImportTask(title: '任务')],
      ),
      throwsA(
        isA<TodoTaskImportException>().having(
          (error) => error.code,
          'code',
          TodoTaskImportApi.busyCode,
        ),
      ),
    );
  });

  test('任务导入目标清单通过当前用户 owner 角色校验', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'code': 0,
                'data': [
                  {'userId': 8, 'role': 'owner'},
                  {'userId': 9, 'role': 'member'},
                ],
                'msg': '',
              },
            ),
          ),
        ),
      );
    final api = ListCollaborationApi(ApiClient(dio: dio));

    expect(await api.isOwner(listId: 12, userId: 8), isTrue);
    expect(await api.isOwner(listId: 12, userId: 9), isFalse);
  });
}
