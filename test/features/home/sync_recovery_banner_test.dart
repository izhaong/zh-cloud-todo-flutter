import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/features/home/sync_recovery_banner.dart';

void main() {
  testWidgets('shows failed count and retries all failed changes', (tester) async {
    var retryCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncRecoveryBanner(
            failedCount: 2,
            onRetry: () async => retryCalls++,
          ),
        ),
      ),
    );

    expect(find.text('2 项同步需要处理'), findsOneWidget);
    expect(find.text('立即重试'), findsOneWidget);

    await tester.tap(find.text('立即重试'));
    await tester.pump();

    expect(retryCalls, 1);
  });
}
