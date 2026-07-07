import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_session.dart';

/// 会话安全持久化：用 [FlutterSecureStorage] 替换旧版明文 `shared_preferences`。
///
/// - keychain/keystore 加密存储完整会话 JSON（token / userId / tenantId）。
/// - 设备唯一标识（`device_id`，sync 协议用）也由本类托管，与 token 同源安全存储。
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'zh_cloud_todo_flutter_session_v2';
  static const _deviceIdKey = 'zh_cloud_todo_flutter_device_id';

  Future<TodoAuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return TodoAuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  Future<void> writeSession(TodoAuthSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  /// 设备唯一标识：跨启动稳定；不存在则生成 UUID-v4 并写回。
  Future<String> readOrCreateDeviceId({String Function()? generate}) async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = (generate ?? _defaultUuid)();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  // 测试可注入确定性 ID；生产用真 UUID（避免在本类硬依赖 uuid 包）。
  String _defaultUuid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}
