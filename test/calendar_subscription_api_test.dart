import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  test('calendar subscription API follows the service contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.path.endsWith('/cal-sub/list')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': [
                      {
                        'id': 9,
                        'name': '团队日历',
                        'sourceUrl': 'https://example.com/team.ics',
                        'subscribeToken': 'token-9',
                        'lastSyncedAt': '2026-07-30T09:30:00',
                        'status': 'ERROR',
                      },
                    ],
                  },
                ),
              );
              return;
            }
            if (options.path.endsWith('/cal-sub/create')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {'code': 0, 'data': 12},
                ),
              );
              return;
            }
            if (options.path.endsWith('/cal-sub/export-url')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': 'https://todo.example/feed/token.ics',
                  },
                ),
              );
              return;
            }
            if (options.path.endsWith('/cal-sub/events')) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': [
                      {
                        'subscriptionId': 9,
                        'sourceName': '团队日历',
                        'uid': 'meeting-1',
                        'title': '团队周会',
                        'description': '只读事件',
                        'startAt': '2026-07-30T09:00:00+08:00',
                        'endAt': '2026-07-30T10:00:00+08:00',
                        'allDay': false,
                        'readOnly': true,
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
                data: {'code': 0, 'data': true},
              ),
            );
          },
        ),
      );
    final api = CalendarSubscriptionApi(ApiClient(dio: dio));

    final items = await api.list();
    final created = await api.create(
      url: 'https://example.com/new.ics',
      name: '新日历',
    );
    await api.delete(9);
    final exportUrl = await api.exportUrl();
    final events = await api.events(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );

    expect(items.single.url, 'https://example.com/team.ics');
    expect(items.single.enabled, isFalse);
    expect(items.single.lastSyncAt, DateTime(2026, 7, 30, 9, 30));
    expect(items.single.syncToken, 'token-9');
    expect(created, 12);
    expect(requests[1].data, {
      'sourceUrl': 'https://example.com/new.ics',
      'name': '新日历',
    });
    expect(requests[2].queryParameters, {'id': 9});
    expect(exportUrl, 'https://todo.example/feed/token.ics');
    expect(events.single.sourceName, '团队日历');
    expect(events.single.title, '团队周会');
    expect(events.single.readOnly, isTrue);
    expect(requests[4].queryParameters, {
      'start': '2026-07-01',
      'end': '2026-07-31',
    });
  });
}
