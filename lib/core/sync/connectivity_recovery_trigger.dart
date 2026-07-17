import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// 仅在设备从无连接恢复到任意可用连接时触发一次同步。
///
/// 连通性状态不是请求成功的证明；实际请求错误仍由同步协调器的退避策略处理。
class ConnectivityRecoveryTrigger {
  ConnectivityRecoveryTrigger(this._changes, {required this.onOnlineRecovered});

  final Stream<List<ConnectivityResult>> _changes;
  final Future<void> Function() onOnlineRecovered;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  void start() {
    _subscription ??= _changes.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((result) => result != ConnectivityResult.none);
    if (_wasOffline && online) {
      unawaited(onOnlineRecovered().catchError((_) {}));
    }
    _wasOffline = !online;
  }

  Future<void> dispose() => _subscription?.cancel() ?? Future.value();
}
