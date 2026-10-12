import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/features/import/task_import_page.dart';

void main() {
  test('解析 B13 导出信封与 snake_case 字段', () {
    final file = PortableTaskImportFile.parse(
      name: 'todo-export.json',
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'data': {
              'tasks': [
                {
                  'id': 31,
                  'title': '  准备周报  ',
                  'description': '汇总本周进度',
                  'due_at': '2026-07-31T18:00:00',
                  'priority': 3,
                  'status': 'COMPLETED',
                  'completed_at': '2026-07-30T18:00:00',
                },
              ],
            },
          }),
        ),
      ),
    );

    expect(file.tasks, hasLength(1));
    expect(file.source, 'ZH_CLOUD_EXPORT');
    expect(file.tasks.single.sourceTaskId, '31');
    expect(file.tasks.single.title, '准备周报');
    expect(file.tasks.single.dueAt, DateTime(2026, 7, 31, 18));
    expect(file.tasks.single.priority, 3);
    expect(file.tasks.single.completed, isTrue);
  });

  test('解析根级 tasks 与 camelCase 字段并忽略空标题任务', () {
    final file = PortableTaskImportFile.parse(
      name: 'portable.json',
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'tasks': [
              {
                'sourceTaskId': 'external-1',
                'title': '外部任务',
                'dueAt': '2026-08-01T09:30:00',
                'priority': 8,
                'completed': false,
              },
              {'title': '   '},
            ],
          }),
        ),
      ),
    );

    expect(file.tasks, hasLength(1));
    expect(file.source, 'PORTABLE_JSON');
    expect(file.tasks.single.sourceTaskId, 'external-1');
    expect(file.tasks.single.priority, 3);
    expect(file.skippedCount, 1);
  });

  testWidgets('选择文件后预览数量并导入到同步清单', (tester) async {
    final requests = <RequestOptions>[];
    var imported = false;
    final api = TodoTaskImportApi(
      ApiClient(
        dio: Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                final dynamic data;
                if (options.path.endsWith('/task-batches')) {
                  data = imported
                      ? [
                          {
                            'batchId': 91,
                            'requestId': 'captured',
                            'source': 'PORTABLE_JSON',
                            'targetListId': 12,
                            'status': 'COMPLETED',
                            'importedCount': 2,
                            'rolledBackCount': 0,
                            'idempotentReplay': false,
                          },
                        ]
                      : <dynamic>[];
                } else {
                  imported = true;
                  final body = Map<String, dynamic>.from(options.data as Map);
                  data = {
                    'batchId': 91,
                    'requestId': body['requestId'],
                    'source': 'PORTABLE_JSON',
                    'targetListId': 12,
                    'status': 'COMPLETED',
                    'importedCount': 2,
                    'rolledBackCount': 0,
                    'idempotentReplay': false,
                  };
                }
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': data, 'msg': ''},
                  ),
                );
              },
            ),
          ),
      ),
    );
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'tasks': [
            {'id': 1, 'title': '任务一'},
            {'id': 2, 'title': '任务二', 'status': 'COMPLETED'},
          ],
        }),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TaskImportPage(
            api: api,
            targets: const [TaskImportTarget(id: 12, name: '工作')],
            filePicker: () async => PortableTaskImportFile.parse(
              name: 'portable.json',
              bytes: bytes,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-import-pick-file')));
    await tester.pumpAndSettle();
    expect(find.text('portable.json'), findsOneWidget);
    expect(find.text('可导入 2 个任务'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-import-submit')));
    await tester.pumpAndSettle();

    final request = requests.firstWhere(
      (item) => item.path.endsWith('/import-health/tasks'),
    );
    final body = Map<String, dynamic>.from(request.data as Map);
    expect(body['requestId'], isNotEmpty);
    expect(body['source'], 'PORTABLE_JSON');
    expect(body['targetListId'], 12);
    expect(body['tasks'], hasLength(2));
    expect(find.text('已导入 2 个任务'), findsOneWidget);
    expect(find.text('导入 2 · 已回滚 0'), findsOneWidget);
  });

  testWidgets('忙碌后重试复用同一请求号且不会重复导入', (tester) async {
    final requestIds = <String>[];
    var importAttempts = 0;
    final api = TodoTaskImportApi(
      ApiClient(
        dio: Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/task-batches')) {
                  handler.resolve(
                    Response<Map<String, dynamic>>(
                      requestOptions: options,
                      data: {'code': 0, 'data': <dynamic>[], 'msg': ''},
                    ),
                  );
                  return;
                }
                importAttempts++;
                final body = Map<String, dynamic>.from(options.data as Map);
                requestIds.add(body['requestId'] as String);
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: importAttempts == 1
                        ? {
                            'code': TodoTaskImportApi.busyCode,
                            'data': null,
                            'msg': '相同导入请求正在处理中，请稍后重试',
                          }
                        : {
                            'code': 0,
                            'data': {
                              'batchId': 91,
                              'requestId': body['requestId'],
                              'source': 'PORTABLE_JSON',
                              'targetListId': 12,
                              'status': 'COMPLETED',
                              'importedCount': 1,
                              'rolledBackCount': 0,
                              'idempotentReplay': false,
                            },
                            'msg': '',
                          },
                  ),
                );
              },
            ),
          ),
      ),
    );
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'tasks': [
            {'title': '任务'},
          ],
        }),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TaskImportPage(
            api: api,
            targets: const [TaskImportTarget(id: 12, name: '工作')],
            filePicker: () async => PortableTaskImportFile.parse(
              name: 'portable.json',
              bytes: bytes,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-import-pick-file')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-import-submit')));
    await tester.pumpAndSettle();
    expect(find.text('相同导入请求正在处理中，请稍后重试'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-import-submit')));
    await tester.pumpAndSettle();
    expect(requestIds, hasLength(2));
    expect(requestIds[1], requestIds[0]);
    expect(find.text('已导入 1 个任务'), findsOneWidget);
  });

  testWidgets('导入历史可确认后按批回滚', (tester) async {
    final requests = <RequestOptions>[];
    var rolledBack = false;
    final api = TodoTaskImportApi(
      ApiClient(
        dio: Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                final batch = {
                  'batchId': 91,
                  'requestId': 'request-stable',
                  'source': 'PORTABLE_JSON',
                  'targetListId': 12,
                  'status': rolledBack ? 'ROLLED_BACK' : 'COMPLETED',
                  'importedCount': 2,
                  'rolledBackCount': rolledBack ? 2 : 0,
                  'idempotentReplay': false,
                };
                if (options.path.endsWith('/rollback')) rolledBack = true;
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {
                      'code': 0,
                      'data': options.path.endsWith('/task-batches')
                          ? [batch]
                          : {
                              ...batch,
                              'status': 'ROLLED_BACK',
                              'rolledBackCount': 2,
                            },
                      'msg': '',
                    },
                  ),
                );
              },
            ),
          ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TaskImportPage(
            api: api,
            targets: const [TaskImportTarget(id: 12, name: '工作')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-import-rollback-91')));
    await tester.pumpAndSettle();
    expect(find.text('回滚本批导入？'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('task-import-rollback-confirm-91')),
    );
    await tester.pumpAndSettle();

    final request = requests.firstWhere(
      (item) => item.path.endsWith('/import-health/rollback'),
    );
    expect(request.queryParameters, {'batchId': 91});
    expect(find.text('已回滚 2 个任务'), findsOneWidget);
    expect(find.text('已回滚'), findsOneWidget);
  });
}
