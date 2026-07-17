import 'package:dio/dio.dart';

import '../api/api_client.dart';
import 'auth_session.dart';

export 'auth_session.dart' show TodoAuthSession, TodoAuthException;

/// 认证网关抽象（便于测试用 Fake 注入）。
abstract class AuthGateway {
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  });

  Future<void> sendSmsCode({required String mobile, required int scene});

  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  });

  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  });

  Future<void> logout(String accessToken);

  /// 校验 accessToken 是否仍被后端认可；网络异常向调用方抛出以保留离线会话。
  Future<bool> validateSession(String accessToken);

  void close();
}

/// 基于 [ApiClient]（dio）的认证网关实现：`/app-api/todo-member/**`。
class AuthGatewayImpl implements AuthGateway {
  AuthGatewayImpl(this._client, {required this.tenantId});

  final ApiClient _client;
  final String tenantId;

  /// 统一响应信封 `{code,msg,data}`：`code != 0` 抛 [TodoAuthException]。
  dynamic _unwrap(Response<dynamic> resp) {
    final body = resp.data;
    if (body is Map<String, dynamic> && body.containsKey('code')) {
      final code = body['code'];
      if (code != 0) {
        throw TodoAuthException(
          body['msg']?.toString() ?? body['message']?.toString() ?? '账号请求失败',
        );
      }
      return body['data'];
    }
    return body;
  }

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  }) async {
    final resp = await _client.memberPost<Map<String, dynamic>>(
      '/auth/login',
      data: {'mobile': mobile, 'password': password, 'terminal': '30'},
    );
    final data = _unwrap(resp);
    if (data is! Map) {
      throw const TodoAuthException('登录响应缺少用户凭证');
    }
    return TodoAuthSession.fromResponse(
      Map<String, dynamic>.from(data),
      mobile: mobile,
      tenantId: tenantId,
    );
  }

  @override
  Future<void> sendSmsCode({required String mobile, required int scene}) async {
    final resp = await _client.memberPost<Map<String, dynamic>>(
      '/auth/send-sms-code',
      data: {'mobile': mobile, 'scene': scene},
    );
    _unwrap(resp);
  }

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  }) async {
    final resp = await _client.memberPost<Map<String, dynamic>>(
      '/auth/sms-login',
      data: {'mobile': mobile, 'code': code, 'terminal': '30'},
    );
    final data = _unwrap(resp);
    if (data is! Map) {
      throw const TodoAuthException('登录响应缺少用户凭证');
    }
    return TodoAuthSession.fromResponse(
      Map<String, dynamic>.from(data),
      mobile: mobile,
      tenantId: tenantId,
    );
  }

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {
    final resp = await _client.memberPut<Map<String, dynamic>>(
      '/user/reset-password',
      data: {'mobile': mobile, 'code': code, 'password': password},
    );
    _unwrap(resp);
  }

  @override
  Future<void> logout(String accessToken) async {
    // logout 走带 token 的请求；ApiClient 拦截器已注入 Authorization。
    try {
      final resp = await _client.memberPost<Map<String, dynamic>>(
        '/auth/logout',
      );
      _unwrap(resp);
    } catch (_) {
      // 登出失败（如已离线）不阻塞本地清理。
    }
  }

  @override
  Future<bool> validateSession(String accessToken) async {
    if (accessToken.isEmpty) return false;
    try {
      final resp = await _client.memberGet<Map<String, dynamic>>('/user/get');
      _unwrap(resp);
      return true;
    } on TodoAuthException {
      return false;
    }
  }

  @override
  void close() {
    // dio 实例由 ApiClient 拥有，这里不主动关闭（避免影响共享实例）。
  }
}
