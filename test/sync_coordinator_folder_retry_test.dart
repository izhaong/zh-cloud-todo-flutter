import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';

void main() {
  test('failed folder REST change survives restart and retries automatically',
      () async {
    final directory = await Directory.systemTemp.createTemp('todo-folder-retry-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/todo.sqlite');
    var firstAttempt = true;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/app-api/todo/folder/create');
            if (firstAttempt) {
              firstAttempt = false;
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'code': 0, 'data': 71},
              ),
            );
          },
        ),
      );
    final first = AppDatabase.forTesting(NativeDatabase(file));
    final folder = await FolderRepository(
      first,
      SyncChangeQueue(first),
    ).create('离线重试文件夹');
    expect(await _coordinator(first, dio).push(), 0);
    var change = await first.select(first.todoSyncChanges).getSingle();
    expect(change.status, 'retryable');
    expect(change.attemptCount, 1);
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(await _coordinator(reopened, dio).push(), 1);
    change = await reopened.select(reopened.todoSyncChanges).getSingle();
    expect(change.status, 'synced');
    expect(change.attemptCount, 1);
    final syncedFolder = await (reopened.select(
      reopened.todoFolders,
    )..where((row) => row.id.equals(folder.id))).getSingleOrNull();
    expect(syncedFolder?.serverId, 71);
  });
}

SyncCoordinator _coordinator(AppDatabase db, Dio dio) {
  final client = ApiClient(dio: dio);
  return SyncCoordinator(
    db: db,
    api: SyncApi(client, clientId: 'folder-retry', deviceId: 'folder-retry'),
    todoApi: client,
  );
}
