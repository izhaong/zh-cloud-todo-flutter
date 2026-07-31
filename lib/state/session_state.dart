import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/auth/auth_gateway.dart';
import '../core/storage/session_store.dart';
import '../native/native_intents.dart';

/// 新架构入口类型的再导出，方便下游 provider / 页面直接 import 本文件即可。
export '../core/auth/auth_session.dart' show TodoAuthSession;
export '../core/auth/auth_gateway.dart' show AuthGateway;
export '../core/storage/session_store.dart' show SessionStore;
export '../core/api/api_client.dart' show ApiClient;

/// 会话仓库（secure 持久化）；ProviderScope.overrides 可注入 Fake。
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// 认证专用客户端不能依赖 [sessionProvider]：应用启动校验正是在恢复该
/// provider，本客户端只处理登录 / 显式 token 校验，避免形成 Provider 环。
final authApiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// 认证网关；tenant 从 [ApiConfig.defaultTenantId]（可由 --dart-define 覆盖）。
final authGatewayProvider = Provider<AuthGateway>((ref) {
  final client = ref.watch(authApiClientProvider);
  final gateway = AuthGatewayImpl(client, tenantId: ApiConfig.defaultTenantId);
  ref.onDispose(gateway.close);
  return gateway;
});

/// 当前登录会话；null 表示未登录。
final sessionProvider = NotifierProvider<SessionController, TodoAuthSession?>(
  SessionController.new,
);

/// 会话初次校验是否完成（避免登录页在校验期间闪现）。
final sessionBootstrappedProvider = StateProvider<bool>((ref) => false);

/// 已持久化会话在离线或弱网启动时最多等待一次短校验；超时仅代表网络
/// 不可确认，必须保留本地会话与 Drift 数据，不能当成令牌被服务端拒绝。
final sessionValidationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

class SessionController extends Notifier<TodoAuthSession?> {
  @override
  TodoAuthSession? build() => null;

  /// 应用启动时读取本地 secure 会话，并向后端校验是否仍然有效。
  ///
  /// 网络不可用时，已持久化的会话仍可访问本地 Drift 数据；只有服务端明确
  /// 拒绝时才移除它，避免离线重启把用户误导回登录页。
  Future<void> bootstrap() async {
    final store = ref.read(sessionStoreProvider);
    try {
      final session = await store.readSession();
      if (session == null) {
        _clearNativeTaskProjections();
        ref.read(sessionBootstrappedProvider.notifier).state = true;
        return;
      }
      final gateway = ref.read(authGatewayProvider);
      final bool valid;
      try {
        valid = await gateway
            .validateSession(session.accessToken)
            .timeout(ref.read(sessionValidationTimeoutProvider));
      } on DioException {
        state = session;
        return;
      } on TimeoutException {
        state = session;
        return;
      }
      if (valid) {
        state = session;
      } else {
        await store.clearSession();
        _clearNativeTaskProjections();
      }
    } catch (_) {
      await store.clearSession();
      _clearNativeTaskProjections();
    } finally {
      ref.read(sessionBootstrappedProvider.notifier).state = true;
    }
  }

  Future<void> setSession(TodoAuthSession session) async {
    final current = state;
    if (current != null &&
        (current.userId != session.userId ||
            current.tenantId != session.tenantId)) {
      _clearNativeTaskProjections();
    }
    state = session;
    final store = ref.read(sessionStoreProvider);
    await store.writeSession(session);
  }

  Future<void> signOut() async {
    final current = state;
    if (current == null) return;
    state = null;
    final store = ref.read(sessionStoreProvider);
    await store.clearSession();
    _clearNativeTaskProjections();
    try {
      await ref.read(authGatewayProvider).logout(current.accessToken);
    } catch (_) {
      // 登出失败（如已离线）不阻塞本地清理。
    }
  }

  void _clearNativeTaskProjections() {
    unawaited(NativeIntents.updateTodayWidgetSnapshot(const []));
    unawaited(NativeIntents.pushLockScreenTasks(const []));
  }
}
