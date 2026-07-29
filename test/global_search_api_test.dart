import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test(
    'global search sends the frozen page contract and decodes all result types',
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
                    'data': {
                      'total': 3,
                      'list': [
                        {
                          'type': 'task',
                          'id': 101,
                          'title': '周报复盘',
                          'listId': 11,
                        },
                        {
                          'type': 'list',
                          'id': 11,
                          'title': '本周计划',
                          'listId': 11,
                        },
                        {'type': 'tag', 'id': 21, 'title': '周报'},
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );

      final page = await TodoRestApi(
        ApiClient(dio: dio),
      ).globalSearch.search(keyword: ' 周报 ', pageNo: 2, pageSize: 20);

      expect(
        request?.uri.toString(),
        'https://todo.test/app-api/todo/task/global-search?keyword=%E5%91%A8%E6%8A%A5&pageNo=2&pageSize=20',
      );
      expect(page.total, 3);
      expect(page.items.map((item) => item.type), ['task', 'list', 'tag']);
      expect(page.items.map((item) => item.id), [101, 11, 21]);
      expect(page.items.first.listId, 11);
      expect(page.items.last.listId, isNull);
    },
  );
}
