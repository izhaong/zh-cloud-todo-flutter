import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  group('ListCollaborationApi / ListMember 模型构造', () {
    test('ListMember 解析 owner/editor/viewer、状态与用户资料', () {
      const owner = ListMember(
        userId: 42,
        role: 'owner',
        status: 'active',
        mobile: '188****0042',
        displayName: 'Test',
      );
      expect(owner.userId, 42);
      expect(owner.isOwner, isTrue);
      expect(owner.roleLabel, '所有者');
      expect(owner.statusLabel, '已加入');
      expect(owner.mobile, contains('0042'));

      const editor = ListMember(userId: 7, role: 'editor', status: 'active');
      expect(editor.isEditor, isTrue);
      expect(editor.roleLabel, '可编辑');

      const viewer = ListMember(
        userId: 8,
        role: 'viewer',
        status: 'invited',
        displayName: '小王',
        email: 'wang@example.com',
      );
      expect(viewer.isViewer, isTrue);
      expect(viewer.roleLabel, '只读');
      expect(viewer.statusLabel, '待接受');
      expect(viewer.email, 'wang@example.com');
    });

    test('邀请按手机号提交 editor/viewer 角色，改角色使用 PATCH', () async {
      final client = _RecordingApiClient();
      final api = ListCollaborationApi(client);

      await api.addMember(
        listId: 12,
        userMobile: '18800000001',
        role: 'viewer',
      );
      await api.updateRole(listId: 12, userId: 99, role: 'editor');

      expect(client.requests, [
        const _RecordedRequest(
          method: 'POST',
          path: '/list/12/members',
          data: {'userMobile': '18800000001', 'role': 'viewer'},
        ),
        const _RecordedRequest(
          method: 'PATCH',
          path: '/list/12/members/99',
          data: {'role': 'editor'},
        ),
      ]);
    });
  });

  group('TaskComment 构造', () {
    test('字段透传（不含 parseTime 重构）', () {
      final c = TaskComment(
        id: 1,
        taskId: 100,
        content: 'hello',
        userId: 5,
        createdAt: DateTime(2026, 7, 7),
      );
      expect(c.id, 1);
      expect(c.taskId, 100);
      expect(c.content, 'hello');
      expect(c.userId, 5);
      expect(c.createdAt, DateTime(2026, 7, 7));
    });
  });

  group('TaskAssignApi', () {
    test('解析服务端执行人资料并按 assigneeUserId 提交', () async {
      final client = _RecordingApiClient(
        getBody: {
          'code': 0,
          'data': {
            'taskId': 12,
            'assigneeUserId': 99,
            'assigneeUserName': '执行人',
            'assigneeUserEmail': 'assignee@example.com',
          },
        },
      );
      final api = TaskAssignApi(client);

      final assignee = await api.assignee(12);
      expect(assignee?.userId, 99);
      expect(assignee?.displayName, '执行人');
      expect(assignee?.email, 'assignee@example.com');

      await api.setAssignee(taskId: 12, userId: 100);
      expect(
        client.requests.last,
        const _RecordedRequest(
          method: 'PUT',
          path: '/task/12/assignee',
          data: {'assigneeUserId': 100},
        ),
      );
    });
  });

  group('CalSubscription 构造', () {
    test('字段透传', () {
      const s = CalSubscription(
        id: 9,
        url: 'https://x.co/cal.ics',
        name: 'test',
        enabled: false,
      );
      expect(s.id, 9);
      expect(s.url, contains('https://'));
      expect(s.enabled, isFalse);
      expect(s.lastSyncAt, isNull);
    });
  });
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.data,
  });

  final String method;
  final String path;
  final Object? data;

  @override
  bool operator ==(Object other) =>
      other is _RecordedRequest &&
      method == other.method &&
      path == other.path &&
      _mapEquals(data, other.data);

  @override
  int get hashCode => Object.hash(
    method,
    path,
    data is Map
        ? Object.hashAllUnordered(
            (data as Map).entries.map(
              (entry) => Object.hash(entry.key, entry.value),
            ),
          )
        : data,
  );
}

bool _mapEquals(Object? left, Object? right) {
  if (left is! Map || right is! Map || left.length != right.length) {
    return left == right;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient({this.getBody});

  final Object? getBody;
  final List<_RecordedRequest> requests = [];

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    requests.add(_RecordedRequest(method: 'GET', path: path, data: null));
    return Response<T>(
      data: getBody as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(_RecordedRequest(method: 'POST', path: path, data: data));
    return _response<T>(path);
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(_RecordedRequest(method: 'PATCH', path: path, data: data));
    return _response<T>(path);
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(_RecordedRequest(method: 'PUT', path: path, data: data));
    return _response<T>(path);
  }

  Response<T> _response<T>(String path) => Response<T>(
    data: const {'code': 0, 'data': <String, Object>{}} as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );
}
