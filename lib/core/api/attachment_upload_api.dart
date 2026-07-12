import 'package:dio/dio.dart';

import 'api_client.dart';

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
}

class DioAttachmentUploadApi implements AttachmentUploadApi {
  DioAttachmentUploadApi(this._client);

  final ApiClient _client;

  @override
  Future<String> uploadFile({
    required String localPath,
    required String name,
  }) async {
    final response = await _client.raw.post<Map<String, dynamic>>(
      '/app-api/infra/file/upload',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(localPath, filename: name),
        'directory': 'todo/attachments',
      }),
    );
    final data = _unwrap(response.data);
    final url = data.toString();
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

  Object? _unwrap(Map<String, dynamic>? body) {
    if (body == null) throw StateError('空响应');
    if (body.containsKey('code')) {
      if (body['code'] != 0) {
        throw DioException(
          requestOptions: RequestOptions(path: '/app-api/infra/file/upload'),
          error: body['msg'] ?? '附件上传失败',
        );
      }
      return body['data'];
    }
    return body['data'] ?? body;
  }
}
