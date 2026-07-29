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
  _FakeApiClient({this.body = const {'code': 0, 'data': <String, Object>{}}});

  final Map<String, Object> body;

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => Response<T>(
    data: const {'code': 0, 'data': <String, Object>{}} as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => Response<T>(
    data: const {'code': 0, 'data': <String, Object>{}} as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );

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

  testWidgets('TaskAssignPage 渲染 - 未指派显示提示', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _containerWith(_FakeApiClient(), db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TaskAssignPage(taskServerId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未指派'), findsOneWidget);
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
