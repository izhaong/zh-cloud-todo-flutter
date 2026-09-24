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

  test('dueAt 走服务端真实线格式：LocalDateTime 被序列化成 epoch 毫秒', () async {
    // 判据来源（不是猜的）：
    // - `AppTodoRecommendTaskRespVO.dueAt` 是**裸 `LocalDateTime`，没有 `@JsonFormat`**；
    // - `TimestampLocalDateTimeSerializer.java:39-64` 只在字段带 `@JsonFormat` 时才写字符串，
    //   否则 `gen.writeNumber(...toEpochMilli())`。
    // 所以线上到的是**数字毫秒**；本仓原先只认 `String` ⇒ `dueAt` 恒 null ⇒
    // 独立页的「明天/后天」两个子档在真实数据下永远不渲染（页面用例是直塞 Drift，绕过了这条通道）。
    final due = DateTime(2026, 8, 3, 9, 30);
    final api = RecommendationApi(
      ApiClient(dio: _stubDio([_wireTask(dueAt: due.toIso8601String())])),
    );
    final iso = await api.list();
    final millis = await RecommendationApi(
      ApiClient(dio: _stubDio([_wireTask(dueAt: due.millisecondsSinceEpoch)])),
    ).list();

    expect(millis.single.dueAt, due, reason: '数字毫秒必须能解析出到期时间：否则子档分组是空壳');
    expect(
      iso.single.dueAt,
      due,
      reason: '既然后端带 @JsonFormat 时会改写字符串，字符串通道不能被弄坏',
    );
  });

  test('dueAt 缺失或非数字非字符串时才是 null', () async {
    final api = RecommendationApi(
      ApiClient(
        dio: _stubDio([_wireTask(dueAt: null), _wireTask(dueAt: '不是时间')]),
      ),
    );
    final list = await api.list();
    expect(list.map((e) => e.dueAt), [null, null]);
  });
}

Map<String, dynamic> _wireTask({required Object? dueAt}) => {
  'taskId': 7,
  'title': '即将到期的任务',
  'dueAt': dueAt,
  'reasonCode': 'DUE_SOON',
  'reason': '即将到期',
  'score': 900,
};

Dio _stubDio(List<Map<String, dynamic>> data) {
  return Dio(BaseOptions(baseUrl: 'https://todo.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {'code': 0, 'data': data},
            ),
          );
        },
      ),
    );
}
