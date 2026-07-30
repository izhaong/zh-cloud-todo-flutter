// widget 测试：用 FakeApi + ProviderContainer 覆写后端 provider，验证新页面渲染。
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/collaboration/list_member_page.dart';
import 'package:zh_cloud_todo_flutter/features/collaboration/task_assign_page.dart';
import 'package:zh_cloud_todo_flutter/features/collaboration/task_comments_page.dart';
import 'package:zh_cloud_todo_flutter/features/calendar_sub/calendar_subscription_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

/// 用于测试的 ApiClient：避免真实网络，返回预配置好的响应。
class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    this.body = const {'code': 0, 'data': <String, Object>{}},
    this.bodyByPath = const {},
  });

  final Map<String, Object> body;
  final Map<String, Object> bodyByPath;
  String? lastMethod;
  String? lastPath;
  Object? lastData;

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    return Response<T>(
      data: (bodyByPath[path] ?? body) as T,
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
    lastMethod = 'POST';
    lastPath = path;
    lastData = data;
    return Response<T>(
      data: const {'code': 0, 'data': <String, Object>{}} as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastData = data;
    return Response<T>(
      data: const {'code': 0, 'data': <String, Object>{}} as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    lastMethod = 'PATCH';
    lastPath = path;
    lastData = data;
    return Response<T>(
      data: const {'code': 0, 'data': <String, Object>{}} as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => Response<T>(
    data: const {'code': 0, 'data': <String, Object>{}} as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );
}

class _FakeSession extends SessionController {
  @override
  TodoAuthSession? build() => const TodoAuthSession(
    userId: 1,
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    tenantId: '1',
    mobile: '18800000000',
  );
}

ProviderContainer _containerWith(ApiClient client, AppDatabase db) {
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      appDatabaseProvider.overrideWithValue(db),
      sessionProvider.overrideWith(() => _FakeSession()),
    ],
  );
}

void main() {
  testWidgets('ListMemberPage 渲染 - 空列表显示提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _containerWith(_FakeApiClient(), db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ListMemberPage(listServerId: 1, title: '测试清单'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无成员，邀请伙伴加入吧'), findsOneWidget);
  });

  testWidgets('ListMemberPage 渲染 - 有成员时显示成员列表', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _containerWith(
      _FakeApiClient(
        body: {
          'code': 0,
          'data': {'members': <Object>[]},
        },
      ),
      db,
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ListMemberPage(listServerId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无成员，邀请伙伴加入吧'), findsOneWidget);
  });

  testWidgets('owner 按手机号和 editor 权限邀请成员', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final client = _FakeApiClient(
      body: {
        'code': 0,
        'data': {
          'members': [
            {
              'userId': 1,
              'userName': '所有者',
              'role': 'owner',
              'status': 'active',
            },
            {
              'userId': 2,
              'userName': '只读成员',
              'userEmail': 'viewer@example.com',
              'role': 'viewer',
              'status': 'invited',
            },
          ],
        },
      },
    );
    final container = _containerWith(client, db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ListMemberPage(listServerId: 12)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('collaboration-invite-mobile')),
      findsOneWidget,
    );
    expect(find.text('可编辑'), findsOneWidget);
    expect(find.text('只读'), findsOneWidget);
    expect(find.text('待接受'), findsOneWidget);
    expect(find.textContaining('viewer@example.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('collaboration-invite-mobile')),
      '18800000001',
    );
    await tester.tap(find.byKey(const Key('collaboration-invite-submit')));
    await tester.pumpAndSettle();

    expect(client.lastMethod, 'POST');
    expect(client.lastPath, '/list/12/members');
    expect(client.lastData, {'userMobile': '18800000001', 'role': 'editor'});

    await tester.tap(find.byTooltip('管理成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, '可编辑'));
    await tester.pumpAndSettle();

    expect(client.lastMethod, 'PATCH');
    expect(client.lastPath, '/list/12/members/2');
    expect(client.lastData, {'role': 'editor'});
  });

  testWidgets('受邀 viewer 只显示接受邀请，不显示 owner 管理入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final client = _FakeApiClient(
      body: {
        'code': 0,
        'data': {
          'members': [
            {
              'userId': 1,
              'userName': '当前用户',
              'role': 'viewer',
              'status': 'invited',
            },
          ],
        },
      },
    );
    final container = _containerWith(client, db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ListMemberPage(listServerId: 12)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('接受邀请'), findsOneWidget);
    expect(find.text('退出协作'), findsNothing);
    expect(find.byKey(const Key('collaboration-invite-mobile')), findsNothing);
  });

  testWidgets('TaskCommentsPage 渲染 - 空列表显示提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _containerWith(_FakeApiClient(), db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TaskCommentsPage(taskServerId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无评论，来说两句吧'), findsOneWidget);
  });

  testWidgets('TaskAssignPage 从 active 清单成员选择执行人', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final client = _FakeApiClient(
      bodyByPath: {
        '/task/1/assignee': {'code': 0, 'data': <String, Object>{}},
        '/list/7/members': {
          'code': 0,
          'data': {
            'members': [
              {
                'userId': 1,
                'userName': '清单所有者',
                'role': 'owner',
                'status': 'active',
              },
              {
                'userId': 2,
                'userName': '活跃编辑者',
                'role': 'editor',
                'status': 'active',
              },
              {
                'userId': 3,
                'userName': '待接受成员',
                'role': 'viewer',
                'status': 'invited',
              },
            ],
          },
        },
      },
    );
    final container = _containerWith(client, db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TaskAssignPage(taskServerId: 1, listServerId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未指派'), findsOneWidget);
    expect(find.textContaining('userId'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.textContaining('活跃编辑者'), findsOneWidget);
    expect(find.textContaining('待接受成员'), findsNothing);
    await tester.tap(find.textContaining('活跃编辑者').last);
    await tester.pumpAndSettle();

    expect(client.lastMethod, 'PUT');
    expect(client.lastPath, '/task/1/assignee');
    expect(client.lastData, {'assigneeUserId': 2});
  });

  testWidgets('active viewer 只能查看执行人，不能重新指派', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final client = _FakeApiClient(
      bodyByPath: {
        '/task/1/assignee': {
          'code': 0,
          'data': {
            'taskId': 1,
            'assigneeUserId': 2,
            'assigneeUserName': '当前执行人',
          },
        },
        '/list/7/members': {
          'code': 0,
          'data': {
            'members': [
              {
                'userId': 1,
                'userName': '只读当前用户',
                'role': 'viewer',
                'status': 'active',
              },
              {
                'userId': 2,
                'userName': '当前执行人',
                'role': 'editor',
                'status': 'active',
              },
            ],
          },
        },
      },
    );
    final container = _containerWith(client, db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TaskAssignPage(taskServerId: 1, listServerId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前执行人'), findsOneWidget);
    expect(find.textContaining('当前清单为只读'), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(picker.onChanged, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '移除执行人'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('CalendarSubscriptionPage 渲染 - 空列表显示提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _containerWith(_FakeApiClient(), db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalendarSubscriptionPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无 ICS 订阅'), findsOneWidget);
  });
}
