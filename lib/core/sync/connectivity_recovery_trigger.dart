import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// 仅在设备从无连接恢复到任意可用连接时触发一次同步。
///
/// 连通性状态不是请求成功的证明；实际请求错误仍由同步协调器的退避策略处理。
class ConnectivityRecoveryTrigger {
  ConnectivityRecoveryTrigger(
    this._changes, {
    required this.onOnlineRecovered,
    Future<List<ConnectivityResult>> Function()? initialState,
  }) : _initialState = initialState;

  final Stream<List<ConnectivityResult>> _changes;
  final Future<void> Function() onOnlineRecovered;
  final Future<List<ConnectivityResult>> Function()? _initialState;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;
  bool _starting = false;
  bool _disposed = false;
  final List<List<ConnectivityResult>> _pendingBeforeInitialState = [];

  /// 在订阅平台流前读取一次当前状态，避免离线冷启动后首次平台事件就是
  /// online 时遗漏恢复同步。初始化期间到达的流事件按原顺序补放，避免读取
  /// 与订阅之间的竞态丢失状态转换。
  Future<void> start() async {
    if (_subscription != null || _starting || _disposed) return;
    _starting = true;
    var initialStateApplied = _initialState == null;
    _subscription = _changes.listen((results) {
      if (!initialStateApplied) {
        _pendingBeforeInitialState.add(results);
        return;
      }
      _onConnectivityChanged(results);
    });
    if (_initialState != null) {
      try {
        _wasOffline = !_isOnline(await _initialState());
      } catch (_) {
        // 读取初始状态失败时不把未知状态误判为离线；后续流仍可正常驱动。
      }
      initialStateApplied = true;
      for (final results in _pendingBeforeInitialState) {
        _onConnectivityChanged(results);
      }
      _pendingBeforeInitialState.clear();
    }
    _starting = false;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) return;
    final online = _isOnline(results);
    if (_wasOffline && online) {
      unawaited(onOnlineRecovered().catchError((_) {}));
    }
    _wasOffline = !online;
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
  }
}
