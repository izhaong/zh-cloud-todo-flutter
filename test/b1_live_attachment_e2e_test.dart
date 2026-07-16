import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/attachment_upload_api.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';

const _enabled = bool.fromEnvironment('TODO_B1_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test(
    'B1 live attachment falls back to presigned upload and is visible to a second session',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');

      final sessionA = await _login();
      final sessionB = await _login();
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final name =
          'B1 live attachment ${DateTime.now().millisecondsSinceEpoch}';
      int? listId;
      int? taskId;
      int? attachmentId;
      try {
        listId = await _postId(apiA, '/app-api/todo/list/create', {
          'name': name,
          'sortOrder': 215,
        });
        taskId = await _postId(apiA, '/app-api/todo/task/create', {
          'listId': listId,
          'title': 'B1 live attachment',
          'description': 'Markdown **presigned fallback**',
          'priority': 2,
          'sortOrder': 215,
        });
        final file = File('README.md');
        final attachmentApi = DioAttachmentUploadApi(apiA);
        final url = await attachmentApi.uploadFile(
          localPath: file.path,
          name: 'b1-live-attachment.md',
        );
        expect(
          await _readRemoteBytes(url),
          orderedEquals(await file.readAsBytes()),
          reason: '上传完成后，返回的访问 URL 必须读取到原始附件字节',
        );
        attachmentId = await attachmentApi.registerTaskAttachment(
          taskServerId: taskId,
          name: 'b1-live-attachment.md',
          url: url,
          size: await file.length(),
          mimeType: 'text/markdown',
          clientMutationId: 'b1-live-${DateTime.now().microsecondsSinceEpoch}',
        );

        final attachments = await _getData(
          apiB,
          '/app-api/todo/attachment/list',
          {'entityType': 'TASK', 'entityId': taskId},
        );
        expect(
          (attachments as List).any(
            (value) => (value as Map)['id'] == attachmentId,
          ),
          isTrue,
        );

        await attachmentApi.deleteTaskAttachment(serverId: attachmentId);
        attachmentId = null;
        final afterDelete = await _getData(
          apiB,
          '/app-api/todo/attachment/list',
          {'entityType': 'TASK', 'entityId': taskId},
        );
        expect(
          (afterDelete as List).any((value) => (value as Map)['id'] != null),
          isFalse,
        );
        await expectLater(
          _readRemoteBytes(url),
          throwsA(
            isA<DioException>().having(
              (error) => error.response?.statusCode,
              'HTTP status',
              HttpStatus.notFound,
            ),
          ),
          reason: '删除附件后，同一预签名访问 URL 必须不能再读取对象二进制',
        );
      } finally {
        if (attachmentId != null) {
          await _delete(
            apiA,
            '/app-api/todo/attachment/delete?id=$attachmentId',
          );
        }
        if (taskId != null) {
          await _delete(apiA, '/app-api/todo/task/delete?id=$taskId');
        }
        if (listId != null) {
          await _delete(apiA, '/app-api/todo/list/delete?id=$listId');
        }
      }
    },
    skip: _enabled ? false : 'set --dart-define=TODO_B1_LIVE=true to run',
  );
}

Future<TodoAuthSession> _login() => AuthGatewayImpl(
  _client(''),
  tenantId: _tenantId,
).passwordLogin(mobile: _mobile, password: _password);

ApiClient _client(String token) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: _baseUrl)),
  tokenProvider: () => token,
  tenantIdProvider: () => _tenantId,
);

Future<int> _postId(ApiClient client, String path, Object data) async {
  final response = await client.raw.post<Map<String, dynamic>>(
    path,
    data: data,
  );
  final value = _unwrap(response.data);
  if (value is! num) throw StateError('$path did not return an ID');
  return value.toInt();
}

Future<Object?> _getData(
  ApiClient client,
  String path,
  Map<String, dynamic> query,
) async {
  final response = await client.raw.get<Map<String, dynamic>>(
    path,
    queryParameters: query,
  );
  return _unwrap(response.data);
}

Future<void> _delete(ApiClient client, String path) async {
  final response = await client.raw.delete<Map<String, dynamic>>(path);
  _unwrap(response.data);
}

Future<List<int>> _readRemoteBytes(String url) async {
  final response = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  return response.data ?? const <int>[];
}

Object? _unwrap(Map<String, dynamic>? body) {
  if (body == null || body['code'] != 0) {
    throw StateError(body?['msg']?.toString() ?? 'empty response');
  }
  return body['data'];
}
