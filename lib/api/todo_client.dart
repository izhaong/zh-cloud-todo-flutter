import 'package:dio/dio.dart';
import 'api_config.dart';

/// M11-B1 通用 dio 客户端（业务 API /app-api/todo/**）
///
/// - baseUrl = ApiConfig.defaultBaseUrl（可由 main.dart 用 --dart-define 覆盖）
/// - 默认 5s 连接 / 10s 接收超时
/// - 业务 401 时由 auth interceptor 清理 token；401 之外错误直接抛 DioException
class TodoApiClient {
  TodoApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
              responseType: ResponseType.json,
            ));

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