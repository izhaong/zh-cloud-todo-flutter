import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/error_text.dart';

final RequestOptions _options = RequestOptions(path: '/app-api/todo/tag/list');

DioException _dio(
  DioExceptionType type, {
  Response<Object?>? response,
  Object? error,
}) {
  return DioException(
    requestOptions: _options,
    type: type,
    response: response,
    error: error,
  );
}

Response<Object?> _envelope(Object? data) {
  return Response<Object?>(requestOptions: _options, data: data);
}

/// web 实测（Issue #468）量到的那条原文：习惯页把它整段渲染给了用户。
DioException _corsConnectionError() {
  return _dio(
    DioExceptionType.connectionError,
    error: StateError(
      'The XMLHttpRequest onError callback was called. This indicates an error '
      'which most likely cannot be solved by the library. See '
      'https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests',
    ),
  );
}

void main() {
  group('describeError 把异常转成中文原因短语', () {
    test('连接失败只给「网络连接不通」，不带 DioException 原文', () {
      final text = describeError(_corsConnectionError());
      expect(text, '网络连接不通，请检查网络后重试');
      expect(text, isNot(contains('DioException')));
      expect(text, isNot(contains('mozilla')));
      expect(text, isNot(contains('CORS')));
    });

    test('芋道信封的中文 msg 优先于分类文案', () {
      final text = describeError(
        _dio(
          DioExceptionType.badResponse,
          response: _envelope(const {
            'code': 400,
            'msg': '请求参数不正确:密码长度为 4-16 位',
          }),
        ),
      );
      expect(text, '请求参数不正确:密码长度为 4-16 位');
    });

    test('超长的 msg 截到 60 字加省略号', () {
      final long = '字' * 80;
      final text = describeError(
        _dio(
          DioExceptionType.badResponse,
          response: _envelope({'code': 500, 'msg': long}),
        ),
      );
      expect(text, '${'字' * 60}…');
    });

    test('三类超时归为「请求超时」', () {
      for (final type in const [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(describeError(_dio(type)), '请求超时，请稍后重试', reason: '$type');
      }
    });

    test('HTTP 状态码各档给对应的中文', () {
      Response<Object?> withStatus(int code) =>
          Response<Object?>(requestOptions: _options, statusCode: code);
      expect(
        describeError(
          _dio(DioExceptionType.badResponse, response: withStatus(401)),
        ),
        '登录状态已失效，请重新登录',
      );
      expect(
        describeError(
          _dio(DioExceptionType.badResponse, response: withStatus(403)),
        ),
        '没有权限执行该操作',
      );
      expect(
        describeError(
          _dio(DioExceptionType.badResponse, response: withStatus(404)),
        ),
        '请求的内容找不到，请稍后重试',
      );
      expect(
        describeError(
          _dio(DioExceptionType.badResponse, response: withStatus(503)),
        ),
        '服务暂时不可用，请稍后重试',
      );
      expect(
        describeError(
          _dio(DioExceptionType.badResponse, response: withStatus(429)),
        ),
        '服务返回异常（HTTP 429），请稍后重试',
      );
    });

    test('取消与未知与 null 都有中文兜底', () {
      expect(describeError(_dio(DioExceptionType.cancel)), '请求已取消');
      expect(describeError(_dio(DioExceptionType.unknown)), '网络连接异常，请稍后重试');
      expect(describeError(null), kGenericErrorReason);
    });

    test('本仓自定义异常的中文句子原样展示，剥掉英文类名', () {
      expect(describeError(StateError('提醒规则不存在：abc123')), '提醒规则不存在：abc123');
      expect(describeError(Exception('同步队列未就绪')), '同步队列未就绪');
    });

    test('框架的英文原文不进界面', () {
      expect(
        describeError(Exception('Bad state: something exploded')),
        kGenericErrorReason,
      );
      expect(
        describeError(FormatException('invalid date')),
        kGenericErrorReason,
      );
      expect(describeError(42), kGenericErrorReason);
    });
  });
}
