import 'package:dio/dio.dart';
import 'api_config.dart';

/// 业务 API dio 客户端（`/app-api/todo/**`）。
///
/// - baseUrl = [ApiConfig.defaultBaseUrl]（可由 main.dart 用 --dart-define 覆盖）
/// - 默认 5s 连接 / 10s 接收超时
/// - 每次请求注入 `Authorization: Bearer <token>` + `tenant-id`（与后端
///   「登录态一体化」约定一致）；401 时触发 [onUnauthorized] 回调交由上层清理会话
class TodoApiClient {
  TodoApiClient({
    Dio? dio,
    String? baseUrl,
    String Function()? tokenProvider,
    String tenantId = '1',
    void Function()? onUnauthorized,
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
          options.headers['tenant-id'] = tenantId;
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

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>('${ApiConfig.todoPrefix}$path', queryParameters: query);
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>('${ApiConfig.todoPrefix}$path', data: data);
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _dio.put<T>('${ApiConfig.todoPrefix}$path', data: data);
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) {
    return _dio.delete<T>('${ApiConfig.todoPrefix}$path', data: data);
  }
}
