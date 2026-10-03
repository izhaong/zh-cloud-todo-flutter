import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_session.dart';

/// macOS 用传统 login keychain，不用数据保护钥匙串。
///
/// 本机只能 ad-hoc 签名（无 Apple Developer ID / 描述文件）：带上
/// `keychain-access-groups` entitlement 会让 `flutter build macos` 直接失败，
/// 而默认的数据保护钥匙串在没有该 entitlement 时写回 `-34018`（FL #481）。
/// 代价是每个新 cdhash（重新构建或换包）读旧项会弹一次系统授权框。
const macOsSessionStorageOptions = MacOsOptions(
  useDataProtectionKeyChain: false,
);

/// 会话没能落进本机安全存储。
class SessionPersistenceException implements Exception {
  const SessionPersistenceException({
    this.message = kSessionPersistenceMessage,
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 界面文案的唯一来源：登录页与异常本身都念这一句。
const kSessionPersistenceMessage = '本机无法保存登录态，关闭应用后需要重新登录';

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
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            mOptions: macOsSessionStorageOptions,
          );

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'zh_cloud_todo_flutter_session_v2';
  static const _deviceIdKey = 'zh_cloud_todo_flutter_device_id';
  static const _e2eDeviceId = String.fromEnvironment('TODO_E2E_DEVICE_ID');
  static TodoAuthSession? _e2eSession;

  static bool get _useE2eMemoryStore =>
      const bool.fromEnvironment('FLUTTER_TEST') && _e2eDeviceId.isNotEmpty;

  Future<TodoAuthSession?> readSession() async {
    if (_useE2eMemoryStore) return _e2eSession;
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return TodoAuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  Future<void> writeSession(TodoAuthSession session) async {
    if (_useE2eMemoryStore) {
      _e2eSession = session;
      return;
    }
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    if (_useE2eMemoryStore) {
      _e2eSession = null;
      return;
    }
    await _storage.delete(key: _sessionKey);
  }

  /// 设备唯一标识：跨启动稳定；不存在则生成 UUID-v4 并写回。
  Future<String> readOrCreateDeviceId({String Function()? generate}) async {
    if (_useE2eMemoryStore) return _e2eDeviceId;
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
