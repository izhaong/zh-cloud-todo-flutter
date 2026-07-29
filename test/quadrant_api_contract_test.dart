import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';

void main() {
  test('四象限规则 CRUD 与看板遵循 service CommonResult 契约', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.path.endsWith('/quadrant/list')) {
              return handler.resolve(
                _response(options, [
                  {
                    'id': 7,
                    'name': '默认四象限',
                    'ruleType': 'PRIORITY_TIME',
                    'isDefault': true,
                  },
                ]),
              );
            }
            if (options.path.endsWith('/quadrant/create')) {
              return handler.resolve(_response(options, 8));
            }
            if (options.path.endsWith('/quadrant/board')) {
              return handler.resolve(
                _response(options, {
                  'Q1_URGENT_IMPORTANT': [
                    {'id': 101, 'title': '马上处理'},
                  ],
                  'Q4_NOT_URGENT_NOT_IMPORTANT': const [],
                }),
              );
            }
            return handler.resolve(_response(options, true));
          },
        ),
      );
    final api = QuadrantApi(dio);

    final rules = await api.listRules();
    final created = await api.createRule(
      name: '按优先级',
      ruleType: QuadrantRuleType.priorityOnly,
      isDefault: false,
    );
    await api.updateRule(
      id: 7,
      name: '默认规则',
      ruleType: QuadrantRuleType.priorityTime,
      isDefault: true,
    );
    await api.deleteRule(8);
    final board = await api.board(ruleId: 7);

    expect(rules.single.id, 7);
    expect(rules.single.type, QuadrantRuleType.priorityTime);
    expect(rules.single.isDefault, isTrue);
    expect(created, 8);
    expect(board['Q1_URGENT_IMPORTANT'], {101});
    expect(
      requests
          .firstWhere((request) => request.path.endsWith('/quadrant/create'))
          .data,
      {
        'name': '按优先级',
        'ruleType': 'PRIORITY_ONLY',
        'quadrantsJson': null,
        'isDefault': false,
      },
    );
    expect(
      requests
          .firstWhere((request) => request.path.endsWith('/quadrant/update'))
          .data,
      {
        'id': 7,
        'name': '默认规则',
        'ruleType': 'PRIORITY_TIME',
        'quadrantsJson': null,
        'isDefault': true,
      },
    );
    expect(
      requests
          .firstWhere((request) => request.path.endsWith('/quadrant/delete'))
          .queryParameters,
      {'id': 8},
    );
    expect(
      requests
          .firstWhere((request) => request.path.endsWith('/quadrant/board'))
          .data,
      {'ruleId': 7, 'listId': null, 'pageNo': 1, 'pageSize': 200},
    );
  });
}

Response<Map<String, dynamic>> _response(RequestOptions options, Object? data) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    data: {'code': 0, 'data': data, 'msg': ''},
  );
}
