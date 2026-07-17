import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/sync/connectivity_recovery_trigger.dart';

void main() {
  test('triggers sync only when offline connectivity recovers', () async {
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
}
