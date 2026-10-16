import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/envelope.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const persistedSession = TodoAuthSession(
    userId: 1,
    accessToken: 'persisted-access-token',
    refreshToken: 'persisted-refresh-token',
    tenantId: '1',
    mobile: '18800000000',
  );

  test(
    'offline validation preserves the persisted session on bootstrap',
    () async {
      final store = _MemorySessionStore(persistedSession);
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          authGatewayProvider.overrideWithValue(
            _FakeAuthGateway(
              validationError: DioException(
                requestOptions: RequestOptions(
                  path: '/app-api/todo-member/user/get',
                ),
                type: DioExceptionType.connectionError,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).bootstrap();

      expect(container.read(sessionProvider), persistedSession);
      expect(store.cleared, isFalse);
      // 服务端根本没答过，不能对用户宣称「登录状态已失效」。
      expect(container.read(sessionExpiredNoticeProvider), isFalse);
      expect(container.read(sessionBootstrappedProvider), isTrue);
    },
  );

  test(
    'bootstrap can construct the production auth gateway without a cycle',
    () async {
      final store = _MemorySessionStore(persistedSession);
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          sessionValidationTimeoutProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).bootstrap();

      expect(container.read(sessionProvider), persistedSession);
      expect(store.cleared, isFalse);
    },
  );

  test(
    'a stalled validation releases the persisted session for offline boot',
    () async {
      final store = _MemorySessionStore(persistedSession);
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          sessionValidationTimeoutProvider.overrideWithValue(Duration.zero),
          authGatewayProvider.overrideWithValue(
            _FakeAuthGateway(validationNeverCompletes: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).bootstrap();

      expect(container.read(sessionProvider), persistedSession);
      expect(store.cleared, isFalse);
      expect(container.read(sessionBootstrappedProvider), isTrue);
    },
  );

  test('a confirmed invalid session is removed on bootstrap', () async {
    final store = _MemorySessionStore(persistedSession);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider), isNull);
    expect(store.cleared, isTrue);
    expect(container.read(sessionBootstrappedProvider), isTrue);
    expect(container.read(sessionExpiredNoticeProvider), isTrue);
  });

  // 用户报的就是这一条：默认 access token 只有 1800 秒，以前「校验不过」直接清
  // 会话，于是每次启动都要重新登录；而 refresh token 能活 2592000 秒。
  test('access token 过期但刷新令牌仍有效时，启动不该掉登录', () async {
    const renewed = TodoAuthSession(
      userId: 1,
      accessToken: 'renewed-access-token',
      refreshToken: 'persisted-refresh-token',
      tenantId: '1',
      mobile: '18800000000',
    );
    final store = _MemorySessionStore(persistedSession);
    final gateway = _FakeAuthGateway(refreshedSession: renewed);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(
      container.read(sessionProvider),
      renewed,
      reason: '拿得到新 accessToken 就该保持登录，而不是把用户丢回登录页',
    );
    expect(gateway.refreshCalls, 1, reason: '续签要真的发生一次');
    expect(store.cleared, isFalse, reason: '还能续签 ⇒ 绝不能清本机会话');
    expect(
      container.read(sessionExpiredNoticeProvider),
      isFalse,
      reason: '这不是「登录已失效」，不能对用户这么讲',
    );
    expect(
      store.session?.accessToken,
      'renewed-access-token',
      reason: '新令牌要落盘，否则下次启动又拿旧令牌去撞 401',
    );
  });

  test('续签时网络不可确认，保留会话而不是清掉（离线启动的既有承诺）', () async {
    final store = _MemorySessionStore(persistedSession);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(
          _FakeAuthGateway(
            refreshError: DioException(
              requestOptions: RequestOptions(
                path: '/app-api/todo-member/auth/refresh-token',
              ),
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(
      container.read(sessionProvider),
      persistedSession,
      reason: '网络断掉不等于令牌被拒，本地 Drift 数据还要能进',
    );
    expect(store.cleared, isFalse);
    expect(container.read(sessionExpiredNoticeProvider), isFalse);
  });

  test('刷新令牌被服务端判过期（信封 code:401）才算失效，清会话', () async {
    final store = _MemorySessionStore(persistedSession);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(
          _FakeAuthGateway(
            // 芋道真形状：HTTP 200，业务码 401 装在信封里，网络层包成 DioException。
            refreshError: envelopeFailure(const {
              'code': 401,
              'msg': '刷新令牌已过期',
              'data': null,
            }, path: '/app-api/todo-member/auth/refresh-token'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider), isNull);
    expect(store.cleared, isTrue);
    expect(container.read(sessionExpiredNoticeProvider), isTrue);
  });

  // 开着应用跨过 30 分钟：业务请求被判 401 时也要先续签，而不是直接踢人。
  test('业务请求 401 后先续签，续得上就不结束会话', () async {
    const renewed = TodoAuthSession(
      userId: 1,
      accessToken: 'renewed-after-401',
      refreshToken: 'persisted-refresh-token',
      tenantId: '1',
      mobile: '18800000000',
    );
    final store = _MemorySessionStore();
    final gateway = _FakeAuthGateway(refreshedSession: renewed);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).setSession(persistedSession);
    final client = container.read(apiClientProvider);
    client.raw.httpClientAdapter = _UnauthorizedAdapter();
    try {
      await client.get('/lists');
    } on DioException {
      // 401 该抛给调用方，这里只量它顺带做了什么。
    }
    await pumpEventQueue();

    expect(gateway.refreshCalls, 1);
    expect(container.read(sessionProvider), renewed);
    expect(store.cleared, isFalse);
    expect(container.read(sessionExpiredNoticeProvider), isFalse);
  });

  test(
    'the expiry notice separates a rejected token from a manual sign out',
    () async {
      final store = _MemorySessionStore(persistedSession);
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionProvider.notifier)
          .setSession(persistedSession);
      await container.read(sessionProvider.notifier).expireSession();
      expect(container.read(sessionExpiredNoticeProvider), isTrue);

      // 重新登录后用户主动退出：标记必须归零，否则把操作说成故障。
      await container
          .read(sessionProvider.notifier)
          .setSession(persistedSession);
      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(sessionExpiredNoticeProvider), isFalse);
      expect(store.cleared, isTrue);
    },
  );

  test('业务请求收到 401 时按「过期」清理会话（providers 的接线）', () async {
    final store = _MemorySessionStore();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).setSession(persistedSession);
    final client = container.read(apiClientProvider);
    client.raw.httpClientAdapter = _UnauthorizedAdapter();
    try {
      await client.get('/lists');
    } on DioException {
      // 401 本来就该抛给调用方；这里要量的是它顺带做了什么。
    }
    await pumpEventQueue();

    expect(container.read(sessionProvider), isNull);
    expect(container.read(sessionExpiredNoticeProvider), isTrue);
  });

  test('业务请求撞到 HTTP 200 + 信封 code:401 时也结束会话（#477 的真形状）', () async {
    final store = _MemorySessionStore();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).setSession(persistedSession);
    final client = container.read(apiClientProvider);
    client.raw.httpClientAdapter = _EnvelopeUnauthorizedAdapter();
    // HTTP 是 200，dio 不抛；「这是未登录」只能从信封里读出来。
    await client.get<Map<String, dynamic>>('/lists');
    await pumpEventQueue();

    expect(container.read(sessionProvider), isNull);
    expect(store.cleared, isTrue);
    expect(container.read(sessionExpiredNoticeProvider), isTrue);
  });

  test(
    'sign out clears persisted native widget and lock screen snapshots',
    () async {
      const channel = MethodChannel('zh_cloud_todo/native');
      const widgetChannel = MethodChannel('home_widget');
      final received = <MethodCall>[];
      final widgetCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received.add(call);
            return call.method == 'pushLockScreenTasks' ? true : null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, (call) async {
            widgetCalls.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(widgetChannel, null);
      });
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(_MemorySessionStore()),
          authGatewayProvider.overrideWithValue(_FakeAuthGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionProvider.notifier)
          .setSession(persistedSession);
      await container.read(sessionProvider.notifier).signOut();
      await pumpEventQueue();

      expect(received.map((call) => call.method), ['pushLockScreenTasks']);
      expect(received.single.arguments, {'tasks': <Object>[]});
      expect(
        widgetCalls
            .singleWhere((call) => call.method == 'saveWidgetData')
            .arguments,
        {'id': 'tasks', 'data': '[]'},
      );
    },
  );
}

