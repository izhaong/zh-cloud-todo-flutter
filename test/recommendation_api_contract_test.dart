import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('推荐请求发送客户端本地日期和精确日界线', () async {
    RequestOptions? captured;
    final now = DateTime(2026, 8, 2, 10, 30);
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': <dynamic>[]},
              ),
            );
          },
        ),
      );
    final api = RecommendationApi(ApiClient(dio: dio), now: () => now);

    await api.list(limit: 10);

    final today = DateTime(2026, 8, 2);
    final tomorrow = DateTime(2026, 8, 3);
    final upcomingEnd = DateTime(2026, 8, 5);
    expect(captured?.path, '/app-api/todo/help/recommend-tasks');
    expect(captured?.queryParameters, {
      'limit': 10,
      'today': '2026-08-02',
      'todayStartEpochMillis': today.millisecondsSinceEpoch,
      'tomorrowStartEpochMillis': tomorrow.millisecondsSinceEpoch,
      'upcomingEndEpochMillis': upcomingEnd.millisecondsSinceEpoch,
    });
  });
}
