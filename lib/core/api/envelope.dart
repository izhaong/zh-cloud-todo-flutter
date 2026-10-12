import 'package:dio/dio.dart';

/// 芋道信封 `{code, msg, data}` 里 `code != 0` 的统一异常形状。
///
/// 「未登录」这类失败 HTTP 状态仍是 200，业务码只藏在 body 里，所以必须把 body 挂在
/// `response.data` 上带出去：`describeError` 靠它区分「登录已失效」和「网络不通」，
/// `ApiClient` 的响应拦截器也靠它在信封里认出 401（dio 的 `onError` 只对真 HTTP 错误生效）。
///
/// 类型仍然保持 [DioException] 是刻意的：`lib` 里三处 `on DioException` 兜底
/// （含 sync_coordinator 那条「folder REST 不可用不能阻断同步白名单实体」）
/// 还得继续接住业务失败，换成新异常类型会让它们静默失守。
DioException envelopeFailure(
  Map<String, dynamic> body, {
  required String path,
  String fallback = '请求失败',
}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: body,
    ),
    error: body['msg'] ?? fallback,
  );
}

/// 读信封里的业务码；不是信封（没有 `code` 键）就返回 null。
int? envelopeCode(Object? data) {
  if (data is! Map) return null;
  if (!data.containsKey('code')) return null;
  return int.tryParse(data['code'].toString());
}
