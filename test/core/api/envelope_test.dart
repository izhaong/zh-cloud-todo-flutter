import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/envelope.dart';
import 'package:zh_cloud_todo_flutter/core/api/error_text.dart';

/// 只回 HTTP 200 + 指定信封的假传输层（芋道的业务失败就是这个形状）。
class _EnvelopeAdapter implements HttpClientAdapter {
  _EnvelopeAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWithEnvelope(String body, {void Function()? onUnauthorized}) {
  final client = ApiClient(onUnauthorized: onUnauthorized);
  client.raw.httpClientAdapter = _EnvelopeAdapter(body);
  return client;
}

void main() {
  test('信封 401 说成登录失效，不是网络异常', () {
    final error = envelopeFailure(const {
      'code': 401,
      'msg': '账号未登录',
      'data': null,
    }, path: '/app-api/todo/habit/list');
    expect(describeError(error), kSessionExpiredMessage);
  });

  test('其它信封码用服务端自己那句中文，不再退化成网络异常', () {
    final error = envelopeFailure(const {
      'code': 500,
      'msg': '同步失败：数据表结构不匹配',
      'data': null,
    }, path: '/app-api/todo/sync/push');
    expect(describeError(error), '同步失败：数据表结构不匹配');
  });

  test('envelopeCode 只认带 code 的信封，容忍字符串码', () {
    expect(envelopeCode({'code': 401}), 401);
    expect(envelopeCode({'code': '401'}), 401);
    expect(envelopeCode({'data': 1}), isNull);
    expect(envelopeCode('not a map'), isNull);
    expect(envelopeCode(null), isNull);
  });

  test('HTTP 200 + 信封 401 也触发 onUnauthorized（dio 的 onError 看不见这一档）', () async {
    var fired = 0;
    final client = _clientWithEnvelope(
      '{"code":401,"msg":"账号未登录","data":null}',
      onUnauthorized: () => fired++,
    );
    // 注意：HTTP 是 200，所以 dio 本身不抛；「这是失败」由信封判定。
    await client.get<Map<String, dynamic>>('/lists');

    expect(fired, 1);
  });

  test('反向对照：成功信封不触发 onUnauthorized', () async {
    var fired = 0;
    final client = _clientWithEnvelope(
      '{"code":0,"msg":"","data":[]}',
      onUnauthorized: () => fired++,
    );
    await client.get<Map<String, dynamic>>('/lists');

    expect(fired, 0);
  });
}
