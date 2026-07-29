import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/sync/connectivity_recovery_trigger.dart';

void main() {
  test('仅在离线恢复为在线时触发同步', () async {
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    var recovered = 0;
    final trigger = ConnectivityRecoveryTrigger(
      changes.stream,
      onOnlineRecovered: () async => recovered++,
    )..start();
    addTearDown(trigger.dispose);

    changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(recovered, 0);

    changes.add(const [ConnectivityResult.none]);
    changes.add(const [ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(recovered, 0);

    changes.add(const [ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(recovered, 1);

    changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(recovered, 1);
  });

  test('primes an offline cold start before the first online event', () async {
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    var recovered = 0;
    final trigger = ConnectivityRecoveryTrigger(
      changes.stream,
      initialState: () async => const [ConnectivityResult.none],
      onOnlineRecovered: () async => recovered++,
    );
    addTearDown(trigger.dispose);

    await trigger.start();
    changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);

    expect(recovered, 1);
  });
}
