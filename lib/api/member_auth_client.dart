import 'package:dio/dio.dart';
import 'api_config.dart';

/// M11-B1 会员认证客户端（/app-api/todo-member/**）
///
/// - 登录 / 登出 / 注册 / 刷新 token
/// - 简化版：返回 token 字符串；具体 JWT 解析在 main.dart
class MemberAuthClient {
  MemberAuthClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.memberPrefix}/auth/login',
      data: {'username': username, 'password': password},
    );
    final token = (resp.data?['data'] as Map?)?['token'] as String?;
    if (token == null) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        message: '登录响应缺少 token',
      );
    }
    return token;
  }

  Future<void> logout({String? token}) async {
    await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.memberPrefix}/auth/logout',
      options: token == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String> register({
    required String username,
    required String password,
    String? email,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '${ApiConfig.memberPrefix}/auth/register',
      data: {
        'username': username,
        'password': password,
        if (email != null) 'email': email,
      },
    );
    final token = (resp.data?['data'] as Map?)?['token'] as String?;
    if (token == null) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        message: '注册响应缺少 token',
      );
    }
    return token;
  }
}