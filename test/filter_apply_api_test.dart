import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test(
    'filter apply sends the frozen pagination contract and keeps server order',
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
                      'total': 2,
                      'list': [
                        {'id': 301, 'title': '置顶且高优先级', 'priority': 3},
                        {'id': 302, 'title': '普通高优先级', 'priority': 3},
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
      ).filter.apply(filterId: 91, pageNo: 2, pageSize: 50);

      expect(
        request?.uri.toString(),
        'https://todo.test/app-api/todo/filter/apply',
      );
      expect(request?.data, {'id': 91, 'pageNo': 2, 'pageSize': 50});
      expect(page.total, 2);
      expect(page.items.map((item) => item.id), [301, 302]);
      expect(page.items.map((item) => item.title), ['置顶且高优先级', '普通高优先级']);
      expect(page.items.map((item) => item.priority), [3, 3]);
    },
  );
}
