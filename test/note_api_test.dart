import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('note API parses list and scalar ids from CommonResult', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.path.endsWith('/note/list')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': [
                      {
                        'id': 7,
                        'title': '周报',
                        'content': '# 完成',
                        'contentType': 2,
                        'archived': false,
                        'taskId': 99,
                      },
                    ],
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': 8},
              ),
            );
          },
        ),
      );
    final api = NoteApi(ApiClient(dio: dio));

    final notes = await api.list();
    final created = await api.create(title: '新笔记', content: '正文');
    final converted = await api.convertFromTask(99);

    expect(notes.single.title, '周报');
    expect(notes.single.taskId, 99);
    expect(created, 8);
    expect(converted, 8);
    expect(requests[1].data, containsPair('contentType', 2));
    expect(requests[2].queryParameters, {'taskId': 99});
  });

  test('note archive and delete use query parameters', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': true},
              ),
            );
          },
        ),
      );
    final api = NoteApi(ApiClient(dio: dio));

    await api.archive(7, archived: true);
    await api.delete(7);

    expect(requests[0].queryParameters, {'id': 7, 'archived': true});
    expect(requests[1].queryParameters, {'id': 7});
  });
}
