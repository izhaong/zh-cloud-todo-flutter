import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_retry_policy.dart';

void main() {
  test('失败退避按指数增长并设定上限', () {
    expect(syncRetryDelay(1), const Duration(seconds: 5));
    expect(syncRetryDelay(2), const Duration(seconds: 10));
    expect(syncRetryDelay(3), const Duration(seconds: 20));
    expect(syncRetryDelay(99), const Duration(hours: 1));
  });
}
