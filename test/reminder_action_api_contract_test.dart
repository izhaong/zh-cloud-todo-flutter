import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart'
    as efficiency;
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart' as todo;

void main() {
  test(
    'reminder actions submit the JDK 25 dispatch identifier contract',
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
                  data: const {'code': 0, 'data': true},
                ),
              );
            },
          ),
        );

      final todoApi = todo.ReminderActionApi(ApiClient(dio: dio));
      final efficiencyApi = efficiency.ReminderActionApi(dio);

      await todoApi.complete(101);
      await todoApi.dismiss(102);
      await todoApi.snooze(103, minutes: 15);
      await efficiencyApi.dismiss(104);
      await efficiencyApi.snooze(105, minutes: 20);

      expect(requests.map((request) => request.path), [
        '/app-api/todo/reminder-action/complete',
        '/app-api/todo/reminder-action/dismiss',
        '/app-api/todo/reminder-action/snooze',
        '/app-api/todo/reminder-action/dismiss',
        '/app-api/todo/reminder-action/snooze',
      ]);
      expect(requests.map((request) => request.data), [
        {'reminderDispatchId': 101},
        {'reminderDispatchId': 102},
        {'reminderDispatchId': 103, 'minutes': 15},
        {'reminderDispatchId': 104},
        {'reminderDispatchId': 105, 'minutes': 20},
      ]);
    },
  );
}
