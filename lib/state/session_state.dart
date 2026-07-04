import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../todo_member_auth_client.dart';

/// 登录会话持久化 key（与旧版 main.dart 保持一致，兼容历史缓存）。
const String sessionPrefsKey = 'zh_cloud_todo_flutter_session_v1';

/// 全局认证网关（登录/注册/找回密码/登出/校验）。
///
/// 测试可在 `ProviderScope.overrides` 中通过 `authGatewayProvider.overrideWithValue`
/// 注入 Fake 实现。
final authGatewayProvider = Provider<TodoMemberAuthGateway>((ref) {
  final client = TodoMemberAuthClient();
  ref.onDispose(client.close);
  return client;
});

/// 当前登录会话；null 表示未登录。
final sessionProvider = NotifierProvider<SessionController, TodoAuthSession?>(
  SessionController.new,
);

/// 会话初次校验是否完成（避免登录页在校验期间闪现）。
final sessionBootstrappedProvider = StateProvider<bool>((ref) => false);

class SessionController extends Notifier<TodoAuthSession?> {
  @override
  TodoAuthSession? build() => null;

  /// 应用启动时读取本地持久化会话，并向后端校验是否仍然有效。
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(sessionPrefsKey);
    if (raw == null || raw.isEmpty) {
      ref.read(sessionBootstrappedProvider.notifier).state = true;
      return;
    }
    try {
      final session = TodoAuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final gateway = ref.read(authGatewayProvider);
      final valid = await gateway.validateSession(session.accessToken);
      state = valid ? session : null;
      if (!valid) {
        await prefs.remove(sessionPrefsKey);
      }
    } catch (_) {
      state = null;
      await prefs.remove(sessionPrefsKey);
    } finally {
      ref.read(sessionBootstrappedProvider.notifier).state = true;
    }
  }

  Future<void> setSession(TodoAuthSession session) async {
    state = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionPrefsKey, jsonEncode(session.toJson()));
  }

  Future<void> signOut() async {
    final current = state;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionPrefsKey);
    if (current != null) {
      try {
        await ref.read(authGatewayProvider).logout(current.accessToken);
      } catch (_) {
        // 登出失败（如已离线）不阻塞本地清理。
      }
    }
  }
}
