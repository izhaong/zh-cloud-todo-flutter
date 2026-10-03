import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/storage/session_store.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

/// #481 的行为契约判据。
///
/// 两条都是实跑出来的错配：ad-hoc 签名的 macOS 档写 data-protection keychain 回
/// `PlatformException(-34018)`，而 `setSession` 先设 state 再 await 写盘 ⇒
/// 界面显示「已登录」、重启却掉登录；另一条是 bootstrap 的兜底 catch 调 `clearSession()`
/// ⇒ 钥匙串「这次读不到」（用户拒绝授权 / 钥匙串暂不可用）被处理成「令牌已失效」，
/// 把还能用的已存项抹掉，逼用户重新登录。
class _WriteFailingStore extends SessionStore {
  bool written = false;

  @override
  Future<TodoAuthSession?> readSession() async => null;

  @override
  Future<void> writeSession(TodoAuthSession session) async {
    written = true;
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<void> clearSession() async {}
}

class _ReadFailingStore extends SessionStore {
  bool cleared = false;

  @override
  Future<TodoAuthSession?> readSession() async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<void> writeSession(TodoAuthSession session) async {}

  @override
  Future<void> clearSession() async {
    cleared = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = TodoAuthSession(
    userId: 7,
    accessToken: 'access-token-under-test',
    refreshToken: 'refresh-token-under-test',
    tenantId: '1',
    mobile: '13800000000',
  );

  test('会话没落盘成功之前不得标成已登录，写失败必须作为异常冒出来', () async {
    final store = _WriteFailingStore();
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    Object? error;
    try {
      await container.read(sessionProvider.notifier).setSession(session);
    } catch (cause) {
      error = cause;
    }

    expect(store.written, isTrue, reason: '用例要先真的走到写盘那一步，否则下面的断言都是恒真');
    expect(error, isNotNull, reason: '写失败被吞掉 ⇒ 调用方拿不到任何信号，只能显示一句错的原因');
    expect(
      container.read(sessionProvider),
      isNull,
      reason:
          '写盘还没成功就把 state 设成已登录 ⇒ 界面显示已登录、重启却掉登录，'
          '用户会以为是自己没勾「记住登录」而不是本机没存下',
    );
  });

  test('本机存储读失败不清已存会话，也不说成令牌已失效', () async {
    final store = _ReadFailingStore();
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(
      store.cleared,
      isFalse,
      reason:
          '「这次读不到」不等于「服务端判失效」：清掉已存项会把一次钥匙串不可用'
          '变成必须重新登录，本地 Drift 数据也跟着白丢',
    );
    expect(container.read(sessionProvider), isNull);
    expect(
      container.read(sessionExpiredNoticeProvider),
      isFalse,
      reason: '那句「登录已失效，请重新登录」只留给确实拿到「无效」答复的路径（#475 的语义）',
    );
    expect(container.read(sessionBootstrappedProvider), isTrue);
  });

  test('macOS 档走传统 login keychain，不依赖 keychain-access-groups entitlement', () {
    // 机械判据：这行配置是桌面端能不能写进钥匙串的分水岭，
    // 默认值 true（数据保护钥匙串）在 ad-hoc 签名下恒回 -34018。
    expect(
      macOsSessionStorageOptions.toMap()['useDataProtectionKeyChain'],
      'false',
      reason: '改成 true 就等于把桌面登录交回需要 entitlement 的数据保护钥匙串',
    );
    expect(const SessionPersistenceException().message, isNotEmpty);
  });
}
