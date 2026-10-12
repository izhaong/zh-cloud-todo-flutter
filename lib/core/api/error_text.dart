import 'package:dio/dio.dart';

import 'envelope.dart';

/// 会话被服务端判为无效时的统一说法：401 兜底文案与登录页的过期说明共用这一句，
/// 避免出现「请求里说已失效、登录页说已过期」两套措辞（Issue #475）。
const String kSessionExpiredMessage = '登录状态已失效，请重新登录';

/// 用户可见文案里出现「无法归类的错误」时的兜底原因。
const String kGenericErrorReason = '请稍后重试';

/// 把捕获到的异常转成一句可直接展示给用户的原因短语。
///
/// 调用方文案形如 `Text('保存失败：${describeError(error)}')`，所以返回的是原因短语而不是
/// 完整句子，且不重复「失败」二字。
///
/// 异常对象不能直接插值：[DioException.toString] 输出的是英文诊断句，还会带上
/// `https://developer.mozilla.org/...` 这类链接，曾经整段渲染到界面上。
String describeError(Object? error) {
  if (error == null) return kGenericErrorReason;
  if (error is DioException) return _describeDio(error);
  final message = _stripClassName(error.toString());
  // 本仓自定义异常带的是中文句子（`StateError('提醒规则不存在：x')`），剥掉英文类名后
  // 可以原样展示；框架的英文原文不进界面。
  // 带 URL 或 Dart 堆栈的串是诊断信息，即使夹着中文也不给用户看。
  if (_hasCjk(message) && !_looksDiagnostic(message)) return message;
  return kGenericErrorReason;
}

String _describeDio(DioException error) {
  // 信封码先判：芋道的「未登录」是 HTTP 200 + `code:401`，若不先认这个码，
  // 就会顺着 msg 念成「账号未登录」或掉进兜底的「网络连接异常」——两句都不是原因。
  if (envelopeCode(error.response?.data) == 401) return kSessionExpiredMessage;
  final serverMessage = _serverMessage(error);
  if (serverMessage != null) return serverMessage;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => '请求超时，请稍后重试',
    DioExceptionType.connectionError => '网络连接不通，请检查网络后重试',
    DioExceptionType.badCertificate => '安全证书校验未通过，请稍后重试',
    DioExceptionType.cancel => '请求已取消',
    DioExceptionType.badResponse => _statusMessage(error.response?.statusCode),
    DioExceptionType.unknown => '网络连接异常，请稍后重试',
  };
}

/// 芋道信封 `{code,msg,data}` 里的 `msg` 本来就是中文，优先用它。
String? _serverMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final msg = data['msg'];
  if (msg is! String) return null;
  final trimmed = msg.trim();
  if (trimmed.isEmpty) return null;
  // 先按整句判诊断串，再截断：截断可能把句尾的 URL 切掉，就漏过去了。
  if (_looksDiagnostic(trimmed)) return null;
  return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
}

String _statusMessage(int? code) {
  if (code == 401) return kSessionExpiredMessage;
  if (code == 403) return '没有权限执行该操作';
  if (code == 404) return '请求的内容找不到，请稍后重试';
  if (code != null && code >= 500) return '服务暂时不可用，请稍后重试';
  if (code == null) return '服务返回异常，请稍后重试';
  return '服务返回异常（HTTP $code），请稍后重试';
}

/// 剥掉 `Exception: ` / `Bad state: ` 这类英文类名前缀。
final RegExp _classNamePrefix = RegExp(
  r'^[A-Za-z][A-Za-z0-9_$.]*(?: [A-Za-z][A-Za-z0-9_$.]*)*: *',
);

String _stripClassName(String text) => text.replaceFirst(_classNamePrefix, '');

/// 是否含中日韩文字（U+3000–U+9FFF：含全角标点与汉字）。
/// 用作「这句是不是本仓自己写的中文文案」的判据，英文诊断句不会落进这个区间。
bool _hasCjk(String text) => text.contains(RegExp('[\\u3000-\\u9fff]'));

/// 带链接或 Dart 堆栈帧的串属于诊断信息，不该出现在界面上。
final RegExp _diagnosticMarkers = RegExp(r'https?://|package:|dart:');

bool _looksDiagnostic(String text) => _diagnosticMarkers.hasMatch(text);