/// 芋道真形状：HTTP 200，业务码 401 装在信封里。
class _EnvelopeUnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":401,"msg":"账号未登录","data":null}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// 只回 401 的假传输层：用来驱动 `apiClientProvider` 里那条真接线。
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":401,"msg":"账号未登录","data":null}',
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({
    this.validationError,
    this.validationNeverCompletes = false,
    this.refreshError,
    this.refreshedSession,
  });

  final Object? validationError;
  final bool validationNeverCompletes;
  final Object? refreshError;
  final TodoAuthSession? refreshedSession;
  int refreshCalls = 0;

  @override
  Future<TodoAuthSession> refreshSession(TodoAuthSession current) async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    final renewed = refreshedSession;
    if (renewed != null) return renewed;
    // 默认当刷新令牌也过期了：老用例量的是「确认失效 ⇒ 清会话」，
    // 「续签成功 ⇒ 不掉登录」由后续独立用例覆盖。
    throw const TodoAuthException('刷新令牌已过期');
  }

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
    String? twoFactorCode,
  }) => throw UnimplementedError();

  @override
  Future<void> sendSmsCode({
    required String mobile,
    required int scene,
  }) async {}

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
    String? twoFactorCode,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {}

  @override
  Future<void> logout(String accessToken) async {}

  @override
  Future<bool> validateSession(String accessToken) async {
    if (validationNeverCompletes) return Completer<bool>().future;
    final error = validationError;
    if (error != null) throw error;
    return false;
  }

  @override
  void close() {}
}

class _MemorySessionStore extends SessionStore {
  _MemorySessionStore([this.session]);

  TodoAuthSession? session;
  bool cleared = false;

  @override
  Future<TodoAuthSession?> readSession() async => session;

  @override
  Future<void> writeSession(TodoAuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clearSession() async {
    session = null;
    cleared = true;
  }
}
