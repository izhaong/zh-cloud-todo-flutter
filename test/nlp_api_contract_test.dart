import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test(
    'NLP API parses the complete JDK 25 backend response contract',
    () async {
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
                    'data': {
                      'planDate': '2026-08-01T15:00:00',
                      'reminderTime': '2026-08-01T14:45:00',
                      'priority': 'HIGH',
                    },
                  },
                ),
              );
            },
          ),
        );
      final api = NlpApi(ApiClient(dio: dio));

      final result = await api.parse('明天下午3点开会，高优先级');
      final due = await api.parseDue(const ['明天下午3点开会']);

      expect(result.planDate, DateTime(2026, 8, 1, 15));
      expect(result.reminderTime, DateTime(2026, 8, 1, 14, 45));
      expect(result.priority, 'HIGH');
      expect(due, DateTime(2026, 8, 1, 15));
      expect(requests, hasLength(2));
      expect(requests[0].method, 'POST');
      expect(requests[0].path, '/app-api/todo/nlp/parse');
      expect(requests[0].data, {'text': '明天下午3点开会，高优先级'});
    },
  );
}
