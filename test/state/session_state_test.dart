import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/state/session_state.dart';

void main() {
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
      expect(container.read(sessionBootstrappedProvider), isTrue);
    },
  );

  test('bootstrap can construct the production auth gateway without a cycle',
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
  });

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
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({
    this.validationError,
    this.validationNeverCompletes = false,
  });

  final Object? validationError;
  final bool validationNeverCompletes;

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
  _MemorySessionStore(this.session);

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
