import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'envelope.dart';

abstract interface class AttachmentUploadApi {
  Future<String> uploadFile({required String localPath, required String name});

  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  });

  Future<void> deleteTaskAttachment({required int serverId});
}

class DioAttachmentUploadApi implements AttachmentUploadApi {
  DioAttachmentUploadApi(this._client);

  final ApiClient _client;

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, dynamic>>(
        '/app-api/infra/file/upload',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(localPath, filename: name),
          'directory': 'todo/attachments',
        }),
      );
      if (_isServerFailure(response.data)) {
        return _uploadWithPresignedUrl(localPath: localPath, name: name);
      }
      return _requiredUrl(_unwrap(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode != null &&
          error.response!.statusCode! < HttpStatus.internalServerError) {
        rethrow;
      }
      return _uploadWithPresignedUrl(localPath: localPath, name: name);
    }
  }

  Future<String> _uploadWithPresignedUrl({
    required String localPath,
    required String name,
  }) async {
    final response = await _client.raw.get<Map<String, dynamic>>(
      '/app-api/infra/file/presigned-url',
      queryParameters: {'name': name, 'directory': 'todo/attachments'},
    );
    final data = _unwrap(response.data);
    if (data is! Map) throw StateError('文件预签名响应格式错误');
    final configId = data['configId'];
    final path = data['path']?.toString();
    final uploadUrl = data['uploadUrl']?.toString();
    final url = data['url']?.toString();
    if (configId is! num ||
        path == null ||
        path.isEmpty ||
        uploadUrl == null ||
        uploadUrl.isEmpty ||
        url == null ||
        url.isEmpty) {
      throw StateError('文件预签名响应缺少必要字段');
    }

    final file = File(localPath);
    final size = await file.length();
    await _putPresignedFile(uploadUrl: uploadUrl, file: file, size: size);
    final createResponse = await _client.raw.post<Map<String, dynamic>>(
      '/app-api/infra/file/create',
      data: {
        'configId': configId.toInt(),
        'path': path,
        'name': name,
        'url': url,
        'type': 'application/octet-stream',
        'size': size,
      },
    );
    _unwrap(createResponse.data);
    return url;
  }

  Future<void> _putPresignedFile({
    required String uploadUrl,
    required File file,
    required int size,
  }) async {
    final response = await _client.raw.put<void>(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {'Content-Length': size},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final status = response.statusCode;
    if (status == null || status < 300) return;
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location == null || location.isEmpty) {
      throw StateError('预签名上传重定向缺少目标地址');
    }
    await _client.raw.put<void>(
      Uri.parse(uploadUrl).resolve(location).toString(),
      data: file.openRead(),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {'Content-Length': size},
      ),
    );
  }

  bool _isServerFailure(Map<String, dynamic>? body) {
    final code = body?['code'];
    return code is num && code >= HttpStatus.internalServerError;
  }

  String _requiredUrl(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) throw StateError('文件上传未返回 URL');
    return url;
  }

  @override
  Future<int> registerTaskAttachment({
    required int taskServerId,
    required String name,
    required String url,
    required int size,
    required String mimeType,
    required String clientMutationId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/attachment/upload',
      data: {
        'entityType': 'TASK',
        'entityId': taskServerId,
        'name': name,
        'url': url,
        'size': size,
        'mimeType': mimeType,
        'clientMutationId': clientMutationId,
      },
    );
    final data = _unwrap(response.data);
    final id = (data as num?)?.toInt();
    if (id == null) throw StateError('附件登记未返回 ID');
    return id;
  }

  @override
  Future<void> deleteTaskAttachment({required int serverId}) async {
    final response = await _client.raw.delete<Map<String, dynamic>>(
      '/app-api/todo/attachment/delete',
      queryParameters: {'id': serverId},
    );
    final deleted = _unwrap(response.data);
    if (deleted != true) throw StateError('附件删除未确认');
  }

  Object? _unwrap(Map<String, dynamic>? body) {
    if (body == null) throw StateError('空响应');
    if (body.containsKey('code')) {
      if (body['code'] != 0) {
        throw envelopeFailure(
          body,
          path: '/app-api/infra/file/upload',
          fallback: '附件上传失败',
        );
      }
      return body['data'];
    }
    return body['data'] ?? body;
  }
}
