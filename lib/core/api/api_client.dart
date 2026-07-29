import 'package:dio/dio.dart';

import 'api_config.dart';

/// 会话凭证供给：网络层在每次请求前回调取最新 token / tenantId。
typedef TokenProvider = String Function();
typedef TenantIdProvider = String Function();

/// 401（会话失效）回调：交由上层清理会话并跳转登录。
typedef OnUnauthorized = void Function();

/// 统一 dio 客户端：业务 `/app-api/todo/**` 与认证 `/app-api/todo-member/**`
/// 共用同一实例，由拦截器统一注入 `Authorization` + `tenant-id`。
///
/// - 默认 5s 连接 / 10s 接收超时。
/// - 请求前注入 `Bearer <token>` + `tenant-id`（与后端「登录态一体化」一致）。
/// - 响应 401 触发 [onUnauthorized]（延后到下一帧，避免 build 期改 provider）。
/// - 业务错误信封 `{code,msg,data}`：`code != 0` 抛 [DioException]。
class ApiClient {
  ApiClient({
    Dio? dio,
    String? baseUrl,
    TokenProvider? tokenProvider,
    TenantIdProvider? tenantIdProvider,
    OnUnauthorized? onUnauthorized,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 10),
               headers: {'Content-Type': 'application/json'},
               responseType: ResponseType.json,
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['tenant-id'] =
              tenantIdProvider?.call() ?? ApiConfig.defaultTenantId;
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  Dio get raw => _dio;

  // --- /app-api/todo/** 业务 ------------------------------------------------

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>('${ApiConfig.todoPrefix}$path', queryParameters: query);
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(
      '${ApiConfig.todoPrefix}$path',
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put<T>(
      '${ApiConfig.todoPrefix}$path',
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete<T>(
      '${ApiConfig.todoPrefix}$path',
      data: data,
      queryParameters: queryParameters,
    );
  }

  // --- /app-api/todo-member/** 认证 -----------------------------------------

  Future<Response<T>> memberPost<T>(String path, {Object? data}) {
    return _dio.post<T>('${ApiConfig.memberPrefix}$path', data: data);
  }

  Future<Response<T>> memberPut<T>(String path, {Object? data}) {
    return _dio.put<T>('${ApiConfig.memberPrefix}$path', data: data);
  }

  Future<Response<T>> memberGet<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.get<T>(
      '${ApiConfig.memberPrefix}$path',
      queryParameters: query,
      options: options,
    );
  }
}
