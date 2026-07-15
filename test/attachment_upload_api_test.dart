import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/attachment_upload_api.dart';

void main() {
  test('direct upload failure falls back to the verified presigned flow', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            switch (options.uri.toString()) {
              case 'https://todo.test/app-api/infra/file/upload':
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 500, 'msg': '存储器不可用'},
                  ),
                );
              case 'https://todo.test/app-api/infra/file/presigned-url?name=README.md&directory=todo%2Fattachments':
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {
                      'code': 0,
                      'data': {
                        'configId': 7,
                        'path': 'todo/attachments/README.md',
                        'uploadUrl': 'https://storage.test/upload',
                        'url': 'https://storage.test/read/README.md',
                      },
                    },
                  ),
                );
              case 'https://storage.test/upload':
                handler.resolve(
                  Response<void>(requestOptions: options, statusCode: 200),
                );
              case 'https://todo.test/app-api/infra/file/create':
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': 77},
                  ),
                );
              default:
                handler.reject(
                  DioException(
                    requestOptions: options,
                    message: 'unexpected ${options.uri}',
                  ),
                );
            }
          },
        ),
      );
    final api = DioAttachmentUploadApi(ApiClient(dio: dio));

    final url = await api.uploadFile(localPath: 'README.md', name: 'README.md');

    expect(url, 'https://storage.test/read/README.md');
    expect(requests.map((request) => request.uri.toString()), [
      'https://todo.test/app-api/infra/file/upload',
      'https://todo.test/app-api/infra/file/presigned-url?name=README.md&directory=todo%2Fattachments',
      'https://storage.test/upload',
      'https://todo.test/app-api/infra/file/create',
    ]);
    final registration = requests.last.data as Map<String, dynamic>;
    expect(registration['configId'], 7);
    expect(registration['path'], 'todo/attachments/README.md');
    expect(registration['name'], 'README.md');
    expect(registration['url'], 'https://storage.test/read/README.md');
    expect(registration['type'], 'application/octet-stream');
    expect(registration['size'], await File('README.md').length());
  });
}
